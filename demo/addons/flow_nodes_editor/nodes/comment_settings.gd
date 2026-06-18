@tool
class_name CommentNodeSettings
extends NodeSettings

@export_group("Comment")
@export_multiline var text := "..."
@export_range(0.0, 1.0)  var hue : float = 0.5

func _init():
	super._init()
	resource_name = "Comments Settings"
