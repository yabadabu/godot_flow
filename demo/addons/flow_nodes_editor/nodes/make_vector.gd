@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Make Vector",
		"settings" : MakeVectorNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.Vector }],
		"aliases" : ["Vector Constant", "Make Vec3"],
		"category" : "Utility",
		"tooltip" : "Creates a single Vector value from 3 immediate float values",
		#"trace" : true
	}

func execute( ctx : FlowData.EvaluationContext ):
	var ix = getSettingValue( ctx, "x", 0.0)
	var iy = getSettingValue( ctx, "y", 0.0)
	var iz = getSettingValue( ctx, "z", 0.0)

	var output := FlowData.Data.new()
	var container : PackedVector3Array = output.addStream( settings.out_name, FlowData.DataType.Vector )
	container.resize( 1 )
	container[0] = Vector3( ix, iy, iz )
	set_output( 0, output )
