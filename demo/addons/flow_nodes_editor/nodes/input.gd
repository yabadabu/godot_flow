@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Input",
		"settings" : InputNodeSettings,
		"category" : "Control Flow",
		"ins" : [],
		"outs" : [{ "label" : "Data" }],
		"tooltip" : "Exposes an input of the Flow Graph Node into the Graph",
		"auto_register" : true,
		"hide_inputs" : true
	}
	
#var output : FlowData.Data
var change_id : int = -1
	
func getTitle() -> String:
	return settings.name

func refreshFromSettings():
	var editor = getEditor()
	if editor and editor.current_resource:
		var input = editor.current_resource.findInParamByName( settings.name )

		var data_type : FlowData.DataType = input.getDataType() if input else FlowData.DataType.Invalid
		meta_node.outs[0].data_type = data_type
			
		# Update the color
		if data_type == FlowData.DataType.Invalid:
			set_slot_color_right( 0, Color.WHITE )
		else:
			var color := getColorForFlowDataType( data_type )
			set_slot_color_right( 0, color )
	super.refreshFromSettings()

func onPropChanged( prop_name : String ):
	super.onPropChanged( prop_name )
	refreshFromSettings()

#func preExecute( ctx : FlowData.EvaluationContext ):
	#super.preExecute( ctx )
	#print( "input.preExecute")

	#if not ctx.graph or ctx.graph.in_params.size() == 0:
		#setError( "Graph does not define any input")
		#return
	#
	#var input := ctx.graph.findInParamByName( settings.name )
	#if not input:
		#setError( "%s is not a valid input name of the flow graph" % settings.name)
		#return
		#
	#if input.is_constant:
		##print( "input.is constant")
		#
		#output = FlowData.Data.new()
		#var new_container = output.addStream( settings.name, input.data_type )
		#if new_container == null:
			#setError( "input.Invalid name %s or data_type %d (bool)" % [settings.name, input.data_type ])
			#return
			#
		## Decide if we use the default value or the user has provided one in the instanced FlowGraphNode
		#var new_value = input.getDefaultValue()
		#if ctx.owner and ctx.owner.args.has( input.name ):
			#var ctx_value = ctx.owner.args[ input.name ]
			#if settings.trace: print( "input ctx_value %s. Owner:%s" % [ ctx_value, ctx.owner.name ] )
			#if FlowNodeBase.getFlowDataTypeFromGdScriptType( typeof( ctx_value ) ) == input.data_type:
				#new_value = ctx.owner.args[ input.name ]
#
		## Assign the value to the output container
		#var container =	output.streams[ settings.name ].container
		#container.resize( 1 )
		#container[0] = new_value
		#last_value_pushed = new_value
		#
		#if settings.trace: print( "input outputs %s" % new_value )
#
	#else:
		#if ctx.inputs.has( input.name ):
			#output = ctx.inputs[ input.name ]
			##print( "input.Reading %s from ctx -> %s" % [input.name, output])
		#else:
			##print( "input.Reading %s from ctx FAILED. Inputs;%s" % [input.name, ctx.inputs])
			#output = FlowData.Data.new()
		#last_value_pushed = null
	#output.dump( "input.preExe.done" )

func execute( ctx : FlowData.EvaluationContext ):
	#print( "input. using cached data %s from ctx -> %s" % [name, output])
	var output = ctx.resolveInput( settings.name )
	set_output( 0, output )
	
