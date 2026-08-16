#include "gd_kdtree.h"

using namespace godot;

//#define dbg godot::UtilityFunctions::print
#define dbg(...)

void GDKdTree::_bind_methods() {
  ClassDB::bind_method(D_METHOD("set_points"), &GDKdTree::set_points);
  ClassDB::bind_method(D_METHOD("find_nearest_idx"), &GDKdTree::find_nearest_idx);
  ClassDB::bind_method(D_METHOD("find_nearest_indices"), &GDKdTree::find_nearest_indices);
  ClassDB::bind_method(D_METHOD("cluster_by_distance"), &GDKdTree::cluster_by_distance);
  ClassDB::bind_method(D_METHOD("find_points_near"), &GDKdTree::find_points_near);
}

GDKdTree::GDKdTree( ) {
}

GDKdTree::~GDKdTree() {
  if( tree )
    delete tree;
}

int GDKdTree::find_nearest_idx( const Vector3& pos ) const {
  if (!tree || all.points.is_empty())
    return -1;
  nanoflann::KNNResultSet<Scalar> results(1);
  size_t return_idx = -1;
  Scalar out_distance;
  results.init(&return_idx, &out_distance);
  tree->findNeighbors(results, &pos.x, nanoflann::SearchParameters());
  return return_idx;
}

PackedInt32Array GDKdTree::find_nearest_indices( const PackedVector3Array& in_pos ) const {
  size_t num_elems = in_pos.size();

  // Hold nearest indices
  PackedInt32Array idxs;
  idxs.resize( num_elems );

  if (!tree || all.points.is_empty()) {
    idxs.fill(-1);
    return idxs;
  }

  const Vector3* pos_addr = in_pos.ptr();
  const bool self_distances = ( pos_addr == all.points.ptr() );

  // Setup 
  nanoflann::KNNResultSet<Scalar> results(2);
  size_t nearest_indices[2];
  Scalar out_distances[2];
  const int index_to_read = self_distances ? 1 : 0;

  // This could be executed in parallel
  for( size_t i=0; i<num_elems; ++i, ++pos_addr ) {
    results.init(nearest_indices, out_distances);
    if( !tree->findNeighbors(results, &pos_addr->x, nanoflann::SearchParameters()))
      idxs[ i ] = -1;
    else
      idxs[ i ] = nearest_indices[ index_to_read ];
  }  

  return idxs;
} 

void GDKdTree::set_points( const PackedVector3Array& in_pos ) {
  all.points = in_pos;
  if( tree ) {
    delete tree;
    tree = nullptr;
  }
  if (in_pos.is_empty())
    return;
  tree = new jTree(3, all, nanoflann::KDTreeSingleIndexAdaptorParams());
}

PackedInt32Array GDKdTree::cluster_by_distance(float max_distance) const {
  const size_t num_points = all.points.size();

  if (!tree || !num_points)
    return PackedInt32Array{};

  PackedInt32Array labels;
  labels.resize(num_points);
  labels.fill(-1);

  std::vector<size_t> queue;
  queue.reserve(64);

  // To store the neighbours of each query
  using ResultItem = nanoflann::ResultItem<size_t, Scalar>;
  std::vector<ResultItem> matches;
  matches.reserve(64);

  nanoflann::SearchParameters params;
  params.sorted = false;

  const Scalar radius_squared = max_distance * max_distance;

  int32_t cluster_index = 0;
  for (size_t start = 0; start < num_points; ++start) {
    if (labels[start] != -1)
      continue;

    labels[start] = cluster_index;

    queue.clear();
    queue.push_back(start);

    size_t queue_index = 0;
    while (queue_index < queue.size()) {
      const size_t current = queue[queue_index++];

      matches.clear();

      nanoflann::RadiusResultSet<Scalar, size_t> results( radius_squared, matches );

      tree->findNeighbors( results, &all.points[current].x, params );

      for (const auto& match : matches) {
        const size_t neighbor = match.first;
        if (labels[neighbor] == -1) {
          labels[neighbor] = cluster_index;
          queue.push_back(neighbor);
        }
      }
    }

    ++cluster_index;
  }

  return labels;
}


PackedInt32Array GDKdTree::find_points_near( const Vector3& pos, float max_distance ) const {

  if (!tree || all.points.is_empty())
    return PackedInt32Array{};

  // A container for the results
  using ResultItem = nanoflann::ResultItem<size_t, Scalar>;
  std::vector<ResultItem> matches;

  nanoflann::SearchParameters params;
  params.sorted = true;

  nanoflann::RadiusResultSet<Scalar, size_t> results( max_distance * max_distance, matches );
  tree->findNeighbors( results, &pos.x, params );

  PackedInt32Array near_indices;
  near_indices.resize( matches.size() );
  int32_t* ptr =near_indices.ptrw();
  for (const auto& match : matches)
    *ptr++ = match.first;
  return near_indices;
}