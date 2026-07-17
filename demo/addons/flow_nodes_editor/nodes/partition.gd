@tool
extends FlowNodeBase

@export var attribute_name : String = "@last"
@export var out_partition_attribute : String

func _init():
	meta_node = {
		"title" : "Partition",
		"category" : "Metadata",
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Partition data based on the different values an attribute."
	}
	
func getTitle() -> String:
	return "Partition %s" % [ attribute_name ]

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input( 0 )
	if in_data == null:
		setError( "partition.Missing input 0" )
		return
		
	# Special case, when partition by a Index, which is not a registered official stream name,
	# but means we want each data to send as a individual bulk
	if attribute_name.to_lower() == "index":
		var ids = PackedInt32Array()
		ids.resize(1)
		for partition_id in range(in_data.size()):
			ids[0] = partition_id
			var out_data : FlowData.Data = in_data.filter( ids )
			if out_partition_attribute:
				var p = newStream( out_data.size(), out_partition_attribute, partition_id, FlowData.DataType.Int )
				out_data.registerStream( p.name, p.container )
			set_output( 0, out_data )
			
	else:
		var stream = in_data.findStream( attribute_name )
		if stream == null:
			setError( "Attribute %s not found in input" % attribute_name )
			return
		var container = stream.container
		
		if trace:
			print( "Partitioning by attribute %s" % container )
		
		# Do a quick and dirty partition by string representation of the value
		# Preserves the indices
		var parts : Dictionary = {} 
		for idx in range( container.size() ):
			var val = "%s" % container[ idx ]
			if not parts.has( val ):
				parts[ val ] = PackedInt32Array()
			parts[ val ].append( idx )
			
		if trace:
			print( parts )
			
		var partition_id := 0
		for key in parts.keys():
			var out_data : FlowData.Data = in_data.filter( parts[key] )
			if out_partition_attribute:
				var p = newStream( out_data.size(), out_partition_attribute, partition_id, FlowData.DataType.Int )
				out_data.registerStream( p.name, p.container )
			set_output( 0, out_data )
			partition_id += 1
	
