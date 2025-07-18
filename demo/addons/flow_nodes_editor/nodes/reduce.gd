@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Reduce",
		"settings" : ReduceNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}
	
func execute( ctx : FlowData.EvaluationContext ):

	if !settings.in_name:
		setError( "Input attribute not set")
		return
	
	var in_data : FlowData.Data = get_input(0)
	var sA = in_data.findStream( settings.in_name )
	if sA == null:
		setError( "Input %s not found" % [settings.in_name])
		return
	if sA.data_type != FlowData.DataType.Float && sA.data_type != FlowData.DataType.Vector && sA.data_type != FlowData.DataType.Int:
		setError( "Input %s must have Float or Vector types" % [settings.in_name])
		return

	var num_elems := in_data.size()

	var out_prefix = settings.out_prefix
	if !out_prefix:
		out_prefix = settings.in_name.replace( ".", "_")

	var cmin_name = out_prefix + "_min"
	var cmax_name = out_prefix + "_max"
	var cavg_name = out_prefix + "_avg"
	
	var out_data := FlowData.Data.new()
	if num_elems > 0:
		var gmin
		var gmax
		var gavg
		if sA.data_type == FlowData.DataType.Float:
			var inA : PackedFloat32Array = sA.container
			var vmin : float = inA[0]
			var vmax : float = vmin
			var vacc : float = inA[0]				# Sum -> / -> Might not be the most accurate
			for idx in range( 1, num_elems ):
				vmin = minf( vmin, inA[idx] )
				vmax = maxf( vmax, inA[idx] )
				vacc += inA[idx]
			vacc /= float(num_elems)

			gmin = PackedFloat32Array()
			gmin.append( vmin )
			gmax = PackedFloat32Array()
			gmax.append( vmax )
			gavg = PackedFloat32Array()
			gavg.append( vacc )

		elif sA.data_type == FlowData.DataType.Int:
			var inA : PackedInt32Array = sA.container
			var vmin : int = inA[0]
			var vmax : int = vmin
			var vacc := inA[0] as float
			for idx in range( 1, num_elems ):
				vmin = min( vmin, inA[idx] )
				vmax = max( vmax, inA[idx] )
				vacc += inA[idx]
			vacc /= float(num_elems)

			gmin = PackedInt32Array()
			gmin.append( vmin )
			gmax = PackedInt32Array()
			gmax.append( vmax )
			gavg = PackedFloat32Array()
			gavg.append( vacc )

		elif sA.data_type == FlowData.DataType.Vector:
			var inA : PackedVector3Array = sA.container
			var vmin : Vector3 = inA[0]
			var vmax : Vector3 = vmin
			var vacc : Vector3 = vmin
			for idx in range( 1, num_elems ):
				vmin = vmin.min( inA[idx] )
				vmax = vmax.max( inA[idx] )
				vacc += inA[idx]
			vacc /= float(num_elems)

			gmin = PackedVector3Array()
			gmin.append( vmin )
			gmax = PackedVector3Array()
			gmax.append( vmax )
			gavg = PackedVector3Array()
			gavg.append( vacc )

		out_data.registerStream( cmin_name, gmin )
		out_data.registerStream( cmax_name, gmax )
		out_data.registerStream( cavg_name, gavg )

	set_output( 0, out_data )
