@tool

## A redirector is an utility of the graph to link inputs and outputs in the graph without using an actual line connections
## but linking the in and outs by name. Imagine you have multiple nodes generating points where trees should not grow.
## You create a RedirectorInput node called "Trees Removed" and add your points to multiple instances of the same redirector name
## Then, when populating the trees or the grass you invoke the RedirectorOutput 'Trees Removed' and this provides all the 
## data that was sent to the RedirectorInput node.
## The main benefit is avoid having long lines in the middle of your graph
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
