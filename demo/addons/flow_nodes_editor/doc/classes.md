# Classes
The important clases:

## FlowGraphResource (flow_graph_resource.gd)
A container of all the operations to perform in a graph. It's a shared resource, has no state

## FlowData.Data
Container of the actual data being moved across the graph. This is inmutable. 
If you want to modify, make a copy of the columns you want to modify. The data is column oriented, meaning the array of points does not contain a vector of key/values like positions, rotation, but it's an array of typed columns, where the first column contains all the positions, the second all the rotations, etc.

## FlowNodeBase (node.gd)
The logic representation of an operation in a graph. Has no UI, and does not need to editor to run 
- @export params are exposed unless the function exposeParam is defined and returns false.
- if the node changes in/outs and the associated graph_node needs to be regenerated, call connections_changed.emit()
- func execute( ctx : FlowData.EvaluationContext ) defines what the node does with a single batch.

## FlowGraphNode3D (flow_node.gd)
This is a godot Node3D that triggers the evaluation of a FlowGraph in the 3D scene. If the graph has parameters, this node can assign custom values for it's own evaluation.

## EvaluationContext
Contains all the data associated to evaluating a graph with some parameters

## FlowGraphNodeUI (flow_graph_node_ui.gd)
A derived from GraphNode class, used to display a FlowNodeBase in a GraphEdit.

## FlowGraphParamOverride
A parameter that can be optionally be overriden by a FlowGraphNode3D or a subgraph Node.

## FlowGraphRedirect
A parameter that can be optionally be overriden by a FlowGraphNode3D or a subgraph Node.

## FlowGraphRedirectors
A parameter that can be optionally be overriden by a FlowGraphNode3D or a subgraph Node.
