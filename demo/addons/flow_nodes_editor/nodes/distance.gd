@tool
extends FlowNodeBase

@export var max_distance : float = 0.0

var HiddenFromThisPoint := true
@export var out_name : String = "distance"
@export var in_nameA : String = FlowData.AttrPosition
@export var in_nameB : String = FlowData.AttrPosition

func _init():
	meta_node = {
		"title" : "Distance",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }, { "label": "Target" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Creates a new attribute where the value is\nthe minimum distance from each point to any of the points in the second set.\nThe value can be normalized to an optional Max Distance",
	}

func execute( ctx : FlowData.EvaluationContext ):
	
	if not out_name:
		setError( "Output name can't be empty")
		return
		
	var in_dataA : FlowData.Data = get_input(0)
	if not in_dataA.hasStreamOfType( in_nameA, FlowData.DataType.Vector ):
		setError( "Input A %s not found" % [in_nameA])
		return
		
	var in_dataB : FlowData.Data = get_input(1)
	if not  in_dataB.hasStreamOfType( in_nameB, FlowData.DataType.Vector ):
		setError( "Input B %s not found" % [in_nameB])
		return
		
	var sA := in_dataA.getVector3Container( in_nameA )
	var sB := in_dataB.getVector3Container( in_nameB )
		
	var size_A = in_dataA.size()
		
	var kdtree = GDKdTree.new()
	kdtree.set_points( sB )
	#print( "Populated kdtree with %d points. WIll check %d" % [in_dataB.size(), size_A])
	var nearest_indices : PackedInt32Array = kdtree.find_nearest_indices( sA )
	
	var inv_max_distance : float = 1.0 / max_distance if max_distance > 0 else 1.0
	
	var out_data : FlowData.Data = in_dataA.duplicate()
	var out_container := PackedFloat32Array()
	out_container.resize( size_A )
	for idx in range(size_A):
		var idxB := nearest_indices[ idx ]
		var delta := sA[ idx ] - sB[ idxB ]
		out_container[ idx ] = delta.length() * inv_max_distance
	
	var err = out_data.registerStream( out_name, out_container )
	set_output( 0, out_data )
