@tool
class_name FlowPlugin
extends EditorPlugin

# This is the entry point for the plugin
# Where we register all editors, inspectors and hocks

var graph_dock: FlowGraphEditor
var data_inspector_dock: Control
var inspector_plugin
var watched_nodes : Array[Node] = []
var undo_redo: EditorUndoRedoManager
var graph_input_inspector_plugin : EditorInspectorPlugin
var node_settings_inspector_plugin : EditorInspectorPlugin
var flow_graph_resource_inspector_plugin : EditorInspectorPlugin
var nodes_factory := FlowNodesFactory.new()
var executors := {}

# To detect scene changes
var current_scene_root = null
var current_watched_node = null

@onready var selection = EditorInterface.get_selection()

static var instance : FlowPlugin

static func get_instance() -> FlowPlugin:
	return instance

func spawnDock( res_template : String, title : String, bottom : bool ) -> Control:
	var packed : PackedScene = load( res_template )
	var new_control = packed.instantiate() as Control
	new_control.name = title
	if bottom:
		add_control_to_bottom_panel(new_control, title)	
	else:
		add_control_to_dock( DOCK_SLOT_RIGHT_UL, new_control )
	return new_control

func _enter_tree():
	instance = self
	print("Data Flow plugin enabled")
	graph_dock = spawnDock("res://addons/flow_nodes_editor/flow_editor.tscn", "Data Flow", false ) as FlowGraphEditor
	data_inspector_dock = spawnDock("res://addons/flow_nodes_editor/data_inspector.tscn", "Data Inspector", true)
	graph_dock.data_inspector = data_inspector_dock
	graph_dock.make_inspector_visible = func(): make_bottom_panel_item_visible( data_inspector_dock )
	
	graph_input_inspector_plugin = load("res://addons/flow_nodes_editor/graph_input_parameter_inspector.gd").new()
	add_inspector_plugin(graph_input_inspector_plugin)
	node_settings_inspector_plugin = load("res://addons/flow_nodes_editor/node_settings_inspector_plugin.gd").new()
	add_inspector_plugin(node_settings_inspector_plugin)
	flow_graph_resource_inspector_plugin = load("res://addons/flow_nodes_editor/flow_graph_resource_inspector.gd").new()
	add_inspector_plugin(flow_graph_resource_inspector_plugin)
	
	# Will refresh everytime the undo/redo subsystem saves a point
	undo_redo = get_undo_redo()
	undo_redo.history_changed.connect(_on_history_changed)
	
	set_process(true)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	
func _save_external_data():
	graph_dock.saveResource()
	
func _exit_tree():
	if undo_redo:
		undo_redo.history_changed.disconnect(_on_history_changed)
	remove_inspector_plugin(node_settings_inspector_plugin)
	remove_inspector_plugin(graph_input_inspector_plugin)
	remove_inspector_plugin(flow_graph_resource_inspector_plugin)
	remove_control_from_docks(graph_dock)
	graph_dock.free()
	remove_control_from_bottom_panel(data_inspector_dock)
	data_inspector_dock.free()
	selection.selection_changed.disconnect(_selection_changed)
	if instance == self:
		instance = null

func _ready():
	selection.selection_changed.connect(_selection_changed)
	_selection_changed()
	nodes_factory.scanAvailableNodes()

func findFirstFlowNode(scene_root : Node) -> FlowGraphNode3D:
	# Auto activate the first flow node graph found in the scene
	for node in scene_root.get_children():
		var flow_node = node as FlowGraphNode3D
		if flow_node:
			return flow_node
	return null
	
# This is called after the a new scene is loaded, but the 'selection' event of the new
# scene is called first.
func on_scene_changed(scene_root: Node) -> void:
	print( "Scene Changed detected %s : %s -> %s" % [graph_dock.current_resource, is_instance_valid(graph_dock.resource_owner), scene_root.name if scene_root else "<none>" ] )
	graph_dock.clear_active_executor()
	if scene_root == null:
		return

	var flow_node := findFirstFlowNode(scene_root)
	if flow_node:
		graph_dock.openResource(flow_node.graph)
		graph_dock.select_executor(flow_node)

func _handles(object: Object) -> bool:
	return object is FlowGraphResource

func _edit(object: Object) -> void:
	if object == null:
		return
	return
	var res := object as FlowGraphResource
	print("Editor requested edit/open for: ", res.resource_path)
	graph_dock.setResourceToEdit( res )

func _selection_changed():
	
	var scene_nodes = selection.get_selected_nodes()
	if not scene_nodes.is_empty():
		var scene_node = scene_nodes[0]
		if scene_node is FlowGraphNode3D:
			setWatchedNode( scene_node )
			graph_dock.openResource(scene_node.graph)
			graph_dock.select_executor(scene_node, scene_node.ctx)
			return
	setWatchedNode( null )

func setWatchedNode( new_node ):
	#print( "setWatchedNode %s" % new_node )
	if current_watched_node:
		current_watched_node.graph_node_changed.disconnect( onSelectedGraphNodeChanged )
		current_watched_node = null
	if new_node:
		current_watched_node = new_node
		new_node.graph_node_changed.connect( onSelectedGraphNodeChanged )

func onSelectedGraphNodeChanged( node : FlowGraphNode3D, prop_name: String ):
	print( "onSelectedGraphNodeChanged %s.%s" % [node.name, prop_name] )
	if prop_name == "graph_resource":
		print( "  -> %s" % [node.graph] )
		graph_dock.setResourceToEdit( node.graph )
	else:
		if graph_dock.resource_owner == node and graph_dock.active_context == node.ctx:
			print( "Input %s changed" % [prop_name] )
			graph_dock.queueRegen()
		elif graph_dock.auto_regen:
			node.regenerate()

func _on_history_changed( ):
	#print("Something changed in the editor (undo/redo history updated)")	
	graph_dock.onEditorSceneChanged()

func _process( elapsed : float ):
	var scene_root = get_editor_interface().get_edited_scene_root()
	if scene_root != current_scene_root:
		current_scene_root = scene_root
		on_scene_changed(scene_root)

func register_executor(
	node: FlowGraphNode3D,
	graph: FlowGraphResource,
	run_idx: int,
	context: FlowData.EvaluationContext = null
) -> void:
	if graph == null:
		return
	var regeneration_callback := _on_graph_regeneration_requested.bind(graph)
	if not graph.regeneration_requested.is_connected(regeneration_callback):
		graph.regeneration_requested.connect(regeneration_callback)
	var id := node.get_instance_id()
	if not executors.has( graph ):
		executors[graph] = { }
	if not executors[ graph ].has( id ):
		executors[graph][id] = { "count" : 0, "runs" : {} }
	executors[graph][id].count += 1
	executors[graph][id].node_ref = weakref(node)
	if context == null and node.graph == graph:
		context = node.ctx
	var run_id: Variant = context.name if context and context.parent_ctx else run_idx
	executors[graph][id].runs[run_id] = context

func _on_graph_regeneration_requested(
	source_owner,
	graph: FlowGraphResource
) -> void:
	var scheduled_owners := {}
	for executor in get_live_executors(graph):
		var node := executor.node_ref.get_ref() as FlowGraphNode3D
		if node == null:
			continue
		for context in executor.runs.values():
			_mark_parent_contexts_dirty(context)
		# The editor has already evaluated a root context directly. A nested
		# context still needs its owner to regenerate so changes propagate
		# through the parent subgraph node.
		if node == source_owner and node.graph == graph:
			continue
		var node_id := node.get_instance_id()
		if scheduled_owners.has(node_id):
			continue
		scheduled_owners[node_id] = true
		node.regenerate.call_deferred()

func _mark_parent_contexts_dirty(context: FlowData.EvaluationContext) -> void:
	var child_ctx := context
	while child_ctx and child_ctx.parent_ctx:
		var parent_ctx := child_ctx.parent_ctx
		for parent_node in parent_ctx.graph.all_nodes:
			var invocations: Dictionary = parent_ctx.child_contexts.get(parent_node.name, {})
			if invocations.values().has(child_ctx):
				parent_ctx.markNodeDirty(parent_node)
				break
		child_ctx = parent_ctx

func unregister_executor(node: FlowGraphNode3D) -> void:
	var graph : FlowGraphResource = node.graph
	if graph == null:
		return
	executors[graph].erase(node.get_instance_id())
	if executors[ graph ].is_empty():
		print( "Executors remaining of this graph: %s" % executors[ graph ] )
	
func get_live_executors( graph : FlowGraphResource ) -> Array:
	var result := []
	if graph:
		var graph_executors = executors.get(graph)
		if graph_executors:
			for id in graph_executors.keys():
				var node = graph_executors[id].node_ref.get_ref()
				if node == null or not is_instance_valid(node) or not node.is_inside_tree():
					executors.erase(id)
					continue
				result.append(graph_executors[id])
	return result


# ----------------------------------------------
var _active_camera: Camera3D
var _debug_lines: Array[Dictionary] = []
var _debug_labels: Array[Dictionary] = []
var _redraw_pending := false

func _forward_3d_gui_input( camera: Camera3D, event: InputEvent ) -> int:
	_active_camera = camera
	if event is InputEventMouse:
		if not _redraw_pending:
			_redraw_pending = true
			_redraw_overlay.call_deferred()
	return EditorPlugin.AFTER_GUI_INPUT_PASS
	
func _redraw_overlay() -> void:
	_redraw_pending = false
	update_overlays()
	
func _forward_3d_force_draw_over_viewport(overlay: Control) -> void:
	#overlay.draw_circle(overlay.get_local_mouse_position(), 64, Color.WHITE)
	var camera = null
	# Useful before the mouse has entered the 3D viewport.
	if not is_instance_valid(camera):
		var editor_viewport := EditorInterface.get_editor_viewport_3d(0)
		camera = editor_viewport.get_camera_3d()
	if camera == null:
		return
	_draw_debug_lines(overlay, camera)
	_draw_debug_labels(overlay, camera)
	
func _draw_debug_lines( overlay: Control, camera: Camera3D ) -> void:
	for entry in _debug_lines:
		var from: Vector3 = entry["from"]
		var to: Vector3 = entry["to"]
		if camera.is_position_behind(from):
			continue
		if camera.is_position_behind(to):
			continue
		var screen_from := camera.unproject_position(from)
		var screen_to := camera.unproject_position(to)
		if screen_from.distance_squared_to( screen_to ) < 1e-5:
			continue
		overlay.draw_line( screen_from, screen_to, entry.color, entry.width, true )	


func _draw_debug_labels( overlay: Control, camera: Camera3D) -> void:
	var font := overlay.get_theme_default_font()
	var default_size := overlay.get_theme_default_font_size()

	for entry in _debug_labels:
		var world_position: Vector3 = entry["position"]
		if camera.is_position_behind(world_position):
			continue

		var screen_position := camera.unproject_position(world_position)
		screen_position += entry["offset"]

		var font_size: int = entry.get("font_size", default_size)
		var text: String = entry["text"]
		var color: Color = entry["color"]

		# Dark outline makes labels readable against most backgrounds.
		overlay.draw_string_outline(
			font,
			screen_position,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			2,
			Color(0.0, 0.0, 0.0, 0.9)
		)

		overlay.draw_string(
			font,
			screen_position,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			color
		)

func clear_debug_draw() -> void:
	_debug_lines.clear()
	_debug_labels.clear()
	update_overlays()
	
func debug_line( from: Vector3, to: Vector3, color := Color.WHITE, width := 1.0 ) -> void:
	_debug_lines.append({
		"from": from,
		"to": to,
		"color": color,
		"width": width
	})
	update_overlays()
	
func debug_text( position: Vector3, text: String, color := Color.WHITE, offset := Vector2(6.0, -6.0), font_size := 14 ) -> void:
	_debug_labels.append({
		"position": position,
		"text": text,
		"color": color,
		"offset": offset,
		"font_size": font_size,
	})
	update_overlays()
	update_overlays()
