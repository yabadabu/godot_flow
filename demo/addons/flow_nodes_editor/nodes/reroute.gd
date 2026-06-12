@tool
extends FlowNodeBase

const HIT_SIZE := Vector2(42, 24)
const PIN_RADIUS := 5.0
const GRAPH_BG_COLOR := Color("0b0d12")
const SELECTED_OUTLINE_COLOR := Color("fbbf24")
const SELECTED_OUTLINE_WIDTH := 1.5

func _init():
	meta_node = {
		"title" : "",
		"settings" : NodeSettings,
		"ins" : [{ "label" : "", "data_type" : FlowData.DataType.Invalid }],
		"outs" : [{ "label" : "", "data_type" : FlowData.DataType.Invalid }],
		"aliases" : ["Reroute"],
		"category" : "Utility",
		"tooltip" : "Reroute point - passes data through unchanged",
		"hide_inputs" : false,
		"auto_register" : false,
	}

func getTitle() -> String:
	# Stay compact: the node renders as a 30x30 dot without a visible title.
	return ""

func getExposedParams():
	return []

func initFromScript():
	super.initFromScript()
	for child in get_children():
		var row := child as FlowConnectorRow
		if row == null:
			continue
		row.custom_minimum_size = HIT_SIZE
		row.getInLabel().text = ""
		row.getOutLabel().text = ""
		row.getInLabel().visible = false
		row.getOutLabel().visible = false
	custom_minimum_size = HIT_SIZE
	size = HIT_SIZE

func refreshFromSettings():
	super.refreshFromSettings()
	title = ""
	custom_minimum_size = HIT_SIZE
	size = HIT_SIZE
	if is_slot_enabled_left(0):
		set_slot_color_left(0, Color.WHITE)
	if is_slot_enabled_right(0):
		set_slot_color_right(0, Color.WHITE)

func execute( ctx : FlowData.EvaluationContext ):
	var in_data = get_optional_input(0)
	if in_data:
		set_output(0, in_data)
	else:
		set_output(0, FlowData.Data.new())

func _ready():
	super._ready()
	custom_minimum_size = HIT_SIZE
	size = HIT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	selectable = true
	draggable = true

func _draw_port(_slot_index: int, position: Vector2i, left: bool, _color: Color) -> void:
	if left:
		return
	var center := Vector2(size.x * 0.5, position.y)
	draw_circle(center, PIN_RADIUS + 1.5, GRAPH_BG_COLOR)
	draw_circle(center, PIN_RADIUS, Color.WHITE)

func _on_draw() -> void:
	var port_y := size.y * 0.5
	if get_input_port_count() > 0:
		port_y = get_input_port_position(0).y
	var center := Vector2(size.x * 0.5, port_y)
	if selected:
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), SELECTED_OUTLINE_COLOR, false, SELECTED_OUTLINE_WIDTH)
	draw_circle(center, PIN_RADIUS + 1.5, GRAPH_BG_COLOR)
	draw_circle(center, PIN_RADIUS, Color.WHITE)
