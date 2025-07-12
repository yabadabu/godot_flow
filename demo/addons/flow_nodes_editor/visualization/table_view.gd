@tool
extends VBoxContainer
class_name TableView

@onready var col_titles := %ColumnTitles
var columns : Array[ Label ] = []
var num_rows : int = 0
var col_starts : Array[ float ] = []
var col_widths : Array[ float ] = []
var style_titles = StyleBoxFlat.new()
var dragging := false

var separator : PackedScene = preload("res://addons/flow_nodes_editor/visualization/draggable_separator.tscn") 

signal cell_clicked( row : int, col : int )
signal title_clicked( col : int )

func clearColumns():
	#print("Clearing rooms")
	num_rows = 0
	for child in col_titles.get_children():
		child.queue_free()
	for idx in range(col_titles.get_child_count()):
		col_titles.remove_child( col_titles.get_child( 0 ))
	columns.clear()
	col_starts.clear()
	col_widths.clear()
	$ScrollContainer.num_rows = num_rows
	$ScrollContainer.col_starts = col_starts

func addColumn( text : String, initial_width : int ):
	var parent = col_titles

	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_stylebox_override( "normal", style_titles )
	#lbl.add_theme_font_size_override("font_size", 14)
	lbl.custom_minimum_size.x = initial_width

	var child_count = parent.get_child_count()
	if child_count== 0:
		parent.add_child( lbl )
	else:
		var hs := separator.instantiate()
		hs.size.y = 8
		hs.dragged.connect( splitDragged )
		parent.add_child( hs )
		parent.add_child( lbl )
			
	columns.append( lbl )
	
func dataScrolled( _offset : int ):
	$TitlesContainer.scroll_horizontal = $ScrollContainer.scroll_horizontal
	call_deferred( "refreshUI" )
	
func titlesScrolled( _offset : int ):
	$ScrollContainer.scroll_horizontal = $TitlesContainer.scroll_horizontal
	call_deferred( "refreshUI" )
	
func splitDragged( _offset : int ):
	if not is_visible_in_tree():
		return
	$TitlesContainer.position.x = 0
	var my_origin = get_global_transform().origin
	col_starts.clear()
	col_widths.clear()
	var idx = 0
	for col in columns:
		var pos = col.get_global_transform().origin
		
		# Confirm we have the layout correctly evaluated...
		if idx == 1 && col.position.x == 0:
			call_deferred( "refreshUI" )
			return
		var lbl_size = col.size
		#print( "cols %s size is %d. Pos %1.1f vs %1.1f vs %1.1f (%s)" % [ col.name, col.size.x, pos.x, my_origin.x, col.position.x, visible ])
		col_starts.append( pos.x - 4 - my_origin.x )
		col_widths.append( lbl_size.x + 2)
		idx += 1
	if col_starts.size() > 0:
		col_widths[ col_widths.size() - 1 ] -= 16
	$ScrollContainer.num_rows = num_rows
	$ScrollContainer.col_starts = col_starts
	$ScrollContainer.col_widths = col_widths
	$ScrollContainer/Contents.custom_minimum_size.x = col_titles.size.x
	$ScrollContainer/Contents.custom_minimum_size.y = num_rows * $ScrollContainer.line_height
	
	style_titles.bg_color = Color( 0.1, 0.1, 0.1 )	
	updateInfo()
	$ScrollContainer.queue_redraw()
	
func updateInfo():
	var ctxt : String = ""
	for idx in range( col_starts.size() ):
		ctxt = ctxt + " / %d - %d" % [ col_starts[idx], col_widths[idx] ] 
	$DebugInfo.text = ctxt

func refreshUI():
	splitDragged(0)

func commitColumns():
	addColumn( "", 0 )
	#print("Comminging columns %d" % col_starts.size())
	call_deferred( "refreshUI" )

func setCellCallback( new_cell_callback : Callable ):
	$ScrollContainer.cell_contents = new_cell_callback

func setColumnCallback( new_callback : Callable ):
	$ScrollContainer.column_callback = new_callback

func _ready():
	$TitlesContainer.get_h_scroll_bar().value_changed.connect( titlesScrolled )
	$ScrollContainer.get_h_scroll_bar().value_changed.connect( dataScrolled )
	#$ScrollContainer/Contents.gui_input.connect( _on_contents_gui_input )

func setSelectedRow( new_row : int ):
	$ScrollContainer.selected_row = new_row
	call_deferred( "refreshUI" )

func setRowHeight( new_height : float ):
	$ScrollContainer.font_size = new_height
	$ScrollContainer.line_height = new_height * 1.4
	
func findColAtX( ex : float ):
	ex -= $ScrollContainer.scroll_horizontal
	for col in range(col_starts.size()-1):
		if ex >= col_starts[ col ] and ex < col_starts[ col+ 1 ]:
			return col
	return -1

func checkSelectedRow( event : InputEvent ):
	if dragging:
		var ex = event.position.x
		var col = findColAtX( ex )
		if col != -1:
			var row = int( ( event.position.y ) / $ScrollContainer.line_height )
			cell_clicked.emit( row, col )
	
	
func _on_contents_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				checkSelectedRow( event )
			else:
				dragging = false
	elif event is InputEventMouseMotion:
		if dragging:
			checkSelectedRow( event )
				

func _on_column_titles_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var col = findColAtX( event.position.x )
				title_clicked.emit( col )

func _input(event):
	if visible and get_rect().has_point(get_local_mouse_position()):
		_on_contents_gui_input( event )

func _on_visibility_changed() -> void:
	if visible:
		call_deferred( "refreshUI" )
