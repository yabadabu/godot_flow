@tool
class_name SamplePointsNodeSettings
extends NodeSettings

@export_group("Sample Points")

enum eDistribution {
	UniformGrid,
	QuasiRandom2D,
	QuasiRandom3D,
}

@export var distribution : eDistribution = eDistribution.QuasiRandom2D:
	set(value):
		if distribution != value:
			distribution = value
			# This triggers the refresh of the property list in the property editor
			notify_property_list_changed()
			
# Uniform sampling
@export var sampling_distance : float = 0.2
@export var max_x : int = 32
@export var max_y : int = 32
@export var max_z : int = 32
@export var new_size_factor : float = 1.0

# Non-Uniform sampling
@export var phase : float = 0.0
@export var size : float = 1.0
@export var out_group_id : String
@export var groups : Array[int] = [ 32 ]

func _init():
	super._init()
	resource_name = "Sample Points Settings"

func isUniformGridParam( name : String ) -> bool:
	return name.begins_with( "max_" ) or name == "sampling_distance" or name == "new_size_factor"

func isQuasiRandomParam( name : String ) -> bool:
	return name == "phase" or name == "size" or name == "out_group_id" or name == "groups"

# This control if the param is visible in the property inspector
func exposeParam( name : String ) -> bool:
	# This must return true except for the specific parameters that depend on the enum
	if distribution == eDistribution.UniformGrid:
		return not isQuasiRandomParam( name )
	return not isUniformGridParam( name )
