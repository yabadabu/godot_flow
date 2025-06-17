@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Add Attribute",
		"settings" : AddAttributeNodeSettings,
		"ins" : [{"label": "In A" }], 
		"outs" : [{ "label" : "Out" }],
		"hide_inputs" : true,
	}
	
func getTitle() -> String:
	return "%s - %s" % [ settings.name, FlowData.DataType.keys()[settings.data_type] ]

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	
	match settings.data_type:
		
		FlowData.DataType.Float:
			var new_val : float = settings.cte_float
			var sout : PackedFloat32Array = out_data.addStream( settings.name, settings.data_type )
			for i in sout.size():
				sout[i] = new_val
				
		FlowData.DataType.Vector:
			var new_val : Vector3 = settings.cte_vector
			var sout : PackedVector3Array = out_data.addStream( settings.name, settings.data_type )
			for i in sout.size():
				sout[i] = new_val
				
		FlowData.DataType.String:
			var new_val : String = settings.cte_string
			var sout : Array[String] = out_data.addStream( settings.name, settings.data_type )
			for i in sout.size():
				sout[i] = new_val
				
		FlowData.DataType.Resource:
			var new_val : Resource = settings.cte_resource
			var sout : Array[Resource] = out_data.addStream( settings.name, settings.data_type )
			for i in sout.size():
				sout[i] = new_val

	set_output( 0, out_data )
