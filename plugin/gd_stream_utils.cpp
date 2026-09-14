#include "gd_stream_utils.h"
#include "gd_kdtree.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/core/math.hpp>
#include <random>
#include <algorithm>
#include <deque>
#include <unordered_map>
#include <vector>

using namespace godot;

namespace {

struct GridCell {
  int32_t x;
  int32_t z;

  bool operator==(const GridCell& other) const {
    return x == other.x && z == other.z;
  }
};

struct GridCellHash {
  size_t operator()(const GridCell& cell) const {
    size_t hash = std::hash<int32_t>{}(cell.x);
    hash ^= std::hash<int32_t>{}(cell.z) + 0x9e3779b9 + (hash << 6) + (hash >> 2);
    return hash;
  }
};

} // namespace

void GDStreamUtils::_bind_methods() {
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_f32", "values"), &GDStreamUtils::get_sorted_indices_f32);
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_i32", "values"), &GDStreamUtils::get_sorted_indices_i32);
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_string", "values"), &GDStreamUtils::get_sorted_indices_string);
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("sample_around", "positions", "sizes", "radius", "max_radius", "max_points", "seed"), &GDStreamUtils::sample_around);
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("KMeans", "points", "num_clusters", "max_iterations", "tolerance", "seed"), &GDStreamUtils::KMeans);
}

template< typename T >
PackedInt32Array get_sorted_container(const T &values) {
    const int size = values.size();

    PackedInt32Array indices;
    indices.resize(size);

    // Fill the indices with [0, 1, 2, ..., size-1]
    int32_t *indices_ptr = indices.ptrw();
    for (int i = 0; i < size; ++i)
        indices_ptr[i] = i;

    // Sort the indices in place based on values
    std::sort(indices_ptr, indices_ptr + size,
        [&values](int a, int b) {
            return values[a] < values[b];
        });

    return indices;
}


PackedInt32Array GDStreamUtils::get_sorted_indices_f32(const PackedFloat32Array &values) {
    return get_sorted_container( values ); 
}

PackedInt32Array GDStreamUtils::get_sorted_indices_i32(const PackedInt32Array &values) {
    return get_sorted_container( values ); 
}

PackedInt32Array GDStreamUtils::get_sorted_indices_string(const PackedStringArray &values) {
    return get_sorted_container( values ); 
}

PackedVector3Array GDStreamUtils::sample_around(
    const PackedVector3Array& positions,
    const PackedVector3Array& sizes,
    float radius,
    float max_radius,
    int32_t max_points,
    uint64_t seed) {
  PackedVector3Array new_positions;
  const int32_t source_count = positions.size();
  if (source_count == 0 || sizes.size() < source_count || max_points <= 0)
    return new_positions;

  // A static KD-tree handles the potentially much larger max_radius query.
  // For the minimum-distance test, Bridson's uniform XZ grid only needs the 9
  // adjacent cells and is cheaper to update than a dynamic KD-tree. Distances
  // are still checked in 3D to preserve the GDScript implementation exactly.
  Ref<GDKdTree> sources_spatial;
  sources_spatial.instantiate();
  sources_spatial->set_points(positions);

  std::vector<Vector3> candidate_positions;
  std::vector<float> candidate_radii;
  candidate_positions.reserve(static_cast<size_t>(source_count) + max_points);
  candidate_radii.reserve(static_cast<size_t>(source_count) + max_points);

  const float minimum_distance = Math::abs(radius);
  const float minimum_distance_squared = minimum_distance * minimum_distance;
  const float cell_size = minimum_distance > 0.0f ? minimum_distance : 1.0f;
  const auto cell_for = [cell_size](const Vector3& point) -> GridCell {
    return {
      static_cast<int32_t>(Math::floor(point.x / cell_size)),
      static_cast<int32_t>(Math::floor(point.z / cell_size)),
    };
  };

  std::unordered_map<GridCell, std::vector<int32_t>, GridCellHash> proximity_grid;
  proximity_grid.reserve(static_cast<size_t>(source_count + max_points));

  std::deque<int32_t> active;
  for (int32_t i = 0; i < source_count; ++i) {
    candidate_positions.push_back(positions[i]);
    const Vector3 planar_size(sizes[i].x, 0.0f, sizes[i].z);
    candidate_radii.push_back(planar_size.length());
    active.push_back(i);
    proximity_grid[cell_for(positions[i])].push_back(i);
  }

  const auto is_too_close = [&](const Vector3& point) -> bool {
    if (minimum_distance_squared == 0.0f)
      return false;

    const GridCell center_cell = cell_for(point);
    for (int32_t z = center_cell.z - 1; z <= center_cell.z + 1; ++z) {
      for (int32_t x = center_cell.x - 1; x <= center_cell.x + 1; ++x) {
        const auto found = proximity_grid.find({x, z});
        if (found == proximity_grid.end())
          continue;
        for (const int32_t index : found->second) {
          if (candidate_positions[index].distance_squared_to(point) < minimum_distance_squared)
            return true;
        }
      }
    }
    return false;
  };

  Ref<RandomNumberGenerator> rng;
  rng.instantiate();
  rng->set_seed(seed);

  new_positions.resize(max_points);
  int32_t accepted_count = 0;
  for (int32_t iteration = 0; iteration < max_points && !active.empty(); ++iteration) {
    const int32_t point_id = active.front();
    const Vector3 center = candidate_positions[point_id];
    const float center_radius = candidate_radii[point_id];
    bool accepted = false;

    for (int32_t attempt = 0; attempt < 8; ++attempt) {
      const float angle = rng->randf() * static_cast<float>(Math_TAU);
      const float radius_factor = rng->randf_range(1.0f, 2.0f);
      const Vector3 direction(Math::cos(angle), 0.0f, Math::sin(angle));
      const Vector3 candidate = center + direction *
        ((center_radius + radius * radius_factor) * 1.02f * 0.5f);

      if (is_too_close(candidate))
        continue;
      if (!sources_spatial->is_close(candidate, max_radius))
        continue;

      const int32_t new_index = static_cast<int32_t>(candidate_positions.size());
      new_positions[accepted_count++] = candidate;
      candidate_positions.push_back(candidate);
      candidate_radii.push_back(radius);
      active.push_back(new_index);
      proximity_grid[cell_for(candidate)].push_back(new_index);
      accepted = true;
      break;
    }

    if (!accepted)
      active.pop_front();
  }

  new_positions.resize(accepted_count);
  return new_positions;
}

Dictionary GDStreamUtils::KMeans(
    const PackedVector3Array& points,
    int32_t num_clusters,
    int32_t max_iterations,
    float tolerance,
    uint32_t seed) {
  const size_t n = points.size();

  Dictionary ret;
  ret["result"] = false;

  if (n == 0 || num_clusters <= 0)
    return ret;

  if (static_cast<size_t>(num_clusters) > n)
    num_clusters = static_cast<int32_t>(n);

  std::mt19937 rng(seed);

  PackedVector3Array centroids;
  centroids.resize(num_clusters);

  PackedInt32Array labels;
  labels.resize(n);
  labels.fill(-1);

  // ------------------------------------------------------------
  // K-Means++ initialization
  // ------------------------------------------------------------

  std::uniform_int_distribution<size_t> firstDist(0, n - 1);
  centroids[0] = points[firstDist(rng)];

  PackedFloat32Array minDistSq;
  minDistSq.resize(n);

  for (size_t i = 0; i < n; ++i)
    minDistSq[i] = points[i].distance_squared_to(centroids[0]);

    for (int32_t c = 1; c < num_clusters; ++c) {
      double total = 0.0;

      for (float d : minDistSq)
        total += d;

      if (total <= 0.0) {
        centroids[c] = points[firstDist(rng)];
        continue;
      }

      std::uniform_real_distribution<double> pick(0.0, total);
      const double target = pick(rng);

      double accumulated = 0.0;
      size_t selected = n - 1;

      for (size_t i = 0; i < n; ++i) {
        accumulated += minDistSq[i];
        if (accumulated >= target) {
          selected = i;
          break;
        }
      }

      centroids[c] = points[selected];

      // Update distance to nearest chosen centroid.
      for (size_t i = 0; i < n; ++i) {
        const float d = points[i].distance_squared_to(centroids[c]);
        if (d < minDistSq[i])
          minDistSq[i] = d;
      }
    }

    // ------------------------------------------------------------
    // Lloyd iterations
    // ------------------------------------------------------------
    struct Accumulator {
      double x = 0.0;
      double y = 0.0;
      double z = 0.0;
      size_t count = 0;
    };

    Vector<Accumulator> accumulators;
    accumulators.resize(num_clusters);
    Accumulator* accs = accumulators.ptrw();

    for (int32_t iteration = 0; iteration < max_iterations; ++iteration) {
      bool assignmentsChanged = false;

      for (auto& acc : accumulators)
        acc = {};

      // Assign each point to nearest centroid.
      for (size_t i = 0; i < n; ++i) {
        int32_t bestCluster = 0;
        float bestDistance = points[i].distance_squared_to(centroids[0]);

        for (int32_t c = 1; c < num_clusters; ++c) {
          const float d = points[i].distance_squared_to(centroids[c]);

          if (d < bestDistance) {
            bestDistance = d;
            bestCluster = c;
          }
        }

        if (labels[i] != bestCluster) {
          labels[i] = bestCluster;
          assignmentsChanged = true;
        }

        Accumulator& acc = accs[bestCluster];
        acc.x += points[i].x;
        acc.y += points[i].y;
        acc.z += points[i].z;
        ++acc.count;
      }

      float maxCentroidMovementSq = 0.0f;

      // Recalculate centroids.
      for (int32_t c = 0; c < num_clusters; ++c) {
        if (accumulators[c].count == 0) {
          // Empty cluster:
          // reinitialize it to a random point.
          centroids[c] = points[firstDist(rng)];
          continue;
        }

        const Vector3 newCentroid {
          static_cast<float>(accumulators[c].x / accumulators[c].count),
          static_cast<float>(accumulators[c].y / accumulators[c].count),
          static_cast<float>(accumulators[c].z / accumulators[c].count)
        };

        const float movementSq = centroids[c].distance_squared_to(newCentroid);
        if (movementSq > maxCentroidMovementSq)
          maxCentroidMovementSq = movementSq;

        centroids[c] = newCentroid;
      }

      if (!assignmentsChanged)
        break;

      if (maxCentroidMovementSq <= tolerance * tolerance)
        break;
    }

  ret[ "result" ] = true;
  ret[ "labels" ] = labels;
  ret[ "centroids" ] = centroids;

  return ret;
}
