@tool
extends FlowNodeBase

## How do we pick the centroid
enum eOperation {
	ByDistance,
	ByAttribute,
}

@export var operation : eOperation = eOperation.ByDistance:
	set(value):
		if operation != value:
			operation = value
			notify_property_list_changed()

@export_range(-1.0, 1.0) var weight : float = 0.5
@export var max_distance : float = 5.0
@export var index_attribute = "cluster_index"
@export var out_name = FlowData.AttrPosition

func _init():
	meta_node = {
		"title" : "Attract",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }, { "label": "Attractors" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Attracts attributes to the nearest point",
	}
	
func exposeParam( name : String ) -> bool:
	if name == "index_attribute":
		return operation == eOperation.ByAttribute
	return true	

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	var attractors_data : FlowData.Data = getInput(ctx, 1)
	var out_data : FlowData.Data = in_data.duplicate()
	
	# The points and the attractor positions
	var in_pos := in_data.getVector3Container( FlowData.AttrPosition )
	var attractors_pos := attractors_data.getVector3Container( FlowData.AttrPosition )
	
	# Associate to each point the nearest attractor
	var nearest_indices : PackedInt32Array

	if operation == eOperation.ByAttribute:
		var user_indices = in_data.getContainerChecked( index_attribute, FlowData.DataType.Int, ctx, self )
		if not user_indices:
			return
		nearest_indices = user_indices
	else:
		var kdtree = GDKdTree.new()
		kdtree.set_points( attractors_pos )
		nearest_indices = kdtree.find_nearest_indices( in_pos )

	var num_attractors = attractors_pos.size()
	var out_container := PackedVector3Array()
	var in_size : int = in_data.size()
	out_container.resize( in_size )
	for idx in range(in_size):
		var nearest_attractor_index := nearest_indices[ idx ]
		if nearest_attractor_index < num_attractors:
			var nearest_attractor := attractors_pos[ nearest_attractor_index ]
			var delta := nearest_attractor - in_pos[ idx ]
			if delta.length() < max_distance:
				if weight >= 0:
					out_container[ idx ] = in_pos[ idx ] + delta * weight
				else:
					var unit_delta = -delta.normalized()
					out_container[ idx ] = in_pos[ idx ] - unit_delta * ( max_distance - delta.length() )  * weight
			else:
				out_container[ idx ] = in_pos[ idx ]			
		else:
			out_container[ idx ] = in_pos[ idx ]
			
	out_data.registerStream( out_name, out_container )
	setOutput(ctx, 0, out_data )
		
