# Classes
The important clases:

## FlowGraphResource (flow_graph_resource.gd)
A container of all the operations to perform in a graph. It's a shared resource, has no state

## FlowData.Data
Container of the actual data being moved across the graph. This is inmutable. 
If you want to modify, make a copy of the modified columns

## FlowNodeBase (node.gd)
The logic representation of an operation in a graph. Has no UI. 
- @export params are exposed unless the function exposeParam is defined and returns false.
- if the node changes in/outs and the associated graph_node needs to be regenerated, call connections_changed.emit
- func execute( ctx : FlowData.EvaluationContext ) defines what the node does.

## FlowGraphNode3D (flow_node.gd)
This is godot Node3D that triggers the evaluation of a FlowGraph in the 3D scene

## EvaluationContext
Contains all the data associated to evaluating a graph with some parameters

## FlowGraphNodeUI (flow_graph_node_ui.gd)
A derived from GraphNode class, used to display a FlowNodeBase in a GraphEdit
