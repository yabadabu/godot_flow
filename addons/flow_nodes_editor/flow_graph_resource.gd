@tool
extends Resource
class_name FlowGraphResource
@export_category("Flow Graph Resource")

@export var nodes: Array[Dictionary] = []
@export var conns : Array[Dictionary] = []
@export var view_zoom : float = 1.0
@export var view_offset : Vector2 = Vector2(0,0)
@export var new_name_counter : int = 0

#@export var conn_from: Array[String] = []
#@export var conn_from_port: Array[int] = []
#@export var conn_to: Array[String] = []
#@export var conn_to_port: Array[int] = []
#
#func get_property_list() -> Array[Dictionary]:
	#return [
		#{
			#"name": "nodes",
			#"type": TYPE_ARRAY,
			#"usage": PROPERTY_USAGE_STORAGE, # Save but don't show in inspector
			#"hint": PROPERTY_HINT_ARRAY_TYPE,
			#"hint_string": "NodeSettings"
		#},
		#{
			#"name": "conn_from",
			#"type": TYPE_ARRAY,
			#"usage": PROPERTY_USAGE_STORAGE,
			#"hint": PROPERTY_HINT_ARRAY_TYPE,
			#"hint_string": "String"
		#},
		#{
			#"name": "conn_from_port",
			#"type": TYPE_ARRAY,
			#"usage": PROPERTY_USAGE_STORAGE,
			#"hint": PROPERTY_HINT_ARRAY_TYPE,
			#"hint_string": "int"
		#},
		#{
			#"name": "conn_to",
			#"type": TYPE_ARRAY,
			#"usage": PROPERTY_USAGE_STORAGE,
			#"hint": PROPERTY_HINT_ARRAY_TYPE,
			#"hint_string": "String"
		#},
		#{
			#"name": "conn_to_port",
			#"type": TYPE_ARRAY,
			#"usage": PROPERTY_USAGE_STORAGE,
			#"hint": PROPERTY_HINT_ARRAY_TYPE,
			#"hint_string": "int"
		#}
	#]
