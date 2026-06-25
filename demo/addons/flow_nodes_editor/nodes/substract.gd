@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Substract",
		"settings" : SubstractSettings,
		"category" : "Spatial",
		"ins" : [{ "label": "In A" }, { "label": "In B" }], 
		"outs" : [{ "label" : "Out" }],
		"hide_inputs" : true,
		"tooltip" : "Applies the boolean logic 'substract', where the points of A that overlap points any of the connected points in B are removed.\nThe same node can be changed to return only the points A intersecting the points of B",
	}

func getTitle() -> String:
	return "Substract" if settings.operation == SubstractSettings.eOperation.A_Minus_B else "Intersection"

func getMergedB(ctx : FlowData.EvaluationContext ) -> FlowData.Data :
	var all_Bs : FlowData.Data
	var args_b = []
	for bulk_index in range( 256 ):
		var b = _getInputForBulkInContext( ctx, bulk_index, 1)
		if not b:
			break
		args_b.append( b )
	if args_b.size() == 1:
		all_Bs = args_b[0]
	else:
		all_Bs = FlowData.Data.new()
		var container_pos = all_Bs.newContainerOfType( FlowData.DataType.Vector )
		var container_szs = all_Bs.newContainerOfType( FlowData.DataType.Vector )
		all_Bs.registerStream( FlowData.AttrPosition, container_pos, FlowData.DataType.Vector )
		all_Bs.registerStream( FlowData.AttrSize, container_szs, FlowData.DataType.Vector )
		for b : FlowData.Data in args_b:
			var b_pos = b.getVector3Container( FlowData.AttrPosition )
			var b_szs = b.getVector3Container( FlowData.AttrSize )
			container_pos.append_array( b_pos )
			container_szs.append_array( b_szs )
	return all_Bs
	
func run( ctx : FlowData.EvaluationContext ):
	print( "substract starts. num_connected_bulks= %d" % num_connected_bulks)
	var all_Bs := getMergedB( ctx )
	for bulk_index in range( num_connected_bulks ):
		inputs = []
		var input =  _getInputForBulkInContext( ctx, bulk_index, 0 )
		print( "Executing bulk index %d" % bulk_index)
		inputs.append(input)
		inputs.append(all_Bs)
		execute( ctx )
	
func execute( _ctx : FlowData.EvaluationContext ):
	var in_dataA: FlowData.Data = get_input(0)
	var in_dataB : FlowData.Data = get_input(1)
	
	if in_dataA == null:
		setError( "Input A not found")
		return
		
	if in_dataB == null:
		in_dataB = FlowData.Data.new()

	var tA := GDRTree.new()
	var posA = in_dataA.getVector3Container( FlowData.AttrPosition )
	var szA = in_dataA.getVector3Container( FlowData.AttrSize )
	tA.add( posA, szA )
	
	var posB = in_dataB.getVector3Container( FlowData.AttrPosition )
	var szB = in_dataB.getVector3Container( FlowData.AttrSize )
	
	var inverse_result = settings.operation == SubstractSettings.eOperation.A_Intersection_B
	var result = tA.overlaps( posB, szB, inverse_result )
	
	var out_data : FlowData.Data = in_dataA.filter( result.idxs_overlapped )
		
	set_output( 0, out_data )
