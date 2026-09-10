#include "gd_shader_reflection.h"

#include "spirv_reflect.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#include <algorithm>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {

String safe_string(const char *value) {
  return value == nullptr ? String() : String::utf8(value);
}

String reflect_result_name(SpvReflectResult result) {
  switch (result) {
    case SPV_REFLECT_RESULT_SUCCESS: return "success";
    case SPV_REFLECT_RESULT_NOT_READY: return "not_ready";
    case SPV_REFLECT_RESULT_ERROR_PARSE_FAILED: return "parse_failed";
    case SPV_REFLECT_RESULT_ERROR_ALLOC_FAILED: return "allocation_failed";
    case SPV_REFLECT_RESULT_ERROR_RANGE_EXCEEDED: return "range_exceeded";
    case SPV_REFLECT_RESULT_ERROR_NULL_POINTER: return "null_pointer";
    case SPV_REFLECT_RESULT_ERROR_INTERNAL_ERROR: return "internal_error";
    case SPV_REFLECT_RESULT_ERROR_COUNT_MISMATCH: return "count_mismatch";
    case SPV_REFLECT_RESULT_ERROR_ELEMENT_NOT_FOUND: return "element_not_found";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_CODE_SIZE: return "invalid_code_size";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_MAGIC_NUMBER: return "invalid_magic_number";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_UNEXPECTED_EOF: return "unexpected_eof";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_ID_REFERENCE: return "invalid_id_reference";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_SET_NUMBER_OVERFLOW: return "set_number_overflow";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_STORAGE_CLASS: return "invalid_storage_class";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_RECURSION: return "recursive_type";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_INSTRUCTION: return "invalid_instruction";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_UNEXPECTED_BLOCK_DATA: return "unexpected_block_data";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_BLOCK_MEMBER_REFERENCE: return "invalid_block_member_reference";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_ENTRY_POINT: return "invalid_entry_point";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_EXECUTION_MODE: return "invalid_execution_mode";
    case SPV_REFLECT_RESULT_ERROR_SPIRV_MAX_RECURSIVE_EXCEEDED: return "max_recursion_exceeded";
    default: return "unknown_error_" + String::num_int64(static_cast<int64_t>(result));
  }
}

Dictionary error_result(const String &message) {
  Dictionary result;
  result["ok"] = false;
  result["error"] = message;
  result["entry_point"] = Dictionary();
  result["constant_buffers"] = Array();
  result["storage_buffers"] = Array();
  result["unsupported_resources"] = Array();
  return result;
}

String descriptor_type_name(SpvReflectDescriptorType type) {
  switch (type) {
    case SPV_REFLECT_DESCRIPTOR_TYPE_SAMPLER: return "sampler";
    case SPV_REFLECT_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER: return "combined_image_sampler";
    case SPV_REFLECT_DESCRIPTOR_TYPE_SAMPLED_IMAGE: return "sampled_image";
    case SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_IMAGE: return "storage_image";
    case SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER: return "uniform_texel_buffer";
    case SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER: return "storage_texel_buffer";
    case SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_BUFFER: return "uniform_buffer";
    case SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_BUFFER: return "storage_buffer";
    case SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC: return "uniform_buffer_dynamic";
    case SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC: return "storage_buffer_dynamic";
    case SPV_REFLECT_DESCRIPTOR_TYPE_INPUT_ATTACHMENT: return "input_attachment";
    case SPV_REFLECT_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR: return "acceleration_structure";
    default: return "unknown";
  }
}

String user_type_name(SpvReflectUserType type) {
  switch (type) {
    case SPV_REFLECT_USER_TYPE_CBUFFER: return "cbuffer";
    case SPV_REFLECT_USER_TYPE_CONSTANT_BUFFER: return "constant_buffer";
    case SPV_REFLECT_USER_TYPE_STRUCTURED_BUFFER: return "structured_buffer";
    case SPV_REFLECT_USER_TYPE_RW_STRUCTURED_BUFFER: return "rw_structured_buffer";
    case SPV_REFLECT_USER_TYPE_BUFFER: return "buffer";
    case SPV_REFLECT_USER_TYPE_RW_BUFFER: return "rw_buffer";
    case SPV_REFLECT_USER_TYPE_BYTE_ADDRESS_BUFFER: return "byte_address_buffer";
    case SPV_REFLECT_USER_TYPE_RW_BYTE_ADDRESS_BUFFER: return "rw_byte_address_buffer";
    case SPV_REFLECT_USER_TYPE_APPEND_STRUCTURED_BUFFER: return "append_structured_buffer";
    case SPV_REFLECT_USER_TYPE_CONSUME_STRUCTURED_BUFFER: return "consume_structured_buffer";
    case SPV_REFLECT_USER_TYPE_INVALID: return "invalid";
    default: return "other";
  }
}

String scalar_type_name(const SpvReflectTypeDescription *type) {
  if (type == nullptr) {
    return "unknown";
  }

  const SpvReflectTypeFlags flags = type->type_flags;
  const uint32_t width = type->traits.numeric.scalar.width;
  String scalar;

  if ((flags & SPV_REFLECT_TYPE_FLAG_BOOL) != 0) {
    scalar = "bool";
  } else if ((flags & SPV_REFLECT_TYPE_FLAG_INT) != 0) {
    scalar = type->traits.numeric.scalar.signedness != 0 ? "int" : "uint";
    if (width != 0 && width != 32) {
      scalar += String::num_uint64(width);
    }
  } else if ((flags & SPV_REFLECT_TYPE_FLAG_FLOAT) != 0) {
    switch (width) {
      case 16: scalar = "half"; break;
      case 64: scalar = "double"; break;
      default: scalar = "float"; break;
    }
  } else if ((flags & SPV_REFLECT_TYPE_FLAG_STRUCT) != 0) {
    const String reflected_name = safe_string(type->type_name);
    return reflected_name.is_empty() ? String("struct") : reflected_name;
  } else {
    return "unknown";
  }

  const uint32_t component_count = type->traits.numeric.vector.component_count;
  if ((flags & SPV_REFLECT_TYPE_FLAG_VECTOR) != 0 && component_count > 1) {
    scalar += String::num_uint64(component_count);
  }

  if ((flags & SPV_REFLECT_TYPE_FLAG_MATRIX) != 0) {
    scalar += "x" + String::num_uint64(type->traits.numeric.matrix.column_count);
  }

  return scalar;
}

Dictionary type_to_dict(const SpvReflectTypeDescription *type) {
  Dictionary result;
  if (type == nullptr) {
    result["name"] = "unknown";
    return result;
  }

  result["name"] = scalar_type_name(type);
  result["reflected_name"] = safe_string(type->type_name);
  result["flags"] = static_cast<int64_t>(type->type_flags);
  result["scalar_width"] = static_cast<int64_t>(type->traits.numeric.scalar.width);
  result["signed"] = type->traits.numeric.scalar.signedness != 0;
  result["component_count"] = static_cast<int64_t>(type->traits.numeric.vector.component_count);
  result["matrix_columns"] = static_cast<int64_t>(type->traits.numeric.matrix.column_count);
  result["matrix_rows"] = static_cast<int64_t>(type->traits.numeric.matrix.row_count);
  result["matrix_stride"] = static_cast<int64_t>(type->traits.numeric.matrix.stride);
  result["array_stride"] = static_cast<int64_t>(type->traits.array.stride);

  Array dimensions;
  for (uint32_t i = 0; i < type->traits.array.dims_count; ++i) {
    dimensions.push_back(static_cast<int64_t>(type->traits.array.dims[i]));
  }
  result["array_dimensions"] = dimensions;
  return result;
}

Dictionary block_variable_to_dict(const SpvReflectBlockVariable &variable) {
  Dictionary result;
  result["name"] = safe_string(variable.name);
  result["offset"] = static_cast<int64_t>(variable.offset);
  result["absolute_offset"] = static_cast<int64_t>(variable.absolute_offset);
  result["size"] = static_cast<int64_t>(variable.size);
  result["padded_size"] = static_cast<int64_t>(variable.padded_size);
  result["array_stride"] = static_cast<int64_t>(variable.array.stride);
  result["matrix_stride"] = static_cast<int64_t>(variable.numeric.matrix.stride);
  result["decoration_flags"] = static_cast<int64_t>(variable.decoration_flags);
  result["type"] = type_to_dict(variable.type_description);

  Array members;
  for (uint32_t i = 0; i < variable.member_count; ++i) {
    members.push_back(block_variable_to_dict(variable.members[i]));
  }
  result["members"] = members;
  return result;
}

SpvReflectDecorationFlags combined_decorations(const SpvReflectDescriptorBinding &binding) {
  SpvReflectDecorationFlags flags = binding.decoration_flags | binding.block.decoration_flags;
  for (uint32_t i = 0; i < binding.block.member_count; ++i) {
    flags |= binding.block.members[i].decoration_flags;
  }
  return flags;
}

String storage_access_name(const SpvReflectDescriptorBinding &binding) {
  switch (binding.user_type) {
    case SPV_REFLECT_USER_TYPE_STRUCTURED_BUFFER:
    case SPV_REFLECT_USER_TYPE_BUFFER:
    case SPV_REFLECT_USER_TYPE_BYTE_ADDRESS_BUFFER:
      return "readonly";
    case SPV_REFLECT_USER_TYPE_RW_STRUCTURED_BUFFER:
    case SPV_REFLECT_USER_TYPE_RW_BUFFER:
    case SPV_REFLECT_USER_TYPE_RW_BYTE_ADDRESS_BUFFER:
    case SPV_REFLECT_USER_TYPE_APPEND_STRUCTURED_BUFFER:
    case SPV_REFLECT_USER_TYPE_CONSUME_STRUCTURED_BUFFER:
      return "readwrite";
    default:
      break;
  }

  const SpvReflectDecorationFlags flags = combined_decorations(binding);
  if ((flags & SPV_REFLECT_DECORATION_NON_WRITABLE) != 0) {
    return "readonly";
  }
  if ((flags & SPV_REFLECT_DECORATION_NON_READABLE) != 0) {
    return "writeonly";
  }
  return "readwrite";
}

Dictionary descriptor_base_to_dict(const SpvReflectDescriptorBinding &binding) {
  Dictionary result;
  result["name"] = safe_string(binding.name);
  result["set"] = static_cast<int64_t>(binding.set);
  result["binding"] = static_cast<int64_t>(binding.binding);
  result["descriptor_type"] = descriptor_type_name(binding.descriptor_type);
  result["descriptor_type_value"] = static_cast<int64_t>(binding.descriptor_type);
  result["user_type"] = user_type_name(binding.user_type);
  result["user_type_value"] = static_cast<int64_t>(binding.user_type);
  result["decoration_flags"] = static_cast<int64_t>(combined_decorations(binding));
  result["accessed"] = binding.accessed != 0;
  result["block"] = block_variable_to_dict(binding.block);
  return result;
}

Dictionary constant_buffer_to_dict(const SpvReflectDescriptorBinding &binding) {
  Dictionary result = descriptor_base_to_dict(binding);
  result["size"] = static_cast<int64_t>(binding.block.size);
  result["padded_size"] = static_cast<int64_t>(binding.block.padded_size);

  Array members;
  for (uint32_t i = 0; i < binding.block.member_count; ++i) {
    members.push_back(block_variable_to_dict(binding.block.members[i]));
  }
  result["members"] = members;
  return result;
}

Dictionary storage_buffer_to_dict(const SpvReflectDescriptorBinding &binding) {
  Dictionary result = descriptor_base_to_dict(binding);
  result["access"] = storage_access_name(binding);

  if (binding.block.member_count > 0) {
    const SpvReflectBlockVariable &element = binding.block.members[0];
    uint32_t element_stride = element.array.stride;
    if (element_stride == 0 && element.type_description != nullptr) {
      element_stride = element.type_description->traits.array.stride;
    }
    result["element"] = block_variable_to_dict(element);
    result["element_type"] = scalar_type_name(element.type_description);
    result["element_stride"] = static_cast<int64_t>(element_stride);
  } else {
    result["element"] = Dictionary();
    result["element_type"] = "unknown";
    result["element_stride"] = static_cast<int64_t>(0);
  }
  return result;
}

bool descriptor_order(
  const SpvReflectDescriptorBinding *left,
  const SpvReflectDescriptorBinding *right) {
  if (left->set != right->set) {
    return left->set < right->set;
  }
  return left->binding < right->binding;
}

} // namespace

void GDShaderReflection::_bind_methods() {
  ClassDB::bind_static_method(
    "GDShaderReflection",
    D_METHOD("reflect_compute", "spirv", "entry_point"),
    &GDShaderReflection::reflect_compute,
    DEFVAL(String()));
}

Dictionary GDShaderReflection::reflect_compute(
  const PackedByteArray &spirv,
  const String &entry_point) {
  if (spirv.is_empty()) {
    return error_result("SPIR-V bytecode is empty");
  }
  if ((spirv.size() % sizeof(uint32_t)) != 0) {
    return error_result("SPIR-V bytecode size must be a multiple of four bytes");
  }

  SpvReflectShaderModule module = {};
  const SpvReflectResult create_result = spvReflectCreateShaderModule(
    static_cast<size_t>(spirv.size()),
    spirv.ptr(),
    &module);
  if (create_result != SPV_REFLECT_RESULT_SUCCESS) {
    return error_result("Unable to reflect SPIR-V: " + reflect_result_name(create_result));
  }

  const SpvReflectEntryPoint *selected_entry_point = nullptr;
  if (!entry_point.is_empty()) {
    const CharString entry_utf8 = entry_point.utf8();
    selected_entry_point = spvReflectGetEntryPoint(&module, entry_utf8.get_data());
  } else {
    for (uint32_t i = 0; i < module.entry_point_count; ++i) {
      if (module.entry_points[i].shader_stage == SPV_REFLECT_SHADER_STAGE_COMPUTE_BIT) {
        selected_entry_point = &module.entry_points[i];
        break;
      }
    }
  }

  if (selected_entry_point == nullptr) {
    const String requested = entry_point.is_empty() ? String("<first compute entry point>") : entry_point;
    spvReflectDestroyShaderModule(&module);
    return error_result("Compute entry point not found: " + requested);
  }
  if (selected_entry_point->shader_stage != SPV_REFLECT_SHADER_STAGE_COMPUTE_BIT) {
    spvReflectDestroyShaderModule(&module);
    return error_result("Requested entry point is not a compute shader");
  }

  uint32_t descriptor_count = 0;
  const SpvReflectResult count_result = spvReflectEnumerateEntryPointDescriptorBindings(
    &module,
    selected_entry_point->name,
    &descriptor_count,
    nullptr);
  if (count_result != SPV_REFLECT_RESULT_SUCCESS) {
    spvReflectDestroyShaderModule(&module);
    return error_result("Unable to enumerate shader resources: " + reflect_result_name(count_result));
  }

  std::vector<SpvReflectDescriptorBinding *> descriptors(descriptor_count);
  if (descriptor_count > 0) {
    const SpvReflectResult enumerate_result = spvReflectEnumerateEntryPointDescriptorBindings(
      &module,
      selected_entry_point->name,
      &descriptor_count,
      descriptors.data());
    if (enumerate_result != SPV_REFLECT_RESULT_SUCCESS) {
      spvReflectDestroyShaderModule(&module);
      return error_result("Unable to read shader resources: " + reflect_result_name(enumerate_result));
    }
  }
  std::sort(descriptors.begin(), descriptors.end(), descriptor_order);

  Array constant_buffers;
  Array storage_buffers;
  Array unsupported_resources;
  for (const SpvReflectDescriptorBinding *descriptor : descriptors) {
    if (descriptor->descriptor_type == SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_BUFFER ||
        descriptor->descriptor_type == SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC) {
      constant_buffers.push_back(constant_buffer_to_dict(*descriptor));
    } else if (descriptor->descriptor_type == SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_BUFFER ||
               descriptor->descriptor_type == SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC) {
      storage_buffers.push_back(storage_buffer_to_dict(*descriptor));
    } else {
      unsupported_resources.push_back(descriptor_base_to_dict(*descriptor));
    }
  }

  Dictionary entry;
  entry["name"] = safe_string(selected_entry_point->name);
  entry["local_size_x"] = static_cast<int64_t>(selected_entry_point->local_size.x);
  entry["local_size_y"] = static_cast<int64_t>(selected_entry_point->local_size.y);
  entry["local_size_z"] = static_cast<int64_t>(selected_entry_point->local_size.z);

  Dictionary result;
  result["ok"] = true;
  result["error"] = String();
  result["generator"] = static_cast<int64_t>(module.generator);
  result["source_language"] = static_cast<int64_t>(module.source_language);
  result["entry_point"] = entry;
  result["constant_buffers"] = constant_buffers;
  result["storage_buffers"] = storage_buffers;
  result["unsupported_resources"] = unsupported_resources;

  spvReflectDestroyShaderModule(&module);
  return result;
}
