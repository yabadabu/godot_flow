@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Input",
		"settings" : InputNodeSettings,
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Exposes an input of the Flow Graph Node into the Graph",
		"auto_register" : false,
		"hide_inputs" : true
	}
	
func getTitle() -> String:
	return settings.name

func refreshFromSettings():
	super.refreshFromSettings()
	#print( "settings.data_type", settings.data_type)
	var gd_type := getGdScriptTypeForFlowDataType( settings.data_type )
	#print( "gd_type", gd_type)
	var color := getColorForGDScriptType( gd_type )
	set_slot_color_right( 0, color )

func execute( ctx : FlowData.EvaluationContext ):
	
	if not ctx.graph or ctx.graph.in_params.size() == 0:
		setError( "Graph does not define any input")
		return
	
	var input = ctx.graph.findInParamByName( settings.name )
	if not input:
		setError( "%s is not a valid input name of the flow graph" % settings.name)
		return
	
	var output := FlowData.Data.new()
	var new_container = output.addStream( settings.name, input.data_type )
	if new_container == null:
		setError( "Invalid name %s or data_type %d (bool)" % [settings.name, input.data_type ])
		return
		
	# Decide if we use the default value or the user has provided one in the instanced FlowGraphNode
	var new_value = input.get_default_value()
	if ctx.owner and ctx.owner.args.has( input.name ):
		var ctx_value = ctx.owner.args[ input.name ]
		if FlowNodeBase.getFlowDataTypeFromGdScriptType( typeof( ctx_value ) ) == input.data_type:
			new_value = ctx.owner.args[ input.name ]

	# Assign the value to the output container
	var container =	output.streams[ settings.name ].container
	container.resize( 1 )
	container[0] = new_value
		
	set_output( 0, output )
