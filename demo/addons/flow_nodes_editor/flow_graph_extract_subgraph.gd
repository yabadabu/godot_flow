@tool
extends RefCounted

# Editor-only transformation which replaces a selection with an embedded
# subgraph while preserving every connection crossing the selection boundary.

class ExtractionResult:
	var success := false
	var error := ""
	var subgraph_node: FlowGraphNodeUI


static func extract(editor, selected_nodes: Array[GraphNode]) -> ExtractionResult:
	var result := ExtractionResult.new()
	if not editor or not editor.current_resource:
		result.error = "There is no Flow Graph being edited."
		return result
	if selected_nodes.is_empty():
		result.error = "Select at least one node to create a subgraph."
		return result

	for graph_node in selected_nodes:
		if not graph_node is FlowGraphNodeUI or not graph_node.flow_node:
			result.error = "The selection contains an invalid Flow Graph node."
			return result
		var template_name: String = graph_node.flow_node.template_name
		if graph_node.flow_node is FlowNodeInput or template_name == "output":
			result.error = "Input and Output nodes cannot be collapsed into a subgraph yet."
			return result

	var selected_by_name := {}
	for graph_node in selected_nodes:
		selected_by_name[graph_node.flow_node.name] = graph_node

	var internal_connections: Array[Dictionary] = []
	var incoming_by_target := {}
	var outgoing_by_source := {}
	for connection in editor.current_resource.all_connections:
		var from_selected: bool = selected_by_name.has(connection.from_node)
		var to_selected: bool = selected_by_name.has(connection.to_node)
		if from_selected and to_selected:
			internal_connections.append(connection.duplicate())
		elif not from_selected and to_selected:
			var input_key := _port_key(connection.to_node, connection.to_port)
			if not incoming_by_target.has(input_key):
				incoming_by_target[input_key] = {
					"node_name": connection.to_node,
					"port": connection.to_port,
					"connections": [],
				}
			incoming_by_target[input_key].connections.append(connection.duplicate())
		elif from_selected and not to_selected:
			var output_key := _port_key(connection.from_node, connection.from_port)
			if not outgoing_by_source.has(output_key):
				outgoing_by_source[output_key] = {
					"node_name": connection.from_node,
					"port": connection.from_port,
					"connections": [],
				}
			outgoing_by_source[output_key].connections.append(connection.duplicate())

	var incoming: Array = incoming_by_target.values()
	var outgoing: Array = outgoing_by_source.values()
	incoming.sort_custom(func(a, b): return _boundary_sort(a, b, selected_by_name))
	outgoing.sort_custom(func(a, b): return _boundary_sort(a, b, selected_by_name))

	var selected_rect: Rect2 = editor.getRectOfNodes(selected_nodes)
	var selected_data: Dictionary = FlowNodeIO.nodes_as_dict(
		selected_nodes.duplicate(),
		[],
		editor
	)
	var child_graph := FlowGraphResource.new()
	child_graph.graph_name = "Extracted Subgraph"

	var child_nodes: Array = selected_data.get("nodes", []).duplicate(true)
	var child_links: Array = internal_connections.duplicate(true)
	var used_names := {}
	var used_port_labels := {}
	for node_data in child_nodes:
		used_names[StringName(node_data.name)] = true

	var input_params: Array[GraphInputParameter] = []
	for input_idx in range(incoming.size()):
		var boundary: Dictionary = incoming[input_idx]
		var target_ui: FlowGraphNodeUI = selected_by_name[boundary.node_name]
		var label := _make_unique_label(
			_get_input_label(target_ui.flow_node, boundary.port),
			used_port_labels
		)
		var data_type: FlowData.DataType = target_ui.get_input_port_type(boundary.port)
		var parameter := GraphInputParameter.new()
		parameter.name = label
		parameter.data_type = data_type
		parameter.is_constant = data_type != FlowData.DataType.Any
		parameter.ensureId()
		input_params.append(parameter)

		var input_node_name := _make_unique_node_name(
			"extracted_input_%d" % input_idx,
			used_names
		)
		var target_position: Vector2 = (
			target_ui.position_offset - selected_rect.position
		) / editor.ui_scale
		child_nodes.append({
			"name": input_node_name,
			"position": Vector2(-240.0, target_position.y),
			"template": "input",
			"settings": {
				"input_id": parameter.param_id,
				"input_name": parameter.name,
			},
		})
		child_links.append({
			"from_node": input_node_name,
			"from_port": 0,
			"to_node": boundary.node_name,
			"to_port": boundary.port,
		})
		boundary["subgraph_port"] = input_idx

	for output_idx in range(outgoing.size()):
		var boundary: Dictionary = outgoing[output_idx]
		var source_ui: FlowGraphNodeUI = selected_by_name[boundary.node_name]
		var label := _make_unique_label(
			_get_output_label(source_ui.flow_node, boundary.port),
			used_port_labels
		)
		var data_type: FlowData.DataType = source_ui.get_output_port_type(boundary.port)
		var output_node_name := _make_unique_node_name(
			"extracted_output_%d" % output_idx,
			used_names
		)
		var source_position: Vector2 = (
			source_ui.position_offset - selected_rect.position
		) / editor.ui_scale
		child_nodes.append({
			"name": output_node_name,
			"position": Vector2(
				selected_rect.size.x / editor.ui_scale + 240.0,
				source_position.y
			),
			"template": "output",
			"settings": {
				"out_name": label,
				"data_type": data_type,
			},
		})
		child_links.append({
			"from_node": boundary.node_name,
			"from_port": boundary.port,
			"to_node": output_node_name,
			"to_port": 0,
		})
		boundary["subgraph_port"] = output_idx

	child_graph.in_params = input_params
	child_graph.data = {
		"type": "flow_graph_nodes",
		"version": 1,
		"min_pos": Vector2.ZERO,
		"nodes": child_nodes,
		"links": child_links,
		"frames": [],
	}

	var previous_drop_position: Vector2 = editor.local_drop_position
	var previous_auto_from_node = editor.auto_connect_from_node
	var previous_auto_from_port: int = editor.auto_connect_from_port
	var previous_auto_to_node = editor.auto_connect_to_node
	var previous_auto_to_port: int = editor.auto_connect_to_port
	editor.auto_connect_from_node = ""
	editor.auto_connect_from_port = 0
	editor.auto_connect_to_node = ""
	editor.auto_connect_to_port = 0
	editor.local_drop_position = (
		selected_rect.get_center() * editor.gedit.zoom
		- editor.gedit.scroll_offset
	)
	var subgraph_ui: FlowGraphNodeUI = editor.addNode(
		"subgraph",
		{"graph": child_graph}
	)
	editor.local_drop_position = previous_drop_position
	editor.auto_connect_from_node = previous_auto_from_node
	editor.auto_connect_from_port = previous_auto_from_port
	editor.auto_connect_to_node = previous_auto_to_node
	editor.auto_connect_to_port = previous_auto_to_port
	if not subgraph_ui:
		result.error = "The Subgraph node could not be created."
		return result
	subgraph_ui.position_offset = selected_rect.get_center() - subgraph_ui.size * 0.5

	for boundary in incoming:
		for connection in boundary.connections:
			editor.connect_nodes(
				connection.from_node,
				connection.from_port,
				subgraph_ui.flow_node.name,
				boundary.subgraph_port
			)
	for boundary in outgoing:
		for connection in boundary.connections:
			editor.connect_nodes(
				subgraph_ui.flow_node.name,
				boundary.subgraph_port,
				connection.to_node,
				connection.to_port
			)

	editor.deleteGraphElementsAndRefresh(selected_nodes, [])
	subgraph_ui.selected = true
	editor.queueSave()
	editor.queueRegen()

	result.success = true
	result.subgraph_node = subgraph_ui
	return result


static func _port_key(node_name: StringName, port: int) -> String:
	return "%s:%d" % [node_name, port]


static func _boundary_sort(a: Dictionary, b: Dictionary, selected_by_name: Dictionary) -> bool:
	var a_ui: FlowGraphNodeUI = selected_by_name[a.node_name]
	var b_ui: FlowGraphNodeUI = selected_by_name[b.node_name]
	if not is_equal_approx(a_ui.position_offset.y, b_ui.position_offset.y):
		return a_ui.position_offset.y < b_ui.position_offset.y
	if a_ui.position_offset.x != b_ui.position_offset.x:
		return a_ui.position_offset.x < b_ui.position_offset.x
	return int(a.port) < int(b.port)


static func _get_input_label(node: FlowNodeBase, port: int) -> String:
	for input_name in node.args_ports_by_name:
		if int(node.args_ports_by_name[input_name].port) == port:
			return str(input_name)
	return "%s Input %d" % [node.getTitle(), port + 1]


static func _get_output_label(node: FlowNodeBase, port: int) -> String:
	var outputs: Array = node.getMeta().get("outs", [])
	if port < outputs.size():
		return str(outputs[port].get("label", "Output %d" % (port + 1)))
	return "%s Output %d" % [node.getTitle(), port + 1]


static func _make_unique_label(base_label: String, used_labels: Dictionary) -> String:
	var clean_label := base_label.strip_edges()
	if clean_label.is_empty():
		clean_label = "Data"
	var candidate := clean_label
	var suffix := 2
	while used_labels.has(candidate):
		candidate = "%s %d" % [clean_label, suffix]
		suffix += 1
	used_labels[candidate] = true
	return candidate


static func _make_unique_node_name(base_name: String, used_names: Dictionary) -> StringName:
	var candidate := StringName(base_name)
	var suffix := 2
	while used_names.has(candidate):
		candidate = StringName("%s_%d" % [base_name, suffix])
		suffix += 1
	used_names[candidate] = true
	return candidate
