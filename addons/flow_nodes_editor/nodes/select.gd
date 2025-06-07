@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Select",
		"settings" : SelectNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Filter inputs by the ratio.\nSo when ratio = 0.2, only 20% of the input points will appear in the output.",
	}

func execute( ):
	var in_data = get_input(0)
	var out_data = []
	var in_size = in_data.size()
	var out_size = round(in_size * settings.ratio)
	# print( "From %d, took %1.2f%% -> %d" % [ in_size, ratio, out_size ])
	
	var pool := range(in_size)
	shuffleArray( pool )
	var subset := pool.slice(0, out_size)
	subset.sort()
	
	for idx in subset:
		out_data.append( in_data[idx] )
	set_output( 0, out_data )
