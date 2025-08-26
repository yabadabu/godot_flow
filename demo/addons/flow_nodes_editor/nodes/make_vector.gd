@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Make Vector",
		"settings" : MakeVectorNodeSettings,
		"ins" : [], 
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.Vector }],
		"tooltip" : "Creates a single Vector value from 3 inmediate float values",
		#"trace" : true
	}

func execute( ctx : FlowData.EvaluationContext ):
	var ix = getSettingValue( ctx, "x")
	var iy = getSettingValue( ctx, "y")
	var iz = getSettingValue( ctx, "z")

	var output := FlowData.Data.new()
	var container : PackedVector3Array = output.addStream( settings.out_name, FlowData.DataType.Vector )
	container.resize( 1 )
	container[0] = Vector3( ix, iy, iz )
	set_output( 0, output )
