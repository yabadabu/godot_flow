#include "gd_rtree.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include "bit_buffer.h"

using namespace godot;

//#define dbg godot::UtilityFunctions::print
#define dbg(...)

void GDRTree::_bind_methods() {
  ClassDB::bind_method(D_METHOD("clear"), &GDRTree::clear);
  ClassDB::bind_method(D_METHOD("add", "centers", "sizes"), &GDRTree::add);
  ClassDB::bind_method(D_METHOD("overlaps", "others_centers", "others_sizes", "return_overlapped"), &GDRTree::overlaps);
}

GDRTree::GDRTree() {
}

GDRTree::~GDRTree() {
}

void GDRTree::clear() {
  tree.RemoveAll();
  size = 0;
}

bool GDRTree::add( const PackedVector3Array& in_centers, const PackedVector3Array& in_sizes ) {
  
  if( in_centers.size() != in_sizes.size() )
    return false;

  const Vector3 *centers_data = in_centers.ptr();
  const Vector3 *sizes_data = in_sizes.ptr();

  int id = 0;
  const size_t i_max = in_centers.size();
  for( size_t i=0; i<i_max; ++i, ++id ) {
    const float* center = &in_centers[i].x;
    const float* size = &sizes_data[i].x;
    dbg( "Inserting ", id, " : ", center[0], ", ", center[1], ", ", center[2], ", ", size[0], ", ", size[1], ", ", size[2] );

    float pmin[3] = { center[0] - size[0] * 0.5f, center[1] - size[1] * 0.5f, center[2] - size[2] * 0.5f };
    float pmax[3] = { center[0] + size[0] * 0.5f, center[1] + size[1] * 0.5f, center[2] + size[2] * 0.5f };
    tree.Insert(pmin, pmax, id);
  }

  size += i_max;
  return true;
}

Dictionary GDRTree::overlaps( const PackedVector3Array& others_centers, const PackedVector3Array& others_sizes, bool return_overlapped ) const {

  BitBuffer bb_my_idxs_overlapped_by_others;
  //PackedInt32Array other_idxs_overlapping_me;

  bool result = false;
  if( others_centers.size() == others_sizes.size() ) {
    const size_t i_max = others_centers.size();
    for( size_t i=0; i<i_max; ++i ) {
      
      const float* center = &others_centers[i].x;
      const float* size = &others_sizes[i].x;
      dbg( "Overlap ", i, " : ", center[0], ", ", center[1], ", ", center[2], ", ", size[0], ", ", size[1], ", ", size[2] );

      float pmin[3] = { center[0] - size[0] * 0.5f, center[1] - size[1] * 0.5f, center[2] - size[2] * 0.5f };
      float pmax[3] = { center[0] + size[0] * 0.5f, center[1] + size[1] * 0.5f, center[2] + size[2] * 0.5f };

      if( tree.Search(pmin, pmax, [&bb_my_idxs_overlapped_by_others,i](const int& id) -> bool {
        dbg( "  Overlaps of ", i, " with!! ", id );
        bb_my_idxs_overlapped_by_others.set_bit( id, true );
        return true;
        })) {
        //other_idxs_overlapping_me.push_back( i );
      } else {
        //dbg( "  no overlap deletected for ", i );
      }
    }
    result = true;
  }

  const size_t my_max = size;
  PackedInt32Array my_idxs_overlapped_by_others;
  for( size_t i=0; i<my_max; ++i ) {
    if( bb_my_idxs_overlapped_by_others.get_bit( i ) == return_overlapped )
      my_idxs_overlapped_by_others.push_back( i );
  }

  Dictionary ret;
  ret["result"] = result;
  ret["idxs_overlapped"] = my_idxs_overlapped_by_others;
  //ret["other_idxs_overlapping_me"] = other_idxs_overlapping_me;
  return ret;
}
