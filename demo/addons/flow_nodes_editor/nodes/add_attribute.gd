@tool
extends FlowNodeBase

@export var attr_name : String = "new_attr"
@export var data_type : FlowData.DataType = FlowData.DataType.Float:
	set(new_value):
		if new_value != FlowData.DataType.Any and new_value != FlowData.DataType.Invalid:
			data_type = new_value
			connections_changed.emit()
			notify_property_list_changed()
		
@export var cte_bool: bool = false
@export var cte_int : int = 0
@export var cte_float : float = 0.0
@export var cte_vector : Vector3 = Vector3.ZERO
@export var cte_color : Color = Color.WHITE
@export var cte_resource : Resource
@export var cte_string : String = ""

func _init():
	meta_node = {
		"title" : "Add Attribute",
		"category" : "Metadata",
		"ins" : [{ "label": "In", "optional": true }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Add a new constant stream to the input set\nIf the input is not given a single entry with the constant value is created.",
	}
	
func getTitle() -> String:
	return "%s - %s" % [ attr_name, FlowData.DataType.keys()[data_type] ]

func exposedAsInputNode( prop ):
	if prop.name.begins_with( "cte_" ):
		var name_lc = FlowData.DataType.keys()[ data_type ].to_lower()
		return prop.name == "cte_" + name_lc
	return false

func exposeParam( name : String ):
	var name_lc = FlowData.DataType.keys()[ data_type ].to_lower()
	if name.begins_with( "cte_" ):
		return name == "cte_" + name_lc
	return true

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getOptionalInput(ctx, 0)
	var out_data : FlowData.Data
	var out_size := 1
	if in_data:
		out_data = in_data.duplicate()
		out_size = in_data.size()
	else:
		out_data = FlowData.Data.new()
	
	var new_val
	match data_type:
		FlowData.DataType.Bool:
			new_val = 1 if getSettingValue( ctx, "cte_bool") else 0
		FlowData.DataType.Int:
			new_val = getSettingValue( ctx, "cte_int" )
		FlowData.DataType.Float:
			new_val = getSettingValue( ctx, "cte_float" )
		FlowData.DataType.Vector:
			new_val = getSettingValue( ctx, "cte_vector" )
		FlowData.DataType.Color:
			new_val = getSettingValue( ctx, "cte_color" )
		FlowData.DataType.String:
			new_val = getSettingValue( ctx, "cte_string" )
		FlowData.DataType.Resource:
			new_val = getSettingValue( ctx, "cte_resource" )

	var container = out_data.newContainerOfType( data_type )
	container.resize( out_size )
	container.fill( new_val )

	out_data.registerStream( attr_name, container, data_type )
	setOutput(ctx, 0, out_data )
