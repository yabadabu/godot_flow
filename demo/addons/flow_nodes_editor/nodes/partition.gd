@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Partition",
		"settings" : PartitionNodeSettings,
		"ins" : [{"label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Partition data",
	}
	
func getTitle() -> String:
	return "Partition %s" % [ settings.attribute_name ]

func execute( ctx : FlowData.EvaluationContext ):
	var in_data = get_input( 0 )
	if in_data == null:
		setError( "partition.Missing input 0" )
		return
	
	var stream = in_data.findStream( settings.attribute_name )
	if stream == null:
		setError( "Attribute %s not found in input" % settings.attribute_name )
		return
	var container = stream.container
	
	if settings.trace:
		print( "Partitioning by attribute %s" % container )
	
	# Do a quick and dirty partition by string representation of the value
	# Preserves the indices
	var parts : Dictionary = {} 
	for idx in range( container.size() ):
		var val = "%s" % container[ idx ]
		if not parts.has( val ):
			parts[ val ] = PackedInt32Array()
		parts[ val ].append( idx )
		
	if settings.trace:
		print( parts )
		
	var partition_id := 0
	for key in parts.keys():
		var out_data : FlowData.Data = in_data.filter( parts[key] )
		if settings.out_partition_attribute:
			var p = newStream( out_data.size(), settings.out_partition_attribute, partition_id, FlowData.DataType.Int )
			out_data.registerStream( p.name, p.container )
		set_output( 0, out_data )
		partition_id += 1
	
