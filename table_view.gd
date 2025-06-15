extends VBoxContainer

@onready var col_titles := %ColumnTitles
var columns : Array[ Label ] = []
var num_rows := 64
var col_starts : Array[ float ] = []
var col_widths : Array[ float ] = []

var separator : PackedScene = preload("res://draggable_separator.tscn") 

func clearColumns():
	columns.clear()
	col_starts.clear()
	col_widths.clear()

func addColumn( text : String ):
	var parent = col_titles

	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2( 20, 0 )

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
	$TitlesContainer.position.x = 0
	col_starts.clear()
	col_widths.clear()
	for col in columns:
		var pos = col.get_global_transform().origin
		var lbl_size = col.size
		col_starts.append( pos.x - 1 )
		col_widths.append( lbl_size.x + 2)
	if col_starts.size() > 0:
		col_widths[ col_widths.size() - 1 ] -= 16
	$ScrollContainer.col_starts = col_starts
	$ScrollContainer.col_widths = col_widths
	$ScrollContainer/Contents.custom_minimum_size.x = %ColumnTitles.size.x
	$ScrollContainer/Contents.custom_minimum_size.y = num_rows * $ScrollContainer.line_height
	updateInfo()
	$ScrollContainer.queue_redraw()
	
func updateInfo():
	var ctxt : String = ""
	for idx in range( col_starts.size() ):
		ctxt = ctxt + " / %d - %d" % [ col_starts[idx], col_widths[idx] ] 
	$DebugInfo.text = ctxt

func refreshUI():
	splitDragged(0)

func getCellContents( cell : DataTableContainer.CellContents ):
	cell.text = "%d/%d _#gpB0" % [ cell.row, cell.col ]
	if cell.col == 7:
		cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		cell.alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _ready():
	$TitlesContainer.get_h_scroll_bar().value_changed.connect( titlesScrolled )
	$ScrollContainer.get_h_scroll_bar().value_changed.connect( dataScrolled )
	$ScrollContainer.cell_contents = getCellContents
	clearColumns()
	addColumn( "Position.X" )
	addColumn( "Position.Y" )
	addColumn( "Position.Z" )
	addColumn( "Density" )
	addColumn( "Size.X" )
	addColumn( "Size.Y" )
	addColumn( "Size.Z" )
	addColumn( "Resource Name" )
	addColumn( "Extends.X" )
	addColumn( "Extends.Y" )
	addColumn( "Extends.Z" )
	addColumn( "" )
	call_deferred( "refreshUI" )
