@tool
extends BaseTest

const EXECUTOR = preload("res://addons/flow_nodes_editor/flow_compute_shader_executor.gd")

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


func test_compute_shader_upload_dispatch_download_is_copy_on_write() -> void:
	var input := FlowData.Data.new()
	var density := PackedFloat32Array([10.0, 20.0, 30.0])
	var positions := PackedVector3Array([
		Vector3(1.0, 2.0, 3.0),
		Vector3(4.0, 5.0, 6.0),
		Vector3(7.0, 8.0, 9.0),
	])
	input.registerStream("density", density, FlowData.DataType.Float)
	input.registerStream("position", positions, FlowData.DataType.Vector)

	var execution := EXECUTOR.execute(USER_GLSL, input, {
		"center": Vector3.ONE,
		"strength": 0.5,
		"iterations": 2,
	})
	assert_true(execution.ok, execution.error)
	if not execution.ok:
		return

	var output: FlowData.Data = execution.data
	var output_positions: PackedVector3Array = output.findStream("position").container
	var results: PackedFloat32Array = output.findStream("result").container
	assert_eq(output_positions, PackedVector3Array([
		Vector3(1.0, 2.5, 4.0),
		Vector3(5.5, 7.0, 8.5),
		Vector3(10.0, 11.5, 13.0),
	]))
	assert_eq(results, PackedFloat32Array([12.0, 22.0, 32.0]))

	# RW results replace only the shallow duplicate's stream container.
	assert_eq(input.findStream("position").container, positions)
	assert_false(input.hasStream("result"))
	assert_eq(output.findStream("density").container, density)


func test_compute_shader_rejects_wrong_input_attribute_type() -> void:
	var input := FlowData.Data.new()
	input.registerStream(
		"density", PackedInt32Array([1, 2]), FlowData.DataType.Int
	)
	input.registerStream(
		"position",
		PackedVector3Array([Vector3.ZERO, Vector3.ONE]),
		FlowData.DataType.Vector
	)

	var execution := EXECUTOR.execute(USER_GLSL, input)
	assert_false(execution.ok)
	assert_true(execution.error.contains("Attribute 'density' should be float"))
	assert_false(input.hasStream("result"))


func test_parameter_changes_reuse_compiled_shader_and_pipeline() -> void:
	var input := FlowData.Data.new()
	input.registerStream(
		"density", PackedFloat32Array([10.0, 20.0]), FlowData.DataType.Float
	)
	input.registerStream(
		"position",
		PackedVector3Array([Vector3(1.0, 2.0, 3.0), Vector3(4.0, 5.0, 6.0)]),
		FlowData.DataType.Vector
	)

	var executor = EXECUTOR.new()
	var first := executor.execute_cached(USER_GLSL, input, {
		"center": Vector3.ZERO,
		"strength": 0.0,
		"iterations": 1,
	}, 64, true)
	assert_true(first.ok, first.error)
	assert_false(first.get("shader_reused", true))
	assert_eq(executor.get_compile_count(), 1)

	var second := executor.execute_cached(USER_GLSL, input, {
		"center": Vector3.ZERO,
		"strength": 1.0,
		"iterations": 5,
	}, 64, true)
	assert_true(second.ok, second.error)
	assert_true(second.get("shader_reused", false))
	assert_eq(executor.get_compile_count(), 1)
	assert_eq(second.profile.compile_reflect_us, 0)
	assert_true(second.profile.total_us > 0)
	assert_true(second.profile.buffers.size() == 3)
	assert_true(
		second.profile.gpu_dispatch_us >= 0,
		"GPU timestamps unavailable: %s" % second.profile
	)
	assert_true(EXECUTOR.format_profile(second.profile).contains("cached pipeline"))
	if second.ok:
		assert_eq(
			second.data.findStream("result").container,
			PackedFloat32Array([15.0, 25.0])
		)
		assert_eq(
			second.data.findStream("position").container,
			PackedVector3Array([
				Vector3(2.0, 4.0, 6.0),
				Vector3(8.0, 10.0, 12.0),
			])
		)
	executor.dispose()


func test_native_vec3_gpu_buffer_conversion_respects_stride() -> void:
	var source := PackedVector3Array([
		Vector3(1.25, -2.5, 3.75),
		Vector3(-4.0, 5.5, 6.25),
	])
	var bytes := GDStreamUtils.pack_vec3_f32(source, 16)
	assert_eq(bytes.size(), 32)
	assert_approx_eq(bytes.decode_float(0), 1.25, 0.00001)
	assert_approx_eq(bytes.decode_float(4), -2.5, 0.00001)
	assert_approx_eq(bytes.decode_float(8), 3.75, 0.00001)
	assert_approx_eq(bytes.decode_float(16), -4.0, 0.00001)
	assert_eq(GDStreamUtils.unpack_vec3_f32(bytes, 2, 16), source)
