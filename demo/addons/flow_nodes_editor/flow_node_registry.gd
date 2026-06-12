@tool
extends Object
class_name FlowNodeRegistry

const DEFAULT_NODE_DIRECTORY := "res://addons/flow_nodes_editor/nodes"

static var _extra_node_directories: Array[String] = []
static var _version := 0

static func register_node_directory(directory_path: String) -> void:
	var normalized := _normalize_directory_path(directory_path)
	if normalized.is_empty():
		return
	if normalized == DEFAULT_NODE_DIRECTORY:
		return
	if normalized in _extra_node_directories:
		return
	_extra_node_directories.append(normalized)
	_version += 1

static func unregister_node_directory(directory_path: String) -> void:
	var normalized := _normalize_directory_path(directory_path)
	var index := _extra_node_directories.find(normalized)
	if index == -1:
		return
	_extra_node_directories.remove_at(index)
	_version += 1

static func get_node_directories() -> Array[String]:
	var directories: Array[String] = [DEFAULT_NODE_DIRECTORY]
	directories.append_array(_extra_node_directories)
	return directories

static func get_node_script_path(template_name: String) -> String:
	if template_name.begins_with("input_"):
		return DEFAULT_NODE_DIRECTORY + "/input.gd"
	if template_name.begins_with("output_"):
		return DEFAULT_NODE_DIRECTORY + "/output.gd"

	for directory_path in get_node_directories():
		var script_path := "%s/%s.gd" % [directory_path, template_name]
		if ResourceLoader.exists(script_path, "Script"):
			return script_path
	return ""

static func get_version() -> int:
	return _version

static func _normalize_directory_path(directory_path: String) -> String:
	var normalized := directory_path.strip_edges().replace("\\", "/")
	while normalized.ends_with("/"):
		normalized = normalized.trim_suffix("/")
	return normalized
