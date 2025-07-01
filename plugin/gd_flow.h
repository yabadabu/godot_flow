#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include "rtree.h"

using RTree3Df = RTree<int, float, 3>;

namespace godot {

// -------------------------------------------------
class FlowOp : public RefCounted {
  GDCLASS(FlowOp, RefCounted)

protected:
  static void _bind_methods();

  RTree3Df                 tree;

public:
  FlowOp();
  ~FlowOp();
  
  void clear();
  void add( Vector3 pmin, Vector3 pmax, int id );
  void addArray( const PackedVector3Array& in_min, const PackedVector3Array& in_max, int id_base );

  static int my_static_function(int input);

};

}
