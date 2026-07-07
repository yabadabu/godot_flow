extends RefCounted
class_name GrammarEvaluator

var _parser : GrammarParser = GrammarParser.new()
var _ast : GNBase = null
var _pieces : Dictionary

class EvaluationContext:
	const EPS := 0.0001
	var _pieces : Dictionary
	var available : float
	var iteration : int = 0
	func lengthOf( symbol : String ) -> float:
		if _pieces.has( symbol ):
			return _pieces[ symbol ]
		return 0.0
	func consume( length : float ):
		if not canConsume(length):
			return false
		available -= length
		if available < 0.0:
			print( "Too much space consumed!!")
			available = 0.0
		return true
	func canConsume(length: float) -> bool:
		return length <= available + EPS
		
class GNBase:
	func reset():
		pass
	func requiredLength(ctx: EvaluationContext) -> float:
		return 0.0
	func emitBase(ctx: EvaluationContext) -> float:
		return 0.0
	func grow(ctx: EvaluationContext) -> float:
		return 0.0
	func emitted() -> Array[String]:
		return []
	func dumpStr( level : int, msg : String ):
		var pad = "  "
		while level > 0:
			pad += "  "
			level -= 1
		print( "%s%s" % [pad, msg ])
		
	func dump(level : int):
		print( "Missing GrammarNode.dump!" )

class GNSymbol  extends GNBase:
	var symbol : String
	var _emitted : Array[ String ] = []
	func _init( in_symbol : String ):
		symbol = in_symbol
	func reset():
		_emitted.clear()
	func requiredLength(ctx: EvaluationContext) -> float:
		return ctx.lengthOf(symbol)
	func emitBase(ctx: EvaluationContext) -> float:
		var length := requiredLength(ctx)
		#print( "Symbol.emitBase.%s %f vs %f" % [ symbol, length, ctx.available ])
		if not ctx.consume(length):
			return 0.0
		_emitted.append( symbol )
		return length
	func grow(ctx: EvaluationContext) -> float:
		return 0.0		
	func emitted( ) -> Array[ String ]:
		return _emitted
	func dump(level : int):
		dumpStr( level, "GNSymbol %s" % symbol )

class GNSequence  extends GNBase:
	var children: Array[GNBase]
	
	func _init( in_children : Array[GNBase] ):
		children = in_children
		
	func reset():
		for child in children:
			child.reset()

	func requiredLength(ctx: EvaluationContext) -> float:
		var acc : float = 0
		for child in children:
			acc += child.requiredLength(ctx)
		return acc
		
	func emitBase( ctx : EvaluationContext ) -> float:
		var used := 0.0
		for child in children:
			var consumed_by_child = child.emitBase(ctx)
			#print( "At Sequence. Child consumed %f for a total of %f" % [consumed_by_child, used ] )
			used += consumed_by_child
		return used
		
	func grow(ctx: EvaluationContext) -> float:
		var used := 0.0
		for child in children:
			var consumed_by_child = child.grow(ctx)
			used += consumed_by_child
		return used
			
	func emitted() -> Array[ String ]:
		var all_emitted : Array[ String ] = []
		for child in children:
			all_emitted.append_array( child.emitted() )
		return all_emitted
		
	func dump( level : int ):
		dumpStr( level, "GNSequence.Start (%d children)" % children.size() )
		for child in children:
			child.dump( level + 1 )
		dumpStr( level, "GNSequence.End" )
		
class GNRepeat extends GNBase:
	var child : GNBase
	var min_count : int
	var max_count : int
	var _count: int = 0
	func _init( in_child : GNBase, in_min_count : int, in_max_count : int ):
		child = in_child
		min_count = in_min_count
		max_count = in_max_count
	func reset():
		_count = 0
		child.reset()		
	func requiredLength(ctx: EvaluationContext) -> float:
		return float(min_count) * child.requiredLength(ctx)
	func emitBase(ctx: EvaluationContext) -> float:
		var used := 0.0
		for i in range(min_count):
			var child_length := child.requiredLength(ctx)
			if not ctx.canConsume(child_length):
				return used
			used += child.emitBase(ctx)
			_count += 1
		return used
		
	func grow(ctx: EvaluationContext) -> float:
		if max_count >= 0 and _count >= max_count:
			return 0.0
		var child_length := child.requiredLength(ctx)
		if child_length == 0.0:
			return 0.0
		if not ctx.canConsume(child_length):
			return 0.0
		var used := child.emitBase(ctx)
		if used <= 0.0:
			return 0.0
		_count += 1
		return used		
	func emitted() -> Array[ String ]:
		return child.emitted()
	func dump(level : int):
		dumpStr( level, "GNRepeat %d..%d" % [ min_count, max_count ] )
		child.dump(level + 1)

class GNGroup  extends GNBase:
	var inner : GNBase
	func _init( in_inner : GNBase ):
		inner = in_inner
	func dump(level : int):
		dumpStr( level, "GNGroup Start" )
		inner.dump(level + 1)
		dumpStr( level, "GNGroup Ends" )

class GNFallback  extends GNBase:
	var children: Array[GNBase]
	func _init( in_children : Array[GNBase] ):
		children = in_children
	func dump( level : int ):
		dumpStr( level, "GNFallback.Start (%d options)" % children.size() )
		for child in children:
			child.dump( level + 1 )
		dumpStr( level, "GNFallback.End" )
		
class GNWeighted extends GNBase:
	var children: Array[GNBase]
	var weights: Array[int]
	func _init( in_children : Array[GNBase], in_weights: Array[int] ):
		children = in_children
		weights = in_weights
	func dump( level : int ):
		dumpStr( level, "GNWeighted.Start (%d options)" % children.size() )
		var idx := 0
		for child in children:
			dumpStr( level + 1, "Weight : %d" % weights[idx])
			child.dump( level + 1 )
			idx += 1
		dumpStr( level, "GNWeighted.End" )


func getErrors() -> Array[ String ]:
	return _parser._errors

func parseString( grammar : String ) -> bool:
	_ast = null
	if not _parser.parseString( grammar ):
		return false
	_ast = _parser.ast
	#_ast.dump(0)
	return true

func sample(total_length: float) -> PackedStringArray:
	var ctx := EvaluationContext.new()
	ctx._pieces = _pieces
	ctx.available = total_length

	_ast.reset()
	var required := _ast.requiredLength(ctx)
	if not ctx.canConsume( required ):
		print("Grammar does not fit. Required %f, available %f" % [required, ctx.available])
		return []

	var consumed := _ast.emitBase(ctx)
	print("Base emit. Required %f, available %f -> Consumed: %f" % [required, total_length, consumed ])

	ctx.iteration = 0
	while ctx.iteration < 1024:
		var used := _ast.grow(ctx)
		#print("Growth iteration %d, available %f, used %f" % [ctx.iteration,ctx.available,used])
		if used <= 0.0001:
			break
		ctx.iteration += 1
	return PackedStringArray(_ast.emitted())

func setPieces( new_pieces : Dictionary ):
	_pieces = new_pieces

	
