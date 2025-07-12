#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

// -------------------------------------------------
class GDStreamUtils : public Object {
  GDCLASS(GDStreamUtils, Object)

protected:
  static void _bind_methods();

public:
  static PackedInt32Array get_sorted_indices_f32(const PackedFloat32Array &values);
};

}
