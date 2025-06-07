@tool
extends EditorPlugin

var graph_dock: Control
var data_inspector_dock: Control

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
	print("Data Flow plugin enabled")
	graph_dock = spawnDock("res://addons/flow_nodes_editor/flow_root.tscn", "Data Flow", false )
	data_inspector_dock = spawnDock("res://addons/flow_nodes_editor/data_inspector.tscn", "Data Inspector", true)
	graph_dock.data_inspector = data_inspector_dock

func _exit_tree():
	remove_control_from_docks(graph_dock)
	graph_dock.free()
	remove_control_from_bottom_panel(data_inspector_dock)
	data_inspector_dock.free()
