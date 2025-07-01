@tool
extends Control

@export var target_left: Control = null
var min_size: int = 10
var drag_active := false
var drag_start := 0

signal dragged( amount : int )

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			drag_active = event.pressed
			drag_start = event.position.x
	elif event is InputEventMouseMotion and drag_active:
		var delta = event.relative.x
		if target_left:
			target_left.custom_minimum_size.x = max(min_size, target_left.size.x + delta)
			dragged.emit( delta )

func _ready():
	var parent := get_parent_control()
	var idx = 0
	var found := false
	if not parent:
		return
	for child in parent.get_children():
		if child == self:
			found = true
			break
		idx = idx + 1
	if found:
		target_left = parent.get_child(idx-1)
		if target_left is Label:
			target_left.custom_minimum_size = target_left.size
			target_left.clip_text = true
