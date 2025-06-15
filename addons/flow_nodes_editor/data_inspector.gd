@tool
extends Control

@export var data_ex : int = 0:
	set(new_value):
		data_ex = new_value
		refresh()

@onready var tv : TableView = %TableView

var node : FlowNodeBase
var num_rows : int = 0
var num_cols : int = 0
var col_titles : Array[String]
var col_streams_names : Array[String]
var data : FlowData.Data 

var container

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
	
func setLabelNumber( label : Label, value : float ):
	var new_text = fmt( value )
	if new_text != label.text:
		label.text = new_text
	
func updateNumRowsAndCols():
	num_rows = data.size()
	col_titles.clear()
	col_streams_names.clear()
	for stream in data.streams.values():	
		var stream_name : String = stream.name
		match stream.data_type:
			FlowData.DataType.Vector:
				col_titles.append( "%s.X" % stream_name)
				col_titles.append( "%s.Y" % stream_name)
				col_titles.append( "%s.Z" % stream_name)
				col_streams_names.append( stream_name)
				col_streams_names.append( stream_name)
				col_streams_names.append( stream_name)
			_:
				col_titles.append( "%s" % stream_name)
				col_streams_names.append( stream_name)
	num_cols = col_titles.size()
	#print( col_titles )
	
func fmt( v : float ) -> String:
	return "%1.4f" % v

func onColumnBegins( cell : DataTableContainer.CellContents ):
	cell.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	if cell.col == 0:
		tv.setCellCallback( getCellContentsIndex )
		return	
	
	# col = 0 is for the Index
	var data_col = cell.col - 1
	if data_col >= col_streams_names.size():
		tv.cell_contents = null
		return
		
	var stream_name = col_streams_names[ data_col ]
	var stream = data.streams.get( stream_name, null )
	if !stream:
		tv.cell_contents = null
		return
	container = stream.container
		
	var title = col_titles[ data_col ]
	if stream.data_type == FlowData.DataType.Vector:
		if title.ends_with(".X"):
			tv.setCellCallback( getCellContentsVectorX )
		elif title.ends_with(".Y"):
			tv.setCellCallback( getCellContentsVectorY )
		elif title.ends_with(".Z"):
			tv.setCellCallback( getCellContentsVectorZ )
	elif stream.data_type == FlowData.DataType.Float:
		tv.setCellCallback( getCellContentsFloat )
	elif stream.data_type == FlowData.DataType.String:
		tv.setCellCallback( getCellContentsString )
		cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
	elif stream.data_type == FlowData.DataType.Resource:
		tv.setCellCallback( getCellContentsResource )
		cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
func getCellContentsVectorX(cell : DataTableContainer.CellContents ):
	cell.text = fmt( container[ cell.row ].x )
	
func getCellContentsVectorY(cell : DataTableContainer.CellContents ):
	cell.text = fmt( container[ cell.row ].y )
	
func getCellContentsVectorZ(cell : DataTableContainer.CellContents ):
	cell.text = fmt( container[ cell.row ].z )
	
func getCellContentsFloat(cell : DataTableContainer.CellContents ):
	cell.text = fmt( container[ cell.row ] )
	
func getCellContentsIndex(cell : DataTableContainer.CellContents ):
	cell.text = "%d" % cell.row
	
func getCellContentsString(cell : DataTableContainer.CellContents ):
	cell.text = container[ cell.row ]
	
func getCellContentsResource(cell : DataTableContainer.CellContents ):
	var res = container[ cell.row ] as Resource
	cell.text = res.resource_path if res else ""
		
func refresh():
	
	if tv == null:
		return

	tv.clearColumns()
	tv.setColumnCallback( onColumnBegins )
	
	data = node.get_output(0) if node else null
	if data:
		updateNumRowsAndCols()
		%LabelStats.text = "%d Rows, (%d cols in %d Streams)" % [ num_rows, num_cols, data.numFields()]
		
		# Index column
		tv.addColumn( "Index", 0 )
		tv.num_rows = num_rows
		tv.setRowHeight( 26 )
		for title in col_titles:
			tv.addColumn( title, 120 )
	tv.commitColumns()

func onCellClicked( row : int, col : int ):
	tv.setSelectedRow( row )

func _ready():
	tv.cell_clicked.connect( onCellClicked )
	refresh()

func _on_btn_refresh_pressed():
	refresh()
