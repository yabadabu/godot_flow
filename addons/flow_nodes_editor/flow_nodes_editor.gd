@tool
extends EditorPlugin

var graph_dock: Control
#var dataview_dock: Control

func _enter_tree():
	print("Data Flow plugin enabled")
	var packed : PackedScene = load("res://addons/flow_nodes_editor/flow_root.tscn")
	graph_dock = packed.instantiate() as Control
	# Give the dock a name so the tab shows up
	graph_dock.name = "Data Flow"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, graph_dock)

func _exit_tree():
	remove_control_from_docks(graph_dock)
	graph_dock.free()
