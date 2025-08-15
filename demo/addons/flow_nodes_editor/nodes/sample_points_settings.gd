@tool
class_name SamplePointsNodeSettings
extends NodeSettings

@export_group("Sample Points")

enum eDistribution {
	UniformGrid,
	QuasiRandom2D,
	QuasiRandom3D,
}

@export var distribution : eDistribution = eDistribution.QuasiRandom2D

# Uniform sampling
@export var sampling_distance : float = 0.2
@export var max_x : int = 32
@export var max_y : int = 32
@export var max_z : int = 32
@export var new_size_factor : float = 1.0

# Non-Uniform sampling
@export var phase : float = 0.0
@export var groups : Array[int] = [ 32 ]
@export var out_group_id : String

func _init():
	super._init()
	resource_name = "Sample Points Settings"
