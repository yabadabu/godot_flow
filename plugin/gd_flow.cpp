#include "gd_flow.h"
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;
void FlowOp::_bind_methods() {
  //ClassDB::bind_method("FlowOp", D_METHOD("my_static_function", "input"), &FlowOp::my_static_function);
  ClassDB::bind_static_method("FlowOp", D_METHOD("my_static_function", "input"), &FlowOp::my_static_function);
}

FlowOp::FlowOp() {
}

FlowOp::~FlowOp() {
}

void FlowOp::clear() {
  tree.RemoveAll();
}

void FlowOp::add( Vector3 pmin, Vector3 pmax, int id ) {
  // float vmin[2] = { aabb.center.x - aabb.half.x, aabb.center.z - aabb.half.z };
  // float vmax[2] = { aabb.center.x + aabb.half.x, aabb.center.z + aabb.half.z };
  tree.Insert(&pmin.x, &pmax.x, id);

    // nhits = tree.Search(vmin, vmax, [this](const int& id) -> bool{
    //   const TStoredData& s = all_instances[id];
    //   render_instances.emplace_back(asWorld(s.aabb), s.color);
    //   return true;
    //   });

}

void FlowOp::addArray( const PackedVector3Array& in_min, const PackedVector3Array& in_max, int id_base ) {

}


int FlowOp::my_static_function(int input) {
  UtilityFunctions::print( "FlowOp::my_static_function" );
  return input * 2; // Example: double the input
}