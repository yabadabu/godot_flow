@tool
class_name FlowGraphOverrides
extends RefCounted

const PROPERTY_PREFIX := "flow_override/"

static func syncWithGraph(
	graph: FlowGraphResource,
	current: Array[FlowGraphParamOverride]
) -> Array[FlowGraphParamOverride]:
	var existing := {}
	for override in current:
		if override:
			existing[override.param_id] = override

	var result: Array[FlowGraphParamOverride] = []
	if not graph:
		return result

	for input in graph.in_params:
		if not _canOverride(input):
			continue
		var override: FlowGraphParamOverride = existing.get(input.name)
		if not override:
			override = FlowGraphParamOverride.new()
			override.param_id = input.name
			override.value = input.getDefaultValue()
			override.enabled = false
		result.append(override)
	return result

static func duplicateAll(
	current: Array[FlowGraphParamOverride]
) -> Array[FlowGraphParamOverride]:
	var result: Array[FlowGraphParamOverride] = []
	for override in current:
		if override:
			result.append(override.duplicate(true))
	return result

static func getOrCreate(
	graph: FlowGraphResource,
	current: Array[FlowGraphParamOverride],
	param_id: StringName
) -> FlowGraphParamOverride:
	for override in current:
		if override and override.param_id == param_id:
			return override

	var override := FlowGraphParamOverride.new()
	override.param_id = param_id
	override.enabled = false
	if graph:
		var input := graph.findInParamByName(param_id)
		if input:
			override.value = input.getDefaultValue()
	current.append(override)
	return override

static func findEnabled(
	current: Array[FlowGraphParamOverride],
	param_id: StringName
) -> FlowGraphParamOverride:
	for override in current:
		if override and override.param_id == param_id and override.enabled:
			return override
	return null

static func getPropertyList(graph: FlowGraphResource) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if not graph:
		return props

	for input: GraphInputParameter in graph.in_params:
		if not _canOverride(input):
			continue
		props.append({
			"name": PROPERTY_PREFIX + String(input.name) + "/enabled",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE
		})
		props.append({
			"name": PROPERTY_PREFIX + String(input.name) + "/value",
			"type": FlowNodeBase.getGdScriptTypeForFlowDataType(input.getDataType()),
			"hint_string": input.name,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE
		})
	return props

static func getProperty(
	graph: FlowGraphResource,
	current: Array[FlowGraphParamOverride],
	property: StringName
):
	var parsed := _parseProperty(property)
	if parsed.is_empty():
		return null
	var override := getOrCreate(graph, current, parsed.param_id)
	return override.get(parsed.field)

static func setProperty(
	graph: FlowGraphResource,
	current: Array[FlowGraphParamOverride],
	property: StringName,
	value: Variant
) -> bool:
	var parsed := _parseProperty(property)
	if parsed.is_empty():
		return false

	var override := getOrCreate(graph, current, parsed.param_id)
	match parsed.field:
		"enabled":
			if override.enabled == value:
				return false
			override.enabled = value
		"value":
			if override.value == value and override.enabled:
				return false
			override.value = value
			override.enabled = true
		_:
			return false
	return true

static func _parseProperty(property: StringName) -> Dictionary:
	var property_name := String(property)
	if not property_name.begins_with(PROPERTY_PREFIX):
		return {}
	var parts := property_name.split("/")
	if parts.size() != 3:
		return {}
	return {
		"param_id": StringName(parts[1]),
		"field": parts[2]
	}

static func _canOverride(input: GraphInputParameter) -> bool:
	return input != null and input.getDataType() != FlowData.DataType.Invalid
