#include "gd_rtree.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include "bit_buffer.h"

using namespace godot;

void GDRTree::_bind_methods() {
  ClassDB::bind_method(D_METHOD("clear"), &GDRTree::clear);
  ClassDB::bind_method(D_METHOD("add"), &GDRTree::add);
  ClassDB::bind_method(D_METHOD("overlaps"), &GDRTree::overlaps);
}

GDRTree::GDRTree() {
}

GDRTree::~GDRTree() {
}

void GDRTree::clear() {
  tree.RemoveAll();
}

bool GDRTree::add( const PackedVector3Array& in_min, const PackedVector3Array& in_max, int id_base ) {
  
  if( in_min.size() != in_max.size() )
    return false;

  if( id_base < 0 )
    return false;

  const Vector3 *min_data = in_min.ptr();
  const Vector3 *max_data = in_max.ptr();

  int id = id_base;
  const size_t i_max = in_min.size();
  for( size_t i=0; i<i_max; ++i, ++id )
    tree.Insert(&min_data[i].x, &max_data[i].x, id);

  size += i_max;
  return true;
}

Dictionary GDRTree::overlaps( const PackedVector3Array& others_min, const PackedVector3Array& others_max ) const {

  BitBuffer bb_my_idxs_overlapped_by_others;
  PackedInt32Array other_idxs_overlapping_me;

  bool result = false;
  if( others_min.size() == others_max.size() ) {
    const size_t i_max = others_min.size();
    for( size_t i=0; i<i_max; ++i ) {
      
      const float* vmin = &others_min[i].x;
      const float* vmax = &others_max[i].x;

      if( tree.Search(vmin, vmax, [&bb_my_idxs_overlapped_by_others](const int& id) -> bool {
        bb_my_idxs_overlapped_by_others.set_bit( id, true );
        return true;
        })) {
        other_idxs_overlapping_me.push_back( i );
      }
    }
    result = true;
  }

  const size_t my_max = size;
  PackedInt32Array my_idxs_overlapped_by_others;
  for( size_t i=0; i<my_max; ++i ) {
    if( bb_my_idxs_overlapped_by_others.get_bit( i ))
      my_idxs_overlapped_by_others.push_back( i );
  }

  Dictionary ret;
  ret["result"] = result;
  ret["my_idxs_overlapped_by_others"] = my_idxs_overlapped_by_others;
  ret["other_idxs_overlapping_me"] = other_idxs_overlapping_me;
  return ret;
}
