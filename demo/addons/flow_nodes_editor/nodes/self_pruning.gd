@tool
extends FlowNodeBase

@export var keep_self_intersections : bool = false

func _init():
	meta_node = {
		"title" : "Self Pruning",
		"category" : "Filter",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Rejects any point overlaping previous points.",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var in_dataA: FlowData.Data = get_input(0)
	
	if in_dataA == null:
		setError( "Input not found")
		return
		
	var tA := GDRTree.new()
	var posA = in_dataA.getVector3Container( FlowData.AttrPosition )
	var szA = in_dataA.getVector3Container( FlowData.AttrSize )
	var result = tA.self_prune( posA, szA, keep_self_intersections )
	
	var out_data : FlowData.Data = in_dataA.filter( result.idxs_overlapped )
		
	set_output( 0, out_data )
