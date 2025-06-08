@tool
extends Control

@export var data_ex : int = 0:
	set(new_value):
		data_ex = new_value
		refresh()

var node : FlowNodeBase

func setNode( new_node : FlowNodeBase ):
	# If there was already one active... disabled it
	if node:
		%LabelTitle.text = "..."
		if node.settings:
			node.settings.inspect_enabled = false
			node.refreshFromSettings()
		
	if node != new_node and new_node:
		%LabelTitle.text = new_node.get_title()
		new_node.settings.inspect_enabled = true
		node = new_node
	else:
		node = null
		refresh()

func addLabel( gc : Container, str_data : String ):
	var c = Label.new()
	c.text = str_data
	gc.add_child( c )
	return c
	
func addColor( gc : Container, data : Color ):
	var c = ColorRect.new()
	c.custom_minimum_size = Vector2( 16,16 )
	c.color = data
	gc.add_child( c )
	return c
	
func refresh():
	print( "refresh is ", node)
	
	var cols = find_child("Columns")
	if cols == null:
		return
	
	# Remove prev columns
	for i in range( 0, cols.get_child_count() ):
		cols.remove_child( cols.get_child( cols.get_child_count() - 1 ))
	
	if node == null:
		return
		
	var data = node.get_output(0)

	# Background color (zebra striping)
	var styleA = StyleBoxFlat.new()
	styleA.bg_color = Color(0.5, 0.5, 0.5)
	var styleB = StyleBoxFlat.new()
	styleB.bg_color = styleA.bg_color + Color( 0.1, 0.1, 0.1 )
	
	for stream in data.streams.values():
		
		# Add the title
		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var head = addLabel( col, " %s " % stream.name )
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		# Add the data
		match stream.data_type:
			FlowData.DataType.Vector:
				var container : PackedVector3Array = stream.container
				for idx in range( container.size() ):
					var cell = container[idx]
					var c = addLabel( col, str(cell) )
					#c.add_theme_stylebox_override( "normal", styleA if (idx % 2) else styleB )
				#cidx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
			FlowData.DataType.Float:
				var container : PackedFloat32Array = stream.container
				for idx in range( container.size() ):
					var cell = container[idx]
					var c = addLabel( col, "%1.4f" % cell )
					#c.add_theme_stylebox_override( "normal", styleA if (idx % 2) else styleB )
					c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
			# type not supported...
			
		cols.add_child( col )
	
func _ready():
	refresh()

func _on_btn_refresh_pressed():
	refresh()
