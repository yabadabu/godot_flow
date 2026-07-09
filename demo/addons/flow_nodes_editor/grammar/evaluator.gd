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
	var rng : RandomNumberGenerator
	func lengthOf( symbol : StringName ) -> float:
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
	func emitBase(ctx: EvaluationContext) -> Array[StringName]:
		return []
	func grow(ctx: EvaluationContext) -> Array[StringName]:
		return []
	func emitted() -> Array[StringName]:
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
	var symbol : StringName
	var _emitted : Array[ StringName ] = []
	func _init( in_symbol : StringName ):
		symbol = in_symbol
	func reset():
		_emitted.clear()
	func requiredLength(ctx: EvaluationContext) -> float:
		return ctx.lengthOf(symbol)
	func emitBase(ctx: EvaluationContext) -> Array[StringName]:
		var length := requiredLength(ctx)
		#print( "Symbol.emitBase.%s %f vs %f	" % [ symbol, length, ctx.available ])
		if not ctx.consume(length):
			return []
		_emitted.append( symbol )
		return [symbol]
	func grow(ctx: EvaluationContext) -> Array[StringName]:
		return []
	func emitted( ) -> Array[ StringName ]:
		return _emitted
	func dump(level : int):
		dumpStr( level, "GNSymbol %s" % symbol )

class GNSequence  extends GNBase:
	var children: Array[GNBase]
	var _emitted : Array[StringName] = []
	
	func _init( in_children : Array[GNBase] ):
		children = in_children
		
	func reset():
		_emitted.clear()
		for child in children:
			child.reset()

	func requiredLength(ctx: EvaluationContext) -> float:
		var acc : float = 0
		for child in children:
			acc += child.requiredLength(ctx)
		return acc
		
	func emitBase( ctx : EvaluationContext ) -> Array[StringName]:
		var emitted_now: Array[StringName] = []
		for child in children:
			var child_emitted := child.emitBase(ctx)
			emitted_now.append_array(child_emitted)
		_emitted.append_array(emitted_now)
		return emitted_now
		
	func grow(ctx: EvaluationContext) -> Array[StringName]:
		var emitted_now: Array[StringName] = []
		for child in children:
			var child_emitted := child.grow(ctx)
			emitted_now.append_array(child_emitted)
		if not emitted_now.is_empty():
			_emitted.clear()
			for child in children:
				_emitted.append_array(child.emitted())
		return emitted_now
			
	func emitted() -> Array[ StringName ]:
		return _emitted
		
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
	var _emitted : Array[StringName] = []
	func _init( in_child : GNBase, in_min_count : int, in_max_count : int ):
		child = in_child
		min_count = in_min_count
		max_count = in_max_count
	func reset():
		_count = 0
		_emitted.clear()
		child.reset()
	func requiredLength(ctx: EvaluationContext) -> float:
		return float(min_count) * child.requiredLength(ctx)
	func emitBase(ctx: EvaluationContext) -> Array[StringName]:
		var emitted_now: Array[StringName] = []
		for i in range(min_count):
			var child_length := child.requiredLength(ctx)
			if not ctx.canConsume(child_length):
				return emitted_now
			var child_emitted := child.emitBase(ctx)
			emitted_now.append_array(child_emitted)
			_emitted.append_array(child_emitted)
			_count += 1
		return emitted_now
		
	func grow(ctx: EvaluationContext) -> Array[StringName]:
		if max_count >= 0 and _count >= max_count:
			return []
		var child_length := child.requiredLength(ctx)
		if child_length == 0.0:
			return []
		if not ctx.canConsume(child_length):
			return []
		var emitted_now := child.emitBase(ctx)
		if emitted_now.is_empty():
			return []
		_count += 1
		_emitted.append_array(emitted_now)
		return emitted_now
	func emitted() -> Array[ StringName ]:
		return _emitted
	func dump(level : int):
		dumpStr( level, "GNRepeat %d..%d" % [ min_count, max_count ] )
		child.dump(level + 1)

class GNGroup  extends GNBase:
	var inner : GNBase
	var _emitted : Array[StringName] = []
	func _init( in_inner : GNBase ):
		inner = in_inner
	func reset():
		_emitted.clear()
		inner.reset()
	func requiredLength(ctx: EvaluationContext) -> float:
		return inner.requiredLength(ctx)
	func emitBase(ctx: EvaluationContext) -> Array[StringName]:
		var emitted_now := inner.emitBase(ctx)
		_emitted.append_array(emitted_now)
		return emitted_now
	func grow(ctx: EvaluationContext) -> Array[StringName]:
		var emitted_now := inner.grow(ctx)
		_emitted.append_array(emitted_now)
		return emitted_now
	func emitted() -> Array[ StringName ]:
		return _emitted
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
	var _emitted : Array[StringName] = []
	var _selected_child_idx := -1
	func _init( in_children : Array[GNBase], in_weights: Array[int] ):
		children = in_children
		weights = in_weights
	func reset():
		_emitted.clear()
		_selected_child_idx = -1
		for child in children:
			child.reset()
	func requiredLength(ctx: EvaluationContext) -> float:
		var best := INF
		for child in children:
			var child_length := child.requiredLength(ctx)
			if child_length > 0.0:
				best = min(best, child_length)
		if best == INF:
			return 0.0
		return best
	func emitBase(ctx: EvaluationContext) -> Array[StringName]:
		var selected_idx := _pickCandidate(ctx)
		if selected_idx < 0:
			return []
		_selected_child_idx = selected_idx
		var emitted_now := children[selected_idx].emitBase(ctx)
		_emitted.append_array(emitted_now)
		return emitted_now
	func grow(ctx: EvaluationContext) -> Array[StringName]:
		if _selected_child_idx < 0:
			return []
		var emitted_now := children[_selected_child_idx].grow(ctx)
		_emitted.append_array(emitted_now)
		return emitted_now
	func emitted() -> Array[StringName]:
		return _emitted
	func _pickCandidate(ctx: EvaluationContext) -> int:
		var candidate_indices : Array[int] = []
		var total_weight := 0
		for idx in range(children.size()):
			var child_length := children[idx].requiredLength(ctx)
			if child_length <= 0.0:
				continue
			if not ctx.canConsume(child_length):
				continue
			candidate_indices.append(idx)
			total_weight += weights[idx]
		if candidate_indices.is_empty() or total_weight <= 0:
			return -1
		var roll := ctx.rng.randi_range(1, total_weight)
		var accumulated_weight := 0
		for idx in candidate_indices:
			accumulated_weight += weights[idx]
			if roll <= accumulated_weight:
				return idx
		return candidate_indices.back()
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

func sample(total_length: float, rng : RandomNumberGenerator) -> Array[StringName]:
	var ctx := EvaluationContext.new()
	ctx._pieces = _pieces
	ctx.available = total_length
	ctx.rng = rng
	if ctx.rng == null:
		ctx.rng = RandomNumberGenerator.new()

	_ast.reset()
	var required := _ast.requiredLength(ctx)
	if not ctx.canConsume( required ):
		print("Grammar does not fit. Required %f, available %f" % [required, ctx.available])
		return []

	_ast.emitBase(ctx)
	#print("Base emit. Required %f, available %f -> Consumed: %f" % [required, total_length, consumed ])

	ctx.iteration = 0
	while ctx.iteration < 1024:
		var emitted_now := _ast.grow(ctx)
		#print("Growth iteration %d, available %f, used %f" % [ctx.iteration,ctx.available,used])
		if emitted_now.is_empty():
			break
		ctx.iteration += 1
	return _ast.emitted()

func setPieces( new_pieces : Dictionary ):
	_pieces = new_pieces

	
