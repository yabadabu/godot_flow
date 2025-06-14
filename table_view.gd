extends VBoxContainer

@onready var col_titles := $ColumnTitles
var columns : Array[ Label ] = []
var col_starts : Array[ float ] = []
var col_widths : Array[ float ] = []

func clearColumns():
	columns.clear()
	col_starts.clear()
	col_widths.clear()

func addColumn( text : String ):
	var parent = col_titles

	var lbl = Label.new()
	lbl.text = text

	while true:
		var child_count = parent.get_child_count()
		if child_count== 0:
			break
		elif child_count == 1:
			var hs := HSplitContainer.new()
			parent.add_child( hs )
			parent = hs
			hs.dragged.connect( splitDragged )
			break
		else:
			parent = parent.get_child(1)
			
	columns.append( lbl )
	parent.add_child( lbl )
	
func splitDragged( _offset : int ):
	col_starts.clear()
	col_widths.clear()
	for col in columns:
		var pos = col.get_global_transform().origin
		var lbl_size = col.size
		col_starts.append( pos.x )
		col_widths.append( lbl_size.x )
	if col_starts.size() > 0:
		col_starts.append( col_starts.back() + col_widths.back() )
		col_widths.append( 0 )
	$ScrollContainer.col_starts = col_starts
	$ScrollContainer.col_widths = col_widths
	updateInfo()
	$ScrollContainer.queue_redraw()
	
func updateInfo():
	var ctxt : String = ""
	for idx in range( col_starts.size() ):
		ctxt = ctxt + " / %d - %d" % [ col_starts[idx], col_widths[idx] ] 
	$DebugInfo.text = ctxt

func refreshUI():
	splitDragged(0)

func _ready():
	col_titles.dragged.connect( splitDragged )
	clearColumns()
	addColumn( "Position.X" )
	addColumn( "Position.Y" )
	addColumn( "Position.Z" )
	addColumn( "Density" )
	call_deferred( "refreshUI" )
