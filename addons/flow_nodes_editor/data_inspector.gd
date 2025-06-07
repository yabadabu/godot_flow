@tool
extends Control

@export var data_ex : int = 0:
	set(new_value):
		data_ex = new_value
		refresh()

var titles = [ "index", "pos", "color", "scale"]
var col_types = [ "int", "vector", "color", "float"]
var datas = [
	[ Vector3(1,0,1), Color.RED, 1.0 ],
	[ Vector3(1,0,0), Color.BLUE, 0.5 ],
	[ Vector3(0,0,1), Color.GREEN, 2.0 ],
]

var node : FlowNodeBase

func setNode( new_node : FlowNodeBase ):
	# If there was already one active... disabled it
	if node:
		%LabelTitle.text = "..."
		if node.settings:
			node.settings.inspect_enabled = false
		
	if node != new_node and new_node:
		%LabelTitle.text = new_node.get_title()
		new_node.settings.inspect_enabled = true
		node = new_node
	else:
		node = null

func addLabel( gc : GridContainer, str_data : String ):
	var c = Label.new()
	c.text = str_data
	gc.add_child( c )
	return c
	
func addColor( gc : GridContainer, data : Color ):
	var c = ColorRect.new()
	c.custom_minimum_size = Vector2( 16,16 )
	c.color = data
	gc.add_child( c )
	return c
	
func refresh():
	var gc : GridContainer = find_child( "GridContainer")
	if not gc:
		return
	gc.columns = 3 + 1 
	
	for i in range( 0, gc.get_child_count() ):
		gc.remove_child( gc.get_child( gc.get_child_count() - 1 ))
	
	# add titles
	for title in titles:
		addLabel( gc, " %s " % title )

	# Background color (zebra striping)
	var styleA = StyleBoxFlat.new()
	styleA.bg_color = Color(0.5, 0.5, 0.5)
	var styleB = StyleBoxFlat.new()
	styleB.bg_color = styleA.bg_color + Color( 0.1, 0.1, 0.1 )

	# add data
	var row_idx = 0
	for row in datas:
		
		var cidx = addLabel( gc, str(row_idx))
		cidx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cidx.add_theme_stylebox_override( "normal", styleA if (row_idx % 2) else styleB )
		
		var col_idx = 0
		for cell in row:
			var c;
			var data_type = col_types[ col_idx + 1 ]
			if data_type == "int":
				c = addLabel( gc, str(cell) ) as Label
				c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			elif data_type == "color":
				c = addColor( gc, cell )
			else:
				c = addLabel( gc, str(cell) )
			
			if c is Label:
				c.add_theme_stylebox_override( "normal", styleA if (row_idx % 2) else styleB )
				
			col_idx += 1
		row_idx += 1

func _ready():
	refresh()

func _on_btn_refresh_pressed():
	refresh()
