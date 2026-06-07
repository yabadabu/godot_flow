@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Input",
		"settings" : InputNodeSettings,
		"category" : "Control Flow",
		"ins" : [],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Exposes an input of the Flow Graph Node into the Graph",
		"auto_register" : true,
		"hide_inputs" : true
	}
	
func getTitle() -> String:
	return settings.name

func refreshFromSettings():
	var editor = getEditor()
	if editor and editor.current_resource:
		var input = editor.current_resource.findInParamByName( settings.name )
		if input:
			settings.data_type = input.getDataType()
	super.refreshFromSettings()
	
	# Update the color
	if settings.data_type == FlowData.DataType.Invalid:
		set_slot_color_right( 0, Color.WHITE )
	else:
		var color := getColorForFlowDataType( settings.data_type )
		set_slot_color_right( 0, color )

func onPropChanged( prop_name : String ):
	super.onPropChanged( prop_name )
	refreshFromSettings()
		
func execute( ctx : FlowData.EvaluationContext ):
	
	if not ctx.graph or ctx.graph.in_params.size() == 0:
		setError( "Graph does not define any input")
		return
	
	var input := ctx.graph.findInParamByName( settings.name )
	if not input:
		setError( "%s is not a valid input name of the flow graph" % settings.name)
		return
		
	if input.is_constant:
		
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

	else:
		if ctx.inputs.has( input.name ):
			var runtime_input = ctx.inputs[ input.name ]
			set_output( 0, runtime_input )
		else:
			set_output( 0, FlowData.Data.new() )
