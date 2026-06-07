@tool
extends FlowNodeBase

var _connected_graph: FlowGraphResource = null

func _init():
	meta_node = {
		"title" : "Subgraph",
		"settings" : SubgraphNodeSettings,
		"ins" : [],
		"outs" : [],
		"is_final" : true,
		"tooltip" : "Evaluates a nested graph inside this node",
	}

func getMeta() -> Dictionary:
	var ins = []
	var outs = []
	if settings and settings.graph:
		for param in settings.graph.in_params:
			if param:
				ins.append({
					"label": param.name,
					"data_type": param.getDataType()
				})
		#if "out_params" in settings.graph and settings.graph.out_params.size() > 0:
			#for param in settings.graph.out_params:
				#if param:
					#outs.append({
						#"label": param.name,
						#"data_type": param.data_type
					#})
		#elif settings.graph.data and settings.graph.data.has("nodes"):
			#for n_data in settings.graph.data["nodes"]:
				#if n_data.get("template") == "output":
					#var node_settings = n_data.get("settings", {})
					#var out_name = node_settings.get("name", "out_val")
					#var out_type = node_settings.get("data_type", FlowData.DataType.Float)
					#outs.append({
						#"label": out_name,
						#"data_type": out_type
					#})
	meta_node.ins = ins
	meta_node.outs = outs
	return meta_node
	
func execute( ctx : FlowData.EvaluationContext ):
	if not settings.graph:
		setError("No graph assigned to Subgraph node '%s'" % getTitle())
		return
	
	var ins = meta_node.ins
	print( "Subgraph, required ins are ", ins)
	
	var subctx := FlowData.EvaluationContext.new()
	
	print( settings.graph.data )
	FlowNodeIO.create_nodes_from_dict( settings.graph.data, null, Vector2(0,0) )
	
	#subctx.owner = ctx.owner
	subctx.graph = settings.graph
	var nodes = subctx.getAllNodes()
	print( nodes )
