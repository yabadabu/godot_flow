@tool
extends FlowNodeBase

func getMeta() -> Dictionary :
	return {
		"title" : "Input",
		"settings" : InputNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" :"Exposes an input of the Flow",
		"auto_register" : false
	}
	
func getTitle() -> String:
	return settings.name

func execute( ctx : FlowData.EvaluationContext ):

	if not ctx or not ctx.graph or not ctx.graph.inputs:
		setError( "Graph does not define any input")
		return
	
	var input = null
	for candidate in ctx.graph.inputs.inputs:
		if candidate.name == settings.name:
			input = candidate
			break
	
	if not input:
		setError( "%s is not a valid input of the flow graph")
		return
	
	var output := FlowData.Data.new()
	var container : Array = output.addStream( settings.name, input.data_type )
	if not container:
		setError( "Invalid name or data_type")
		return
	container.resize( 1 )
	container[0] = input.value
	set_output( 0, output )
