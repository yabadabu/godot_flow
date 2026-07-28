@tool
class_name FlowGraphRedirect
extends Resource

@export_storage var redirect_id: StringName

@export var name: String = "Redirect":
	set(value):
		if name == value:
			return
		name = value
		emit_changed()

func ensureId() -> StringName:
	if redirect_id.is_empty():
		redirect_id = StringName(Resource.generate_scene_unique_id())
	return redirect_id
