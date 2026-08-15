#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

// -------------------------------------------------
class GDStreamUtils : public Object {
  GDCLASS(GDStreamUtils, Object)

protected:
  static void _bind_methods();

public:
  static PackedInt32Array get_sorted_indices_f32(const PackedFloat32Array &values);
  static PackedInt32Array get_sorted_indices_i32(const PackedInt32Array &values);
  static PackedInt32Array get_sorted_indices_string(const PackedStringArray &values);

  static Dictionary KMeans(
    const PackedVector3Array& points,
    int32_t num_clusters,
    int32_t max_iterations = 100,
    float tolerance = 1e-4f,
    uint32_t seed = 12345);
};

}
