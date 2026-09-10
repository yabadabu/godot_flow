#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Thin Godot-facing wrapper around Khronos SPIRV-Reflect. It deliberately
// returns a language-neutral Dictionary so the flow graph does not depend on
// HLSL-specific compiler details after source compilation.
class GDShaderReflection : public Object {
  GDCLASS(GDShaderReflection, Object)

protected:
  static void _bind_methods();

public:
  static Dictionary reflect_compute(
    const PackedByteArray &spirv,
    const String &entry_point = String());
};

} // namespace godot
