#include "gd_kdtree.h"

using namespace godot;

//#define dbg godot::UtilityFunctions::print
#define dbg(...)

void GDKdTree::_bind_methods() {
  ClassDB::bind_method(D_METHOD("set_points"), &GDKdTree::set_points);
  ClassDB::bind_method(D_METHOD("find_nearest_idx"), &GDKdTree::find_nearest_idx);
  ClassDB::bind_method(D_METHOD("find_nearest_indices"), &GDKdTree::find_nearest_indices);
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
  nanoflann::KNNResultSet<float> results(1);
  size_t return_idx = -1;
  float out_distance;
  results.init(&return_idx, &out_distance);
  tree->findNeighbors(results, &pos.x, nanoflann::SearchParams(3));
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
  nanoflann::KNNResultSet<float> results(2);
  size_t nearest_indices[2];
  float out_distances[2];
  const int index_to_read = self_distances ? 1 : 0;

  // This could be executed in parallel
  for( size_t i=0; i<num_elems; ++i, ++pos_addr ) {
    results.init(nearest_indices, out_distances);
    if( !tree->findNeighbors(results, &pos_addr->x, nanoflann::SearchParams(3)))
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