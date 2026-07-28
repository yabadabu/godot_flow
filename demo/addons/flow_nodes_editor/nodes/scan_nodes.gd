@tool
extends FlowBaseScanNode

@export var filter_by_class_name : String
@export var size_to_bounds : bool = false

func _init():
	meta_node = {
		"title" : "Scan Nodes",
		"category" : "Spatial",
		"scans_scene" : true,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generate points from existing non-flowgraph nodes in the scene\nCan filter by class name, group.\nMetadata values can optionally be imported\nYou can also import properties of the nodes, even with a\nsubpath property like mesh:text if the nodes are a MeshInstance3D with meshes of type TextMesh.",
	}
	
# material[0]:albedo_color
# name

func execute( ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	
	var filter_by_class_name = getSettingValue( ctx, "filter_by_class_name" )
	var nodes = findNodesMatchingFilters( ctx, filter_by_class_name )
	
	var nsamples = nodes.size()
	output.addCommonStreams( nsamples )
	
	var spos := output.getVector3Container( FlowData.AttrPosition )
	var srot := output.getVector3Container( FlowData.AttrRotation )
	var ssize := output.getVector3Container( FlowData.AttrSize )
	for idx in range( nsamples ):
		var node = nodes[idx]
		spos[idx] = node.global_position
		ssize[idx] = node.scale
		var b : Basis = node.global_transform.basis
		srot[idx] = FlowData.basisToEuler( b )
		
		if size_to_bounds:
			var aabb = get_combined_aabb( node )
			ssize[idx] = aabb.size
			spos[idx] = node.transform * ( aabb.position + aabb.size * 0.5 )
			
	importCommon( ctx, output, nodes )

	setOutput(ctx, 0, output )
