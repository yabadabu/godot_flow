@tool
class_name FlowComputeShaderSource
extends RefCounted

const DEFAULT_LOCAL_SIZE_X := 64

const PARAMETER_TYPES := {
	"bool": true,
	"int": true,
	"uint": true,
	"float": true,
	"ivec2": true,
	"ivec3": true,
	"ivec4": true,
	"uvec2": true,
	"uvec3": true,
	"uvec4": true,
	"vec2": true,
	"vec3": true,
	"vec4": true,
}

const BUFFER_TYPES := {
	"int": true,
	"float": true,
	"vec3": true,
	"vec4": true,
}

const DIRECTIVE_KINDS := {
	"flow_param": "param",
	"flow_ro": "ro",
	"flow_rw": "rw",
	"flow_out": "out",
}

const RESERVED_NAMES := {
	"FlowSize": true,
	"FlowKernel": true,
	"main": true,
}

const REFLECTED_TYPE_NAMES := {
	"bool": "bool",
	"int": "int",
	"uint": "uint",
	"float": "float",
	"ivec2": "int2",
	"ivec3": "int3",
	"ivec4": "int4",
	"uvec2": "uint2",
	"uvec3": "uint3",
	"uvec4": "uint4",
	"vec2": "float2",
	"vec3": "float3",
	"vec4": "float4",
}


static func parse(source_code: String) -> Dictionary:
	var parameters: Array[Dictionary] = []
	var buffers: Array[Dictionary] = []
	var errors: Array[String] = []
	var kernel_lines := PackedStringArray()
	var declared_names := {}
	var identifier_regex := RegEx.new()
	identifier_regex.compile("^[A-Za-z_][A-Za-z0-9_]*$")

	var lines := source_code.split("\n", true)
	for line_index in lines.size():
		var line: String = lines[line_index]
		var stripped := line.strip_edges()
		if not stripped.begins_with("#pragma flow_"):
			kernel_lines.append(line)
			continue

		# Preserve the line number of all user code that follows the directive.
		kernel_lines.append("")
		var tokens := stripped.split(" ", false)
		if tokens.size() != 4:
			errors.append(
				"Line %d: expected '#pragma flow_<kind> <type> <name>'." % (line_index + 1)
			)
			continue

		var directive: String = tokens[1]
		var data_type: String = tokens[2]
		var declaration_name: String = tokens[3]
		if not DIRECTIVE_KINDS.has(directive):
			errors.append("Line %d: unknown Flow pragma '%s'." % [line_index + 1, directive])
			continue

		var kind: String = DIRECTIVE_KINDS[directive]
		var allowed_types: Dictionary = PARAMETER_TYPES if kind == "param" else BUFFER_TYPES
		if not allowed_types.has(data_type):
			errors.append(
				"Line %d: type '%s' is not supported for %s." % [
					line_index + 1, data_type, directive
				]
			)
			continue
		if identifier_regex.search(declaration_name) == null:
			errors.append("Line %d: '%s' is not a valid identifier." % [
				line_index + 1, declaration_name
			])
			continue
		if RESERVED_NAMES.has(declaration_name):
			errors.append("Line %d: '%s' is reserved by Flow." % [
				line_index + 1, declaration_name
			])
			continue
		if declared_names.has(declaration_name):
			errors.append("Line %d: '%s' is declared more than once." % [
				line_index + 1, declaration_name
			])
			continue

		declared_names[declaration_name] = true
		var declaration := {
			"kind": kind,
			"type": data_type,
			"name": declaration_name,
			"line": line_index + 1,
		}
		if kind == "param":
			parameters.append(declaration)
		else:
			declaration["binding"] = buffers.size() + 1
			buffers.append(declaration)

	return {
		"ok": errors.is_empty(),
		"error": "\n".join(errors),
		"errors": errors,
		"parameters": parameters,
		"buffers": buffers,
		"kernel_source": "\n".join(kernel_lines),
	}


static func generate(source_code: String, local_size_x := DEFAULT_LOCAL_SIZE_X) -> Dictionary:
	var parsed := parse(source_code)
	if not parsed.ok:
		parsed["shader_source"] = ""
		return parsed
	if local_size_x < 1 or local_size_x > 1024:
		parsed.ok = false
		parsed.error = "local_size_x must be between 1 and 1024."
		parsed.errors = [parsed.error]
		parsed["shader_source"] = ""
		return parsed

	var generated := PackedStringArray([
		"#version 450",
		"",
		"layout(local_size_x = %d, local_size_y = 1, local_size_z = 1) in;" % local_size_x,
		"",
		"layout(set = 0, binding = 0, std140) uniform FlowParameters {",
		"\tuint FlowSize;",
	])
	for parameter in parsed.parameters:
		generated.append("\t%s %s;" % [parameter.type, parameter.name])
	generated.append("};")

	for buffer in parsed.buffers:
		generated.append("")
		var access_qualifiers := "readonly restrict " if buffer.kind == "ro" else "restrict "
		generated.append(
			"layout(set = 0, binding = %d, std430) %sbuffer FlowBuffer_%s {" % [
				buffer.binding, access_qualifiers, buffer.name
			]
		)
		generated.append("\t%s %s[];" % [buffer.type, buffer.name])
		generated.append("};")

	generated.append("")
	generated.append("#line 1")
	generated.append(parsed.kernel_source)
	generated.append("")
	generated.append("void main()")
	generated.append("{")
	generated.append("\tuint index = gl_GlobalInvocationID.x;")
	generated.append("\tif (index < FlowSize)")
	generated.append("\t\tFlowKernel(index);")
	generated.append("}")

	parsed["shader_source"] = "\n".join(generated)
	parsed["local_size_x"] = local_size_x
	return parsed


static func compile_and_reflect(
	rd: RenderingDevice,
	source_code: String,
	local_size_x := DEFAULT_LOCAL_SIZE_X
) -> Dictionary:
	var result := generate(source_code, local_size_x)
	result["bytecode"] = PackedByteArray()
	result["spirv"] = null
	result["reflection"] = {}
	if not result.ok:
		return result
	if rd == null:
		return _with_error(result, "Unable to create a RenderingDevice.")

	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = result.shader_source
	var spirv := rd.shader_compile_spirv_from_source(shader_source, false)
	var compile_error := spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not compile_error.is_empty():
		return _with_error(result, compile_error)
	if spirv.bytecode_compute.is_empty():
		return _with_error(result, "GLSL compilation returned empty compute bytecode.")

	result.bytecode = spirv.bytecode_compute
	result.spirv = spirv
	result.reflection = GDShaderReflection.reflect_compute(result.bytecode, "main")
	if not result.reflection.ok:
		return _with_error(result, result.reflection.error)

	var contract_error := _validate_reflection(result, result.reflection)
	if not contract_error.is_empty():
		return _with_error(result, contract_error)
	return result


static func _validate_reflection(contract: Dictionary, reflection: Dictionary) -> String:
	var parameter_buffer := _find_binding(reflection.constant_buffers, 0)
	if parameter_buffer.is_empty():
		return "Generated FlowParameters buffer is missing at set 0, binding 0."

	var size_member := _find_named(parameter_buffer.members, "FlowSize")
	if size_member.is_empty() or size_member.type.name != "uint":
		return "Generated FlowSize parameter does not reflect as uint."
	for parameter in contract.parameters:
		var member := _find_named(parameter_buffer.members, parameter.name)
		if member.is_empty():
			return "Parameter '%s' is missing from SPIR-V reflection." % parameter.name
		var expected_type: String = REFLECTED_TYPE_NAMES[parameter.type]
		if member.type.name != expected_type:
			return "Parameter '%s' reflects as %s instead of %s." % [
				parameter.name, member.type.name, expected_type
			]

	for buffer in contract.buffers:
		var reflected := _find_binding(reflection.storage_buffers, buffer.binding)
		if reflected.is_empty():
			return "Buffer '%s' is missing at set 0, binding %d." % [
				buffer.name, buffer.binding
			]
		var expected_type: String = REFLECTED_TYPE_NAMES[buffer.type]
		if reflected.element_type != expected_type:
			return "Buffer '%s' reflects as %s instead of %s." % [
				buffer.name, reflected.element_type, expected_type
			]
		var expected_access := "readonly" if buffer.kind == "ro" else "readwrite"
		if reflected.access != expected_access:
			return "Buffer '%s' reflects as %s instead of %s." % [
				buffer.name, reflected.access, expected_access
			]
		if reflected.element_stride <= 0:
			return "Buffer '%s' has an invalid reflected element stride." % buffer.name
	return ""


static func _find_binding(items: Array, binding: int) -> Dictionary:
	for item in items:
		if item.set == 0 and item.binding == binding:
			return item
	return {}


static func _find_named(items: Array, wanted_name: String) -> Dictionary:
	for item in items:
		if item.name == wanted_name:
			return item
	return {}


static func _with_error(result: Dictionary, message: String) -> Dictionary:
	result.ok = false
	result.error = message
	result.errors = [message]
	return result
