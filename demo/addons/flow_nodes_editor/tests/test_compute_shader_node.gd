@tool
extends BaseTest

const NODE_SCRIPT = preload("res://addons/flow_nodes_editor/nodes/compute_shader.gd")

const NODE_SHADER := """#pragma flow_param float multiplier
#pragma flow_param vec3 offset
#pragma flow_ro float weight
#pragma flow_rw vec3 position

void FlowKernel(uint index)
{
	position[index] = position[index] + offset * weight[index] * multiplier;
}
"""


func test_compute_shader_node_exposes_and_preserves_typed_parameters() -> void:
	var node = NODE_SCRIPT.new()
	node.shader_source = NODE_SHADER

	var exposed: Array = node.getExposedParams()
	assert_eq(exposed.size(), 2)
	assert_eq(exposed[0].name, "multiplier")
	assert_eq(exposed[0].type, TYPE_FLOAT)
	assert_eq(exposed[0].data_type, FlowData.DataType.Float)
	assert_eq(exposed[1].name, "offset")
	assert_eq(exposed[1].type, TYPE_VECTOR3)
	assert_eq(exposed[1].data_type, FlowData.DataType.Vector)

	node.set("shader_parameters/multiplier", 2.0)
	node.set("shader_parameters/offset", Vector3(1.0, 2.0, 3.0))
	assert_eq(node.get("shader_parameters/multiplier"), 2.0)
	assert_eq(node.parameter_values.offset, Vector3(1.0, 2.0, 3.0))

	# Editing only the kernel keeps the values associated with its typed contract.
	node.shader_source = NODE_SHADER + "\n// Kernel-only edit.\n"
	assert_eq(node.parameter_values.multiplier, 2.0)
	assert_eq(node.parameter_values.offset, Vector3(1.0, 2.0, 3.0))

	# A declaration type change resets only that parameter to its new default.
	node.shader_source = NODE_SHADER.replace(
		"#pragma flow_param float multiplier",
		"#pragma flow_param int multiplier"
	)
	assert_eq(node.parameter_values.multiplier, 0)
	assert_eq(node.parameter_values.offset, Vector3(1.0, 2.0, 3.0))


func test_compute_shader_node_delegates_execution() -> void:
	var node = NODE_SCRIPT.new()
	node.name = "compute_shader_test"
	node.shader_source = NODE_SHADER
	node.set("shader_parameters/multiplier", 2.0)
	node.set("shader_parameters/offset", Vector3(1.0, 0.0, -1.0))
	node.args_ports_by_name = {
		"multiplier": {"port": 1, "connected": true},
	}

	var input := FlowData.Data.new()
	var original_positions := PackedVector3Array([
		Vector3(1.0, 2.0, 3.0),
		Vector3(4.0, 5.0, 6.0),
	])
	input.registerStream(
		"position", original_positions, FlowData.DataType.Vector
	)
	input.registerStream(
		"weight", PackedFloat32Array([0.5, 2.0]), FlowData.DataType.Float
	)
	var connected_multiplier := FlowData.Data.new()
	connected_multiplier.registerStream(
		"value", PackedFloat32Array([3.0]), FlowData.DataType.Float
	)

	var ctx := FlowData.EvaluationContext.new()
	node.preExecute(ctx)
	ctx.setNodeInputs(node, [input, connected_multiplier])
	node.execute(ctx)

	assert_eq(ctx.getNodeError(node), "")
	var output: FlowData.Data = ctx.getOutput(node, 0, 0)
	assert_true(output != null)
	if output == null:
		return
	assert_eq(output.findStream("position").container, PackedVector3Array([
		Vector3(2.5, 2.0, 1.5),
		Vector3(10.0, 5.0, 0.0),
	]))
	assert_eq(input.findStream("position").container, original_positions)


func test_compute_shader_node_serializes_dynamic_parameter_values() -> void:
	var source_node = NODE_SCRIPT.new()
	source_node.shader_source = NODE_SHADER
	source_node.set("shader_parameters/multiplier", 4.0)
	source_node.set("shader_parameters/offset", Vector3(2.0, 3.0, 4.0))

	var serialized := FlowNodeIO.resource_to_dict(source_node)
	assert_true(serialized.has("shader_source"))
	assert_true(serialized.has("parameter_values"))

	var restored_node = NODE_SCRIPT.new()
	FlowNodeIO.dict_to_resource(serialized, restored_node)
	assert_eq(restored_node.shader_source, NODE_SHADER)
	assert_eq(restored_node.parameter_values.multiplier, 4.0)
	assert_eq(restored_node.parameter_values.offset, Vector3(2.0, 3.0, 4.0))
	assert_eq(restored_node.getExposedParams().size(), 2)
