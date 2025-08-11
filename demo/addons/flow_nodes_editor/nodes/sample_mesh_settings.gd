@tool
class_name SampleMeshNodeSettings
extends NodeSettings

@export_group("Sample Mesh")

enum eMode {
	UseDensity,
	UseNumSamples,
	OnePerVertex,
	FaceCenters,
}

@export var mode : eMode = eMode.UseDensity
@export var density : float = 0.5
@export var num_samples : int = 100
@export var point_size : float = 1.0

func _init():
	super._init()
	resource_name = "Sample Mesh Settings"
