@tool
class_name FilterDataByIndexNodeSettings
extends NodeSettings

@export_group("Filter Data By Index")

@export var indices: String = ""

func _init():
	super._init()
	resource_name = "Filter Data By Index"
