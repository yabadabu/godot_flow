@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Add Attribute",
		"settings" : AddAttributeNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"hide_inputs" : true,
	}
	
func getTitle() -> String:
	return "%s - %s" % [ settings.name, FlowData.DataType.keys()[settings.data_type] ]

func execute( _ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_optional_input(0)
	var out_data : FlowData.Data
	var out_size := 1
	if in_data:
		out_data = in_data.duplicate()
		out_size = in_data.size()
	else:
		out_data = FlowData.Data.new()
	
	var new_val
	match settings.data_type:
		FlowData.DataType.Bool:
			new_val = 1 if settings.cte_bool else 0
		FlowData.DataType.Int:
			new_val = settings.cte_int
		FlowData.DataType.Float:
			new_val = settings.cte_float
		FlowData.DataType.Vector:
			new_val = settings.cte_vector
		FlowData.DataType.String:
			new_val = settings.cte_string
		FlowData.DataType.Resource:
			new_val = settings.cte_resource

	var sout = out_data.addStream( settings.name, settings.data_type )
	sout.resize( out_size )
	sout.fill( new_val )
	set_output( 0, out_data )
