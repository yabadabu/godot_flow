@tool
extends FlowNodeBase

@export var size : float = 1.0
@export var max_radius : float = 3.0
@export var max_tries : int = 100

func _init():
	meta_node = {
		"title" : "Sample Around",
		"category" : "Spatial",
		"ins" : [{ "label": "In" }],
		"outs" : [{ "label" : "Out" }],
		"tooltip" : "Generates new points randomly around the input positions in the plane XZ",
	}

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = getInput(ctx, 0)
	var in_trs : FlowData.TransformsStream = in_data.getTransformsStream()
	if in_trs == null:
		setError(ctx,  "Input does not provide position, rotation or scale streams" )
		return

	var sample_result : Dictionary = GDStreamUtils.sample_around(
		in_trs.positions,
		in_trs.sizes,
		size,
		max_radius,
		max_tries,
		random_seed)
	if not sample_result.result:
		setError(ctx, "Invalid input parameters for Sample Around")
		return
	var new_positions : PackedVector3Array = sample_result.positions
	var generations : PackedInt32Array = sample_result.generations

	var out_data := FlowData.Data.new()
	out_data.addCommonStreams( 0 )
	var spos := out_data.getVector3Container( FlowData.AttrPosition )
	var srot := out_data.getVector3Container( FlowData.AttrRotation )
	var ssize := out_data.getVector3Container( FlowData.AttrSize )
	spos.append_array( new_positions )
	srot.resize( new_positions.size() )
	srot.fill( Vector3.ZERO )
	ssize.resize( new_positions.size() )
	ssize.fill( Vector3.ONE * size )
	out_data.registerStream( "generation", generations, FlowData.DataType.Int )
	
	setOutput(ctx, 0, out_data )
