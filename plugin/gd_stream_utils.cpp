#include "gd_stream_utils.h"
#include <godot_cpp/core/class_db.hpp>
#include <random>
#include <algorithm>

using namespace godot;

void GDStreamUtils::_bind_methods() {
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_f32", "values"), &GDStreamUtils::get_sorted_indices_f32);
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_i32", "values"), &GDStreamUtils::get_sorted_indices_i32);
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_string", "values"), &GDStreamUtils::get_sorted_indices_string);
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