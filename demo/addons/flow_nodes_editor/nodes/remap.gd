@tool
extends FlowNodeBase

@export var in_name : String = "density"
@export var out_name : String = "@source"
@export var remap_curve : Curve

func _init():
	
	remap_curve = Curve.new()
	remap_curve.add_point( Vector2(0,0) )
	remap_curve.add_point( Vector2(1,1) )
	resource_name = "Remap Settings"
	
	meta_node = {
		"title" : "Remap",
		"category" : "Metadata",
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Remaps the input values using a curve",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	
	var sA = in_data.findStream( in_name )
	if sA == null:
		setError( "Input %s not found" % [in_name])
		return
		
	# Confirm it has the correct type (float)
	if sA.data_type != FlowData.DataType.Float:
		setError( "Input stream %s should have data type float" % [in_name])
		return
		
	var out_name = out_name
	if out_name == "@source":
		out_name = sA.name
		
	var out_data : FlowData.Data = in_data.duplicate()
	var in_container = sA.container
		
	var c : Curve = remap_curve
	var in_size := in_data.size()
	var out_container = PackedFloat32Array()
	out_container.resize( in_size )
	for idx in in_size:
		out_container[idx] = c.sample( in_container[idx] )
	out_data.registerStream( out_name, out_container )
	
	set_output( 0, out_data )
