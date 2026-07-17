@tool
extends FlowNodeBase

@export var names : Array[String] = []
@export var keep_selected_attributes : bool = false

func _init():
	meta_node = {
		"title" : "Remove Attributes",
		"category" : "Metadata",
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Remove streams from the input connection.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	var out_data : FlowData.Data = in_data.duplicate()
	
	var streams_to_remove = names
	if keep_selected_attributes:
		streams_to_remove = out_data.streams.keys().filter( func( candidate ): 
			return not candidate in names 
		)
	
	# Remove from the dict	
	for name in streams_to_remove:
		out_data.delStream( name )
		
	set_output( 0, out_data )
