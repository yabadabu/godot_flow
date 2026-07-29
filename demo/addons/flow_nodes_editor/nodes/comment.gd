@tool
extends FlowNodeBase

@export_group("Comment")
@export_multiline var text := "..."
@export_range(0.0, 1.0)  var hue : float = 0.5

var is_ready : bool = false
var label : Label
var panel_sb: StyleBoxFlat
var panel_selected_sb: StyleBoxFlat

func _init():
	meta_node = {
		"title" : "Comments",
		"category" : "Debug",
		"ins" : [], 
		"outs" : [],
		"hide_inputs" : true,
		"tooltip" : "Adds a custom text to the graph",
		"widget" : preload( "res://addons/flow_nodes_editor/flow_graph_node_ui_comment.tscn" ),
	}
	hue = randf()

func shouldReevaluateOnPropChanged(prop_name: StringName) -> bool:
	print( "shouldReevaluateOnPropChanged %s" % prop_name )
	return prop_name != &"text" and prop_name != &"hue"
