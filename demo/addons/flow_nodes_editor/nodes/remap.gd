@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Remap",
		"settings" : RemapNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Remaps the input values using a curve",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	
	var sA = in_data.findStream( settings.in_name )
	if sA == null:
		setError( "Input %s not found" % [settings.in_name])
		return
		
	# Confirm it has the correct type (float)
	if sA.data_type != FlowData.DataType.Float:
		setError( "Input stream %s should have data type float" % [settings.in_name])
		return
		
	var out_name = settings.out_name
	if out_name == "@in_name":
		out_name = sA.name
		
	var out_data : FlowData.Data = in_data.duplicate()
	var in_container = sA.container
		
	var c : Curve = settings.remap_curve
	var in_size := in_data.size()
	var out_container = PackedFloat32Array()
	out_container.resize( in_size )
	for idx in in_size:
		out_container[idx] = c.sample( in_container[idx] )
	out_data.registerStream( out_name, out_container )
	
	set_output( 0, out_data )
