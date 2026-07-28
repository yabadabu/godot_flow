@tool
extends FlowNodeBase

@export var x : float
@export var y : float
@export var z : float

# This is a signal to stop presenting the rest of the output as inputs of the box
var HiddenFromThisPoint := true
@export var out_name : String = "Vector"

func _init():
	meta_node = {
		"title" : "Make Vector",
		"category" : "Math",
		"ins" : [], 
		"outs" : [{ "label" : "Out", "data_type" : FlowData.DataType.Vector }],
		"tooltip" : "Creates a single Vector value from 3 inmediate float values",
		#"trace" : true
	}

func execute( ctx : FlowData.EvaluationContext ):
	var ix : float = getSettingValue( ctx, "x")
	var iy = getSettingValue( ctx, "y")
	var iz : float = getSettingValue( ctx, "z")

	var output := FlowData.Data.new()
	var container : PackedVector3Array = output.addStream( out_name, FlowData.DataType.Vector )
	container.resize( 1 )
	if typeof(ix) == TYPE_FLOAT and typeof(iy) == TYPE_FLOAT and typeof(iz) == TYPE_FLOAT:
		container[0] = Vector3( ix, iy, iz )
	setOutput(ctx, 0, output )
