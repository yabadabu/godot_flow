@tool
extends FlowNodeBase

@export var from_name : String = "@last"
@export var to_name : String = ""
@export var overwrite_existing : bool = false

func _init():
	meta_node = {
		"title" : "Attribute Rename",
		"category" : "Metadata",
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Renames one attribute/stream while preserving its type and values.\nSubstreams like position.X can't be renamed",
	}

func getTitle() -> String:
	return "%s -> %s" % [ from_name, to_name ] 

func execute(ctx : FlowData.EvaluationContext):
	var in_data : FlowData.Data = getInput(ctx, 0)
	if in_data == null:
		setError(ctx, "Input not found")
		return
	var out_data : FlowData.Data = in_data.duplicate()
	var err_msg = out_data.renameStream( from_name, to_name, overwrite_existing )
	if err_msg:
		setError(ctx, err_msg)
	setOutput(ctx, 0, out_data)
