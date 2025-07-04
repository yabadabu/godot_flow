#include "gd_kdtree.h"

using namespace godot;

//#define dbg godot::UtilityFunctions::print
#define dbg(...)

void GDKdTree::_bind_methods() {
  ClassDB::bind_method(D_METHOD("set_points"), &GDKdTree::set_points);
  ClassDB::bind_method(D_METHOD("find_nearest_idx"), &GDKdTree::find_nearest_idx);
}

GDKdTree::GDKdTree( ) {
}

GDKdTree::~GDKdTree() {
  if( tree )
    delete tree;
}

int GDKdTree::find_nearest_idx( const Vector3& pos ) const {
  nanoflann::KNNResultSet<float> results(1);
  size_t return_idx;
  float out_distance;
  results.init(&return_idx, &out_distance);
  tree->findNeighbors(results, &pos.x, nanoflann::SearchParams(3));
  return return_idx;
}

PackedInt32Array GDKdTree::find_nearest_indices( const PackedVector3Array& in_pos ) const {
  PackedInt32Array idxs;
  return idxs;
} 


void GDKdTree::set_points( const PackedVector3Array& in_pos ) {
  all.points = in_pos;
  if( tree )
    delete tree;
  tree = new jTree(3, all, nanoflann::KDTreeSingleIndexAdaptorParams());
}