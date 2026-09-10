@tool
extends BaseTest

const COMPUTE_SHADER_SOURCE = preload(
	"res://addons/flow_nodes_editor/flow_compute_shader_source.gd"
)

const USER_GLSL := """#pragma flow_param vec3 center
#pragma flow_param float strength
#pragma flow_param int iterations

#pragma flow_ro float density
#pragma flow_rw vec3 position
#pragma flow_out float result

void FlowKernel(uint index)
{
	vec3 direction = position[index] - center;
	position[index] += direction * strength;
	result[index] = density[index] + float(iterations);
}
"""


func _find_named(items: Array, wanted_name: String) -> Dictionary:
	for item in items:
		if item.name == wanted_name:
			return item
	return {}


func _find_binding(items: Array, wanted_binding: int) -> Dictionary:
	for item in items:
		if item.set == 0 and item.binding == wanted_binding:
			return item
	return {}


func test_flow_pragmas_generate_typed_contract() -> void:
	var generated := COMPUTE_SHADER_SOURCE.generate(USER_GLSL)
	assert_true(generated.ok, generated.error)
	if not generated.ok:
		return

	assert_eq(generated.parameters.size(), 3)
	assert_eq(generated.parameters[0], {
		"kind": "param", "type": "vec3", "name": "center", "line": 1,
	})
	assert_eq(generated.parameters[1].name, "strength")
	assert_eq(generated.parameters[2].type, "int")

	assert_eq(generated.buffers.size(), 3)
	assert_eq(generated.buffers[0].kind, "ro")
	assert_eq(generated.buffers[0].type, "float")
	assert_eq(generated.buffers[0].name, "density")
	assert_eq(generated.buffers[0].binding, 1)
	assert_eq(generated.buffers[1].kind, "rw")
	assert_eq(generated.buffers[1].binding, 2)
	assert_eq(generated.buffers[2].kind, "out")
	assert_eq(generated.buffers[2].binding, 3)

	var shader: String = generated.shader_source
	assert_true(shader.begins_with("#version 450"))
	assert_true(shader.contains("uniform FlowParameters"))
	assert_true(shader.contains("vec3 center;"))
	assert_true(shader.contains("readonly restrict buffer FlowBuffer_density"))
	assert_true(shader.contains("float density[];"))
	assert_true(shader.contains("restrict buffer FlowBuffer_position"))
	assert_true(shader.contains("vec3 position[];"))
	assert_true(shader.contains("FlowKernel(index);"))
	assert_false(shader.contains("#pragma flow_"))


func test_flow_pragmas_reject_ambiguous_contracts() -> void:
	var source := """
#pragma flow_ro bool flags
#pragma flow_rw vec3 position
#pragma flow_out float position
#pragma flow_param mat4 transform
#pragma flow_param float FlowSize
"""
	var generated := COMPUTE_SHADER_SOURCE.generate(source)
	assert_false(generated.ok)
	assert_true(generated.error.contains("type 'bool' is not supported for flow_ro"))
	assert_true(generated.error.contains("'position' is declared more than once"))
	assert_true(generated.error.contains("type 'mat4' is not supported for flow_param"))
	assert_true(generated.error.contains("'FlowSize' is reserved by Flow"))
	assert_eq(generated.shader_source, "")


func test_generated_glsl_compiles_and_matches_reflection() -> void:
	var generated := COMPUTE_SHADER_SOURCE.generate(USER_GLSL)
	assert_true(generated.ok, generated.error)
	if not generated.ok:
		return

	var rd := RenderingServer.create_local_rendering_device()
	assert_true(rd != null, "Unable to create a local RenderingDevice")
	if rd == null:
		return

	var compiled := COMPUTE_SHADER_SOURCE.compile_and_reflect(rd, USER_GLSL)
	assert_true(compiled.ok, compiled.error)
	if not compiled.ok:
		rd.free()
		return

	var reflection: Dictionary = compiled.reflection

	assert_eq(reflection.entry_point.name, "main")
	assert_eq(reflection.entry_point.local_size_x, 64)
	assert_eq(reflection.entry_point.local_size_y, 1)
	assert_eq(reflection.entry_point.local_size_z, 1)

	var parameters := _find_binding(reflection.constant_buffers, 0)
	assert_false(parameters.is_empty(), "FlowParameters was not reflected at set 0, binding 0")
	if not parameters.is_empty():
		assert_false(_find_named(parameters.members, "FlowSize").is_empty())
		assert_false(_find_named(parameters.members, "center").is_empty())
		assert_false(_find_named(parameters.members, "strength").is_empty())
		assert_false(_find_named(parameters.members, "iterations").is_empty())

	var density := _find_binding(reflection.storage_buffers, 1)
	var position := _find_binding(reflection.storage_buffers, 2)
	var result := _find_binding(reflection.storage_buffers, 3)
	assert_false(density.is_empty(), "density was not reflected at set 0, binding 1")
	assert_false(position.is_empty(), "position was not reflected at set 0, binding 2")
	assert_false(result.is_empty(), "result was not reflected at set 0, binding 3")
	if not density.is_empty():
		assert_eq(density.access, "readonly")
		assert_eq(density.element_type, "float")
		assert_eq(density.element_stride, 4)
	if not position.is_empty():
		assert_eq(position.access, "readwrite")
		assert_eq(position.element_type, "float3")
		assert_eq(position.element_stride, 16)
	if not result.is_empty():
		assert_eq(result.access, "readwrite")
		assert_eq(result.element_type, "float")
		assert_eq(result.element_stride, 4)

	rd.free()


# This fixture keeps reflection testable on machines where a RenderingDevice is
# unavailable. Its original source happened to be HLSL, but only its SPIR-V
# interface is relevant to this regression test.
func test_precompiled_spirv_reflection() -> void:
	var bytecode := FileAccess.get_file_as_bytes(
		"res://addons/flow_nodes_editor/tests/fixtures/array_of_structured_buffer.spv"
	)
	assert_false(bytecode.is_empty(), "Unable to load the precompiled SPIR-V fixture")
	if bytecode.is_empty():
		return

	var reflection := GDShaderReflection.reflect_compute(bytecode, "main")
	assert_true(reflection.ok, reflection.error)
	if not reflection.ok:
		return

	assert_eq(reflection.entry_point.name, "main")
	assert_eq(reflection.entry_point.local_size_x, 16)
	assert_eq(reflection.entry_point.local_size_y, 16)
	assert_eq(reflection.entry_point.local_size_z, 1)

	var input := _find_named(reflection.storage_buffers, "Input")
	var output := _find_named(reflection.storage_buffers, "Output")
	assert_false(input.is_empty(), "Input buffer was not reflected")
	assert_false(output.is_empty(), "Output buffer was not reflected")
	if not input.is_empty():
		assert_eq(input.access, "readonly")
		assert_eq(input.element_type, "float3")
	if not output.is_empty():
		assert_eq(output.access, "readwrite")
		assert_eq(output.element_type, "float3")
