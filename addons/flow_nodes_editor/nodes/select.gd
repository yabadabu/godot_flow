@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Select",
		"settings" : SelectNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Filter inputs by the ratio.\nSo when ratio = 0.2, only 20% of the input points will appear in the output.",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	#in_data.dump( "Select.Input")
	var in_size = in_data.size()
	
	var ratio = getSettingValue(ctx, "ratio")
	ratio = clamp( ratio, 0.0, 1.0 )
	
	var out_size = round(in_size * ratio)
	#print( "Select: From %d, took %1.2f%% -> %d" % [ in_size, settings.ratio, out_size ])
	
	var pool := range(in_size)
	shuffleArray( pool )
	var indices = PackedInt32Array( pool )
	var subset := indices.slice(0, out_size)
	subset.sort()
	
	var out_data = in_data.filter( subset )
	set_output( 0, out_data )
