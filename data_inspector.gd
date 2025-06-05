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
	var gc : GridContainer = %GridContainer
	gc.columns = 3 + 1 
	for i in range( 0, gc.get_child_count() ):
		gc.remove_child( gc.get_child( gc.get_child_count() - 1 ))
	
	# add titles
	for title in titles:
		addLabel( gc, title )

	# add data
	var idx = 0
	for row in datas:
		
		var cidx = addLabel( gc, str(idx))
		cidx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		var col_idx = 0
		for cell in row:
			var data_type = col_types[ col_idx + 1 ]
			if data_type == "int":
				var c = addLabel( gc, str(cell) ) as Label
				c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			elif data_type == "color":
				addColor( gc, cell )
			else:
				addLabel( gc, str(cell) )
				
			col_idx += 1
		idx += 1

func _ready():
	refresh()

func _on_btn_refresh_pressed():
	refresh()
