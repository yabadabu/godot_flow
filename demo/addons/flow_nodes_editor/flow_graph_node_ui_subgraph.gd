@tool
extends FlowGraphNodeUI
class_name FlowGraphNodeUISubgraph

# Double click to trigger openning the subgraph
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		var subgraph_node := flow_node as FlowNodeSubGraph
		if editor and subgraph_node:
			if not subgraph_node.graph:
				subgraph_node.graph = FlowGraphResource.new()
			var graph : FlowGraphResource = subgraph_node.graph
			var owner = editor.resource_owner
			#print( "graph.data", graph.data)
			#print( "graph.resource_name", graph.resource_name )
			#print( "graph.resource_path", graph.resource_path )
			if not subgraph_node.graph.data:
				subgraph_node.resetSubgraph( graph )
			editor.openSubgraph(subgraph_node)
			accept_event()	
