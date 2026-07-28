@tool
extends FlowNodeBase
class_name FlowNodeInput

# Serialized for backwards compatibility and to keep the stable parameter link,
# but neither value is meant to be edited from an Input node.
@export_storage var input_name : String = "in_val"
@export_storage var input_id: StringName

func _init():
	meta_node = {
		"title" : "Input",
		"category" : "Control Flow",
		"ins" : [],
		"outs" : [{ "label" : "Data" }],
		"tooltip" : "Exposes an input of the Flow Graph Node into the Graph",
		"auto_register" : true,
		"hide_inputs" : true
	}

func _validate_property(property: Dictionary) -> void:
	if property.name == "title":
		property.usage = PROPERTY_USAGE_STORAGE
		return
	super._validate_property(property)

func getMeta() -> Dictionary:
	refreshInputMetadata()
	return meta_node

func bindInputParameter(graph: FlowGraphResource) -> void:
	flow_graph = graph
	var input := getInputParameter()
	if not input:
		return
	input_id = input.ensureId()
	input_name = input.name
	refreshInputMetadata()

func getInputParameter() -> GraphInputParameter:
	if not flow_graph:
		return null
	var input := flow_graph.findInParamById(input_id)
	if not input and not input_name.is_empty():
		input = flow_graph.findInParamByName(input_name)
		if input:
			input_id = input.ensureId()
	return input

func refreshInputMetadata() -> void:
	if meta_node.get("outs", []).is_empty():
		return
	var input := getInputParameter()
	if not input:
		return
	input_name = input.name
	var data_type := input.getDataType()
	if data_type == FlowData.DataType.Invalid:
		data_type = FlowData.DataType.Any
	meta_node.outs[0].label = input.name
	meta_node.outs[0].data_type = data_type

func refreshInputDefinition() -> void:
	refreshInputMetadata()
	settings_changed.emit(StringName("input_name"))
	connections_changed.emit()

#func refreshFromSettings():
	#var editor = getEditor()
	#if editor and editor.current_resource:
		#var input = editor.current_resource.findInParamByName( input_name )
#
		#var data_type : FlowData.DataType = input.getDataType() if input else FlowData.DataType.Invalid
		#meta_node.outs[0].data_type = data_type
			#
		## Update the color
		#if data_type == FlowData.DataType.Invalid:
			#set_slot_color_right( 0, Color.WHITE )
		#else:
			#var color := getColorForFlowDataType( data_type )
			#set_slot_color_right( 0, color )
	#super.refreshFromSettings()

#func onPropChanged( prop_name : StringName ):
	#super.onPropChanged( prop_name )
	#refreshFromSettings()

func execute( ctx : FlowData.EvaluationContext ):
	var input := getInputParameter()
	var resolved_name := input.name if input else input_name
	var output = ctx.resolveInput(resolved_name)
	if trace:
		print( "%s Output %s resolved to: %s" % [name, resolved_name, output])
		output.dump("At input %s" % name )
	setOutput(ctx, 0, output )
	
