@tool
extends Control

@export var data_ex : int = 0:
	set(new_value):
		data_ex = new_value
		refresh()

@onready var cols : HBoxContainer = %Columns

var node : FlowNodeBase
var num_rows : int = 0
var num_cols : int = 0
var col_titles : Array[String]
var data : FlowData.Data 

var styleA = StyleBoxFlat.new()
var styleB = StyleBoxFlat.new()
var style_titles = StyleBoxFlat.new()

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
	
func allocColumn( title : String ):
		
	var col : VBoxContainer = VBoxContainer.new()	
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = 100
		
	for idx in range( num_rows + 1 ):
		var cell : Label = Label.new()
		if idx == 0:
			cell.add_theme_stylebox_override( "normal", style_titles )
			cell.text = title
		elif not idx % 2:
			cell.add_theme_stylebox_override( "normal", styleA )
		else:
			cell.add_theme_stylebox_override( "normal", styleB )
		col.add_child( cell )
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT	
	return col
	
func setLabelText( label : Label, value : float ):
	var new_text = fmt( value )
	if new_text != label.text:
		label.text = new_text
	
func updateNumRowsAndCols():
	num_rows = data.size()
	col_titles.clear()
	for stream in data.streams.values():	
		var stream_name : String = stream.name
		match stream.data_type:
			FlowData.DataType.Vector:
				col_titles.append( "%s.X" % stream_name)
				col_titles.append( "%s.Y" % stream_name)
				col_titles.append( "%s.Z" % stream_name)
			_:
				col_titles.append( "%s" % stream_name)
	num_cols = col_titles.size()
	#print( col_titles )
	
func fmt( v : float ) -> String:
	return "%1.4f" % v
		
func removeAll():
	# Remove everything
	while( cols.get_child_count() > 0):
		var col = cols.get_child( cols.get_child_count()-1)
		cols.remove_child( col )
		col.queue_free()
		
func refresh():
	queue_redraw()
	removeAll()
	
	if cols == null || node == null:
		return

	data = node.get_output(0)
	if data == null:
		return
		
	var prev_num_rows = num_rows
	var prev_num_cols = num_cols
	updateNumRowsAndCols()
	
	%LabelStats.text = "%d Reserved, %d Rows, (%d cols in %d Streams)" % [ cols.get_child_count(), num_rows, num_cols, data.numFields()]
	
	# Index column
	var col_ids = allocColumn("Index")
	for row in range( num_rows ):
		var label : Label = col_ids.get_child( row + 1 )
		label.text = str(row)
	cols.add_child( col_ids )

	style_titles.bg_color = Color( 0.1, 0.1, 0.1 )
	styleA.bg_color = Color( 0.2, 0.2, 0.2, 0.1 )
	styleB.bg_color = styleA.bg_color + Color( 0.1, 0.1, 0.1 )
	for stream in data.streams.values():
		# Add the data
		match stream.data_type:
			FlowData.DataType.Vector:
				var container : PackedVector3Array = stream.container
				var stream_name : StringName = stream.name
				var titles = [" %s.X " % stream.name, " %s.Y " % stream.name, " %s.Z " % stream.name]
				if stream_name == FlowData.AttrRotation:
					titles = ["  Yaw ", "  Pitch ", "  Roll "]
				var colx = allocColumn(titles[0])
				var coly = allocColumn(titles[1])
				var colz = allocColumn(titles[2])
				for idx in range( num_rows ):
					var cell : Vector3 = container[idx]
					var j := idx + 1
					setLabelText( colx.get_child(j), cell.x )
					setLabelText( coly.get_child(j), cell.y )
					setLabelText( colz.get_child(j), cell.z )
				cols.add_child( colx )
				cols.add_child( coly )
				cols.add_child( colz )

			FlowData.DataType.Float:
				var container : PackedFloat32Array = stream.container
				var col = allocColumn(stream.name)
				for idx in range( num_rows ):
					setLabelText( col.get_child(  idx + 1 ), container[idx] )
				cols.add_child( col )

			FlowData.DataType.DTResource:
				var container : Array[ Resource ] = stream.container
				var col = allocColumn(stream.name)
				for idx in range( num_rows ):
					col.get_child( idx + 1 ).text = "   " + container[idx].resource_path
				cols.add_child( col )

			FlowData.DataType.DTString:
				var container : Array[ String ] = stream.container
				var col = allocColumn(stream.name)
				for idx in range( num_rows ):
					col.get_child( idx + 1 ).text = container[ idx ]
				cols.add_child( col )

			## type not supported...
	#
func _ready():
	refresh()

func _on_btn_refresh_pressed():
	refresh()
