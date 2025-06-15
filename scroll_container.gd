extends ScrollContainer

var col_starts : Array[ float ] = []
var col_widths : Array[ float ] = []	
var font : Font
var line_height : int = 0

func _ready():
	var hbar = get_h_scroll_bar()
	var vbar = get_v_scroll_bar()
	hbar.value_changed.connect( _on_scroll_changed )
	vbar.value_changed.connect( _on_scroll_changed )
	font = get_theme_default_font()
	line_height = get_theme_default_font_size() + 1
	$Contents.custom_minimum_size = Vector2(400, 20 )
	
func _on_scroll_changed(_value):
	queue_redraw()
	
func verticalLine( x0 : int, color : Color ):
	var y0 = 0
	var y1 = size.y + y0
	var p0 := Vector2( x0, y0 )
	var p1 := Vector2( x0, y1 )
	draw_line( p0, p1, color )
	
func horizontallLine( y0 : int, color : Color ):
	var x0 = 0
	var x1 = size.x + x0
	var p0 := Vector2( x0, y0 )
	var p1 := Vector2( x1, y0 )
	draw_line( p0, p1, color )

func drawCell( cell_pos : Vector2, width: float, row : int,  col : int ):
	draw_string( font, cell_pos, "%d/%d _#gpB0" % [ row, col ], HORIZONTAL_ALIGNMENT_RIGHT, width )
		
func drawVerticalLines():
	for idx in range( col_starts.size() ):
		var x0 = col_starts[idx]
		verticalLine( x0 - 6, Color.GREEN_YELLOW )
		#verticalLine( x0, Color.GREEN_YELLOW )
		#verticalLine( x0 + col_widths[idx], Color.WHITE )	

func drawCol( col_idx : int, y0 : float, row_idx : int ):
	var y1 := size.y
	var cell_pos := Vector2( 0, y0 )
	var w = col_widths[ col_idx ]
	cell_pos.x = col_starts[ col_idx ]
	
	# No need to render fully clipped columns
	if cell_pos.x > size.x || cell_pos.x + w < 0:
		return
		
	while y0 < y1:
		#horizontallLine( y0, Color.AQUA )
		cell_pos.y = y0 + line_height - 6
		
		drawCell( cell_pos, w, row_idx, col_idx )
		
		y0 += line_height
		row_idx += 1	
		

func drawBackgrounds( y0 : float, row_idx : int ):
	var w = size.x
	var y1 := size.y
	var pos := Vector2( 0, y0 )
	while y0 < y1:
		if row_idx & 1:
			draw_rect( Rect2( pos + Vector2( 0, 3 ), Vector2( w, line_height - 2 )), Color.DIM_GRAY )
		pos.y = y0 + line_height - 2
		y0 += line_height
		row_idx += 1		

func _draw():
	if col_starts.size() == 0:
		return
	
	var voffset := scroll_vertical
	var y0 := -voffset
	
	var row_idx = 0
	var num_hidden_rows = int( floor( voffset / line_height ) )
	if num_hidden_rows < 0:
		num_hidden_rows = 0	
		
	y0 += num_hidden_rows * line_height
	row_idx += num_hidden_rows
	
	drawBackgrounds( y0, row_idx )
	
	for col in range(col_starts.size()-1):
		drawCol( col, y0, row_idx )

	drawVerticalLines()
