@tool
extends FlowNodeBase

@export var ratio : float = 0.2

func getMeta() -> Dictionary :
	return {
		"title" : "Select",
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
	}

func execute( ):
	var in_data = get_input(0)
	var out_data = []
	var in_size = in_data.size()
	var out_size = round(in_size * ratio)
	# print( "From %d, took %1.2f%% -> %d" % [ in_size, ratio, out_size ])
	
	var pool := range(in_size)
	shuffleArray( pool )
	var subset := pool.slice(0, out_size)
	subset.sort()
	
	for idx in subset:
		out_data.append( in_data[idx] )
	set_output( 0, out_data )
