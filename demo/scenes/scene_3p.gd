@tool
extends Node3D

@export var head_rotation : float :
	set( value ):
		_head_rotation = value
		var child = $MeshInstance3D/MeshInstance3D2
		if child:
			child.rotation_degrees = Vector3(0,value,0)
	get:
		return _head_rotation
		
var _head_rotation: float = 0.0  # backing variable
