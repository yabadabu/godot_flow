@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Input",
		"settings" : InputNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Exposes an input of the Flow",
		"auto_register" : false,
		"hide_inputs" : true
	}
	
func getTitle() -> String:
	return settings.name

func findInputInCtx( ctx : FlowData.EvaluationContext ):
	for candidate in ctx.graph.inputs.inputs:
		if candidate.name == settings.name:
			return candidate
	return null

func refreshFromSettings():
	super.refreshFromSettings()
	print( "settings.data_type", settings.data_type)
	var gd_type := getGdScriptTypeForFlowDataType( settings.data_type )
	print( "gd_type", gd_type)
	var color := getColorForGDScriptType( gd_type )
	set_slot_color_right( 0, color )

func execute( ctx : FlowData.EvaluationContext ):
	
	if not ctx or not ctx.graph or not ctx.graph.inputs:
		setError( "Graph does not define any input")
		return
	
	var input = findInputInCtx( ctx )
	if not input:
		setError( "%s is not a valid input of the flow graph")
		return
	
	var output := FlowData.Data.new()
	if input.data_type == FlowData.DataType.Float:
		var container : PackedFloat32Array = output.addStream( settings.name, input.data_type )
		if container == null:
			setError( "Invalid name %s or data_type %d" % [settings.name, input.data_type ])
			return
		container.resize( 1 )
		container[0] = input.cte_float
		
	elif input.data_type == FlowData.DataType.Vector:
		var container : PackedVector3Array = output.addStream( settings.name, input.data_type )
		if container == null:
			setError( "Invalid name %s or data_type %d" % [settings.name, input.data_type ])
			return
		container.resize( 1 )
		container[0] = input.cte_vector
		
	set_output( 0, output )
