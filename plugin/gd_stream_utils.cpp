#include "gd_stream_utils.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GDStreamUtils::_bind_methods() {
  ClassDB::bind_static_method("GDStreamUtils", D_METHOD("get_sorted_indices_f32", "values"), &GDStreamUtils::get_sorted_indices_f32);
}

PackedInt32Array GDStreamUtils::get_sorted_indices_f32(const PackedFloat32Array &values) {
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

