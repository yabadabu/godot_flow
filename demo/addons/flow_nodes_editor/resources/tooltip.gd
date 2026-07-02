@tool
extends Control
const PADDING := Vector2(16, 16)
func set_tooltip_text(text: String) -> void:
	var content : RichTextLabel = get_child(0)
	content.text = text
	if not content.finished.is_connected(_on_content_finished):
		content.finished.connect(_on_content_finished)

func _on_content_finished() -> void:
	var content : RichTextLabel = get_child(0)
	var content_size := Vector2(content.get_content_width(), content.get_content_height())
	content_size += PADDING
	content.custom_minimum_size = content_size 
	custom_minimum_size = content_size
