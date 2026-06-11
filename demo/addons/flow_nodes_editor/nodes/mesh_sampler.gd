@tool
extends "res://addons/flow_nodes_editor/nodes/sample_mesh.gd"

func _init():
	meta_node = {
		"title" : "Mesh Sampler",
		"settings" : SampleMeshNodeSettings,
		"ins" : [{ "label": "Meshes", "data_type": FlowData.DataType.NodeMesh }],
		"outs" : [{ "label" : "Out" }],
		"auto_register" : false,
		"aliases" : ["Mesh Sampler"],
		"category" : "Sampler",
		"tooltip" : "Samples points on a mesh surface. Alias of Sample Mesh.",
	}
