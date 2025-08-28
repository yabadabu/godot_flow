@tool
extends FlowNodeBase

func _init():
	meta_node = {
		"title" : "Expression",
		"settings" : ExpressionNodeSettings,
		"ins" : [{ "label": "In" }], 
		"outs" : [{ "label" : "Out" }],
		"tooltip" : 
			"Evaluates an expression and stores the result in the output stream\n" + 
			" * When expose_arrays is set, the values of the point set are exposed as arrays\n" +
			"   and position[Index] (Index with capital I) must be used to reference the current point\n" + 
			"   and position[Index-1] references the previous position\n" + 
			" * Size for the total number of points\n" +  
			" * Customize the Node Label if the expression is too long\n"
			,
	}
	
var _container
var _expression : Expression
var _in_size : int
var _out_data : FlowData.Data
	
func shorten(text: String) -> String:
	return text.substr(0, 32) + "..." if text.length() > 32 else text
	
# Expose the local parameters of the expressions as parameters of the flow node 
func getExposedParams():
	var params = []
	for arg_name in settings.args:
		var prop_gd_type = typeof( settings.args[ arg_name ] )
		var data = {
			"name" : arg_name,
			"label" : editorDisplayName( arg_name ),
			"type" : prop_gd_type,
			"data_type" : getFlowDataTypeFromGdScriptType( prop_gd_type ),
			"is_parameter" : true,
			"port" : -1,
		}	
		params.append( data )	
		#print( arg_name, settings.args[ arg_name ], data )
	return params
	
func getTitle() -> String:
	size = get_combined_minimum_size()
	if settings.title != "Expression":
		return settings.title
	if !settings.expression:
		return "Expression"
	return shorten( settings.expression )

func evaluateAndSaveResult( idx : int, values : Array ):

	var result = _expression.execute(values)
	if not _expression.has_execute_failed():
		if _container == null:
			var flow_data_type = getFlowDataTypeFromGdScriptType( typeof( result ))
			if flow_data_type != FlowData.DataType.Invalid:
				var stream = newStream( _in_size, settings.out_name, result, flow_data_type )
				if settings.trace:
					print( "Created container of type %d %s" % [ flow_data_type, stream ])
				_container = stream.container
			else:
				setError( "Failed to identify type of expression result at index %d" % idx )
				return false
		if settings.trace:
			print( "Added[%d] = %s" % [ idx, result ])
		_container[idx] = result
		return true
	setError( _expression.get_error_text() )	
	return false

func execute( ctx : FlowData.EvaluationContext ):
	var in_data : FlowData.Data = get_input(0)
	_out_data = in_data.duplicate()
	
	_in_size = in_data.size()
	if _in_size == 0:
		set_output( 0, _out_data )
		return
	
	_expression = Expression.new()
	_container = null
	
	var names = ["Index", "Size"]
	names.append_array( settings.args.keys() )
	names.append_array( in_data.streams.keys() )
	var error := _expression.parse(settings.expression, names)
	if error != OK:
		setError("Failed parsing expression: %s" % _expression.get_error_text())
		return
	var values = [0, _in_size]
	for arg_name in settings.args:
		var def_value = settings.args[ arg_name ]
		var arg_value = getSettingValue( ctx, arg_name, def_value )
		#print( "%s is %s vs %s" % [ arg_name, def_value, arg_value ] )
		if arg_value != null:
			values.append( arg_value )
		else:
			values.append( def_value )
	
	var container = null
	if settings.expose_arrays:
		var containers = in_data.streams.values().map( func( s ): return s.container )
		values.append_array( containers )
			
		for idx in range( _in_size ):
			values[0] = idx
			if not evaluateAndSaveResult( idx, values ):
				break
	else:
		var k0 = values.size()
		var containers := in_data.streams.values().map( func(s): return s.container )
		var num_containers = containers.size()
		values.append_array( containers.map( func( c ): return c[0] ) )
		for idx in range( _in_size ):
			values[0] = idx
			for k in range( containers.size() ):
				values[ k0 + k ] = containers[k][ idx ]
			#if settings.trace:
				#print( "  For %d : %s" % [ idx, values ])
			if not evaluateAndSaveResult( idx, values ):
				break
		if settings.trace:
			print( "Registering stream %s with %s" % [ settings.out_name, _container ])
		var err_msg = _out_data.registerStream( settings.out_name, _container )
		if err_msg:
			setError( err_msg )
			
	set_output( 0, _out_data )
