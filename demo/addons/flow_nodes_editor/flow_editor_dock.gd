@tool
class_name FlowEditorDock
extends EditorDock

## Bottom-panel dock wrapper: expand like built-in Shader Editor when laid out horizontally.

var _cached_layout: int = DOCK_LAYOUT_HORIZONTAL


func _update_layout(layout: int) -> void:
	_cached_layout = layout
	_apply_panel_fill_layout(layout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_PARENTED:
		_apply_panel_fill_layout(_cached_layout)


func _apply_panel_fill_layout(layout: int) -> void:
	var fill := (
		layout == DOCK_LAYOUT_HORIZONTAL
		or layout == DOCK_LAYOUT_VERTICAL
		or layout == 0
	)
	if not fill:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child in get_children():
		if child is Control:
			var panel := child as Control
			panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
