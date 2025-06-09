@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Assets",
		"settings" : AssetsNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Generates a list of assets",
	}

func execute( _ctx : FlowData.EvaluationContext ):
	var output := FlowData.Data.new()
	var sassets = output.addStream( "assets", FlowData.DataType.DTResource )
	assert( sassets != null )
	var count = settings.assets.size()
	sassets.resize( count )
	for idx in range(count):
		sassets[idx] = settings.assets[idx]
	set_output( 0, output )
