@tool
extends Control
@onready var tv : TableView = $TableView

func getCellContents( cell : DataTableContainer.CellContents ):
	cell.text = "%d/%d _#gpB0" % [ cell.row, cell.col ]
	if cell.col == 7:
		cell.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		cell.alignment = HORIZONTAL_ALIGNMENT_RIGHT

func onCellClicked( row : int, col : int ):
	print( "Click on cell [%d,%d]" % [ row, col ])
	tv.setSelectedRow( row )

func onTitleClicked( col : int ):
	print( "Click on title [%d]" % [  col ])

func _ready():
	tv.clearColumns()
	var columns_names = [
		"Position.X", 
		"Position.Y", 
		"Position.Z", 
		"Density", 
		"Size.X", 
		"Size.Y", 
		"Size.Z", 
		"Extends.X", 
		"Extends.Y", 
		"Extends.Z", 
		"Resource Name", 
	]
	tv.num_rows = 20
	tv.setRowHeight( 14 )
	tv.cell_clicked.connect( onCellClicked )
	tv.title_clicked.connect( onTitleClicked )
	tv.setCellCallback( getCellContents )
	tv.clearColumns()
	for col in columns_names:
		var w = 120
		if col == "Size.X":
			w = 80
		tv.addColumn( col, w )
	tv.commitColumns()
