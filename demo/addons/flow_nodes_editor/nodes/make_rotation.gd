@tool
extends FlowNodeBase

var inA = { "label": "Z", "multiple_connections" : false }
var inB = { "label": "Y", "multiple_connections" : false }

func _init():
	meta_node = {
		"title" : "Make Rotation",
		"settings" : MakeRotationNodeSettings,
		"category" : "Math",
		"ins" : [ inA ], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Creates a single Rotation value",
		#"trace" : true
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_dataA: FlowData.Data = get_input(0)
	if not in_dataA:
		setError( "Input Z has no data" )
		return
	var sA = in_dataA.findStream( settings.attribute_Z )
	if sA == null:
		setError( "Input Z %s not found" % [settings.attribute_Z])
		return
	var num_elems := in_dataA.size()
	
	var outC := PackedVector3Array()
	outC.resize( num_elems )
	var out_data : FlowData.Data = in_dataA.duplicate()
	
	var inA : PackedVector3Array = sA.container
	var axisY = settings.Y
	for i in num_elems:
		outC[i] = Basis.looking_at(inA[i], axisY ).get_euler() * 180.0 / PI
	
	var err = out_data.registerStream( settings.out_name, outC )
	if err:
		setError( err )
		return
	out_data.markStreamAsRotation( settings.out_name )
	set_output( 0, out_data )
