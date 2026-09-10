@tool
extends FlowNodeBase

const SHADER_SOURCE = preload("res://addons/flow_nodes_editor/flow_compute_shader_source.gd")
const SHADER_EXECUTOR = preload("res://addons/flow_nodes_editor/flow_compute_shader_executor.gd")
const PARAMETER_PROPERTY_PREFIX := "shader_parameters/"

const DEFAULT_SHADER := """#pragma flow_param vec3 offset
#pragma flow_rw vec3 position

void FlowKernel(uint index)
{
	position[index] += offset;
}
"""

@export_multiline var shader_source: String = DEFAULT_SHADER:
	set(value):
		if shader_source == value:
			return
		shader_source = value
		var signature_changed := _refresh_contract()
		notify_property_list_changed()
		if signature_changed:
			connections_changed.emit()

@export_range(1, 1024, 1) var local_size_x := SHADER_SOURCE.DEFAULT_LOCAL_SIZE_X
@export var profile_execution := false
@export_storage var parameter_values: Dictionary = {}

var _contract: Dictionary = {}
var _contract_error := ""
var _parameter_types: Dictionary = {}
var _executor = SHADER_EXECUTOR.new()
var last_profile: Dictionary = {}


func _init() -> void:
	meta_node = {
		"title": "Compute Shader",
		"category": "Math",
		"ins": [{"label": "In"}],
		"outs": [{"label": "Out"}],
		"tooltip": (
			"Runs a GLSL compute kernel over FlowData attributes.\n"
			+ "Declare constants with #pragma flow_param and buffers with "
			+ "#pragma flow_ro, flow_rw or flow_out."
		),
		"keywords": ["gpu", "glsl", "kernel"],
	}
	_refresh_contract()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _executor != null:
		_executor.dispose()


func _refresh_contract() -> bool:
	var parsed := SHADER_SOURCE.parse(shader_source)
	if not parsed.ok:
		_contract_error = parsed.error
		return false

	_contract_error = ""
	var new_types := {}
	var new_values := {}
	for parameter in parsed.parameters:
		new_types[parameter.name] = parameter.type
		if (
			parameter_values.has(parameter.name)
			and _parameter_types.get(parameter.name) == parameter.type
			and _value_matches_type(parameter_values[parameter.name], parameter.type)
		):
			new_values[parameter.name] = parameter_values[parameter.name]
		else:
			new_values[parameter.name] = _default_parameter_value(parameter.type)

	var signature_changed := new_types != _parameter_types
	_contract = parsed
	_parameter_types = new_types
	parameter_values = new_values
	return signature_changed


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if _contract.is_empty() or not _contract.get("ok", false):
		return properties
	if _contract.parameters.is_empty():
		return properties

	properties.append({
		"name": "Shader Parameters",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})
	for parameter in _contract.parameters:
		properties.append({
			"name": PARAMETER_PROPERTY_PREFIX + parameter.name,
			"type": _variant_type_for(parameter.type),
			"usage": PROPERTY_USAGE_EDITOR,
		})
	return properties


func _get(property: StringName) -> Variant:
	var property_name := String(property)
	if not property_name.begins_with(PARAMETER_PROPERTY_PREFIX):
		return null
	var parameter_name := property_name.trim_prefix(PARAMETER_PROPERTY_PREFIX)
	return parameter_values.get(parameter_name)


func _set(property: StringName, value: Variant) -> bool:
	var property_name := String(property)
	if not property_name.begins_with(PARAMETER_PROPERTY_PREFIX):
		return false
	var parameter_name := property_name.trim_prefix(PARAMETER_PROPERTY_PREFIX)
	if not _parameter_types.has(parameter_name):
		return false
	if not _value_matches_type(value, _parameter_types[parameter_name]):
		return false
	parameter_values[parameter_name] = value
	return true


func getExposedParams() -> Array:
	var exposed := []
	if _contract.is_empty() or not _contract.get("ok", false):
		return exposed
	for parameter in _contract.parameters:
		exposed.append({
			"name": parameter.name,
			"label": editorDisplayName(parameter.name),
			"type": _variant_type_for(parameter.type),
			"data_type": _flow_data_type_for(parameter.type),
			"is_parameter": true,
			"port": -1,
		})
	return exposed


func getTitle() -> String:
	return title if not title.is_empty() and title != "Compute Shader" else "Compute Shader"


func execute(ctx: FlowData.EvaluationContext) -> void:
	var input_data: FlowData.Data = getInput(ctx, 0)
	var current_contract := SHADER_SOURCE.parse(shader_source)
	if not current_contract.ok:
		setError(ctx, current_contract.error)
		return
	_refresh_contract()

	var resolved_parameters := {}
	for parameter in current_contract.parameters:
		var value = parameter_values.get(
			parameter.name, _default_parameter_value(parameter.type)
		)
		value = _getRuntimeParameterInputValue(ctx, parameter.name, value)
		resolved_parameters[parameter.name] = _coerce_runtime_value(parameter.type, value)

	var result := _executor.execute_cached(
		shader_source,
		input_data,
		resolved_parameters,
		local_size_x,
		profile_execution
	)
	last_profile = result.get("profile", {})
	if profile_execution and not last_profile.is_empty():
		print(SHADER_EXECUTOR.format_profile(last_profile))
	if not result.ok:
		setError(ctx, result.error)
		return
	setOutput(ctx, 0, result.data)


func getLastProfileReport() -> String:
	return SHADER_EXECUTOR.format_profile(last_profile)


static func _variant_type_for(shader_type: String) -> int:
	match shader_type:
		"bool": return TYPE_BOOL
		"int", "uint": return TYPE_INT
		"float": return TYPE_FLOAT
		"vec2": return TYPE_VECTOR2
		"vec3": return TYPE_VECTOR3
		"vec4": return TYPE_VECTOR4
		"ivec2", "uvec2": return TYPE_VECTOR2I
		"ivec3", "uvec3": return TYPE_VECTOR3I
		"ivec4", "uvec4": return TYPE_VECTOR4I
	return TYPE_NIL


static func _flow_data_type_for(shader_type: String) -> FlowData.DataType:
	match shader_type:
		"bool": return FlowData.DataType.Bool
		"int", "uint": return FlowData.DataType.Int
		"float": return FlowData.DataType.Float
		"vec3": return FlowData.DataType.Vector
		"vec4": return FlowData.DataType.Color
	return FlowData.DataType.Invalid


static func _default_parameter_value(shader_type: String) -> Variant:
	match shader_type:
		"bool": return false
		"int", "uint": return 0
		"float": return 0.0
		"vec2": return Vector2.ZERO
		"vec3": return Vector3.ZERO
		"vec4": return Vector4.ZERO
		"ivec2", "uvec2": return Vector2i.ZERO
		"ivec3", "uvec3": return Vector3i.ZERO
		"ivec4", "uvec4": return Vector4i.ZERO
	return null


static func _value_matches_type(value: Variant, shader_type: String) -> bool:
	var expected_type := _variant_type_for(shader_type)
	return typeof(value) == expected_type


static func _coerce_runtime_value(shader_type: String, value: Variant) -> Variant:
	if shader_type == "bool" and value is int:
		return value != 0
	if shader_type == "vec4" and value is Color:
		return Vector4(value.r, value.g, value.b, value.a)
	return value
