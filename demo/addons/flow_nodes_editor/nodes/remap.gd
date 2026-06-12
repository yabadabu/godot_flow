@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Remap",
		"settings" : RemapNodeSettings,
		"ins" : [{ "label" : "In" }],
		"outs" : [{ "label" : "Out" }],
		"category" : "Density",
		"tooltip" : "Remaps the input values using a curve\nValues outside the curve's domain (0..1 by default) are clamped.\nSet Out Name to '@in_name' to overwrite the source attribute in place.",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = require_input(0, _ctx)
	if in_data == null:
		return

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
	var stream_size : int = in_container.size()
	if stream_size != in_size and stream_size != 1:
		setError( "Input stream %s must have %d values or 1 value (got %d)" % [settings.in_name, in_size, stream_size] )
		return
	var out_container = PackedFloat32Array()
	out_container.resize( in_size )
	for idx in in_size:
		out_container[idx] = c.sample( in_container[FlowData.bcast_idx(stream_size, idx)] )
	out_data.registerStream( out_name, out_container )
	
	set_output( 0, out_data )
