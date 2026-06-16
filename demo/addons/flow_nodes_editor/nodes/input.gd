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

func execute( ctx : FlowData.EvaluationContext ):
	var output = ctx.resolveInput( settings.name )
	if settings.trace:
		print( "%s Output %s resolved to: %s" % [name, settings.name, output])
	set_output( 0, output )
	
