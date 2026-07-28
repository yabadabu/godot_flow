@tool
class_name FlowGraphRedirectors
extends RefCounted

const SYNTHETIC_KEY := &"redirect_synthetic"

static func findDefinition(
	graph: FlowGraphResource,
	redirect_id: StringName
) -> FlowGraphRedirect:
	if not graph or redirect_id.is_empty():
		return null
	for definition in graph.redirectors:
		if definition and definition.ensureId() == redirect_id:
			return definition
	return null

static func findDefinitionByName(
	graph: FlowGraphResource,
	redirect_name: String
) -> FlowGraphRedirect:
	if not graph:
		return null
	for definition in graph.redirectors:
		if definition and definition.name == redirect_name:
			return definition
	return null

static func ensureDefinition(
	graph: FlowGraphResource,
	redirect_id: StringName,
	redirect_name: String
) -> FlowGraphRedirect:
	var definition := findDefinition(graph, redirect_id)
	if not definition and not redirect_name.is_empty():
		definition = findDefinitionByName(graph, redirect_name)
	if definition:
		return definition

	definition = FlowGraphRedirect.new()
	definition.name = redirect_name if not redirect_name.is_empty() else "Redirect"
	definition.ensureId()
	graph.redirectors.append(definition)
	return definition

static func createDefinition(
	graph: FlowGraphResource,
	redirect_name: String
) -> FlowGraphRedirect:
	if not graph:
		return null
	var clean_name := redirect_name.strip_edges()
	if clean_name.is_empty() or findDefinitionByName(graph, clean_name):
		return null
	var definition := FlowGraphRedirect.new()
	definition.name = clean_name
	definition.ensureId()
	graph.redirectors.append(definition)
	return definition

static func makeUniqueName(
	graph: FlowGraphResource,
	base_name: String = "Redirect"
) -> String:
	var clean_name := base_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Redirect"
	var candidate := clean_name
	var suffix := 2
	while findDefinitionByName(graph, candidate):
		candidate = "%s %d" % [clean_name, suffix]
		suffix += 1
	return candidate

static func rebuildSyntheticConnections(
	graph: FlowGraphResource,
	invalidate_endpoints: bool = true
) -> void:
	if not graph:
		return
	_removeSyntheticConnections(graph)

	var inputs_by_id := {}
	var outputs_by_id := {}
	for node in graph.all_nodes:
		if node is FlowNodeRedirectInput:
			_appendEndpoint(inputs_by_id, node.redirect_id, node)
		elif node is FlowNodeRedirectOutput:
			_appendEndpoint(outputs_by_id, node.redirect_id, node)

	for redirect_id in inputs_by_id:
		var inputs: Array = inputs_by_id[redirect_id]
		var outputs: Array = outputs_by_id.get(redirect_id, [])
		for input_node: FlowNodeRedirectInput in inputs:
			for output_node: FlowNodeRedirectOutput in outputs:
				var connection: Dictionary = {
					"from_node": input_node.name,
					"from_port": 0,
					"to_node": output_node.name,
					"to_port": 0,
					SYNTHETIC_KEY: true,
				}
				input_node.dependants.append(connection)
				output_node.deps.append(connection)

	if invalidate_endpoints:
		for node in graph.all_nodes:
			if node is FlowNodeRedirectEndpoint:
				node.invalidate()

static func removeUnusedDefinitions(graph: FlowGraphResource) -> void:
	if not graph:
		return
	var used_ids := {}
	for node in graph.all_nodes:
		if node is FlowNodeRedirectEndpoint and not node.redirect_id.is_empty():
			used_ids[node.redirect_id] = true
	for idx in range(graph.redirectors.size() - 1, -1, -1):
		var definition := graph.redirectors[idx]
		if not definition or not used_ids.has(definition.ensureId()):
			graph.redirectors.remove_at(idx)

static func _appendEndpoint(
	endpoints_by_id: Dictionary,
	redirect_id: StringName,
	node: FlowNodeBase
) -> void:
	if redirect_id.is_empty():
		return
	if not endpoints_by_id.has(redirect_id):
		endpoints_by_id[redirect_id] = []
	endpoints_by_id[redirect_id].append(node)

static func _removeSyntheticConnections(graph: FlowGraphResource) -> void:
	for node in graph.all_nodes:
		for idx in range(node.deps.size() - 1, -1, -1):
			if node.deps[idx].get(SYNTHETIC_KEY, false):
				node.deps.remove_at(idx)
		for idx in range(node.dependants.size() - 1, -1, -1):
			if node.dependants[idx].get(SYNTHETIC_KEY, false):
				node.dependants.remove_at(idx)
