extends RefCounted
class_name GrammarParser

var _tokens: Array = []
var _current: int = 0
var _errors: Array[String] = []
var ast : GrammarEvaluator.GNBase

func errorAtCurrent(message: String) -> void:
	errorAtToken(peek(), message)

func errorAtPrevious(message: String) -> void:
	errorAtToken(previous(), message)

func errorAtToken(token, message: String) -> void:
	_errors.append("%s At position %s." % [message, token])

func peek():
	return _tokens[_current]
	
func previous():
	return _tokens[_current - 1]
	
func isAtEnd() -> bool:
	return peek().token == GrammarTokenizer.eToken.EOF

func check(type: GrammarTokenizer.eToken) -> bool:
	if _tokens.is_empty():
		return false
	return peek().token == type

func checkAny(types: Array[GrammarTokenizer.eToken]) -> bool:
	for type in types:
		if check(type):
			return true
	return false

func advance():
	if not isAtEnd():
		_current += 1
	return previous()
	
func consume(type: GrammarTokenizer.eToken, message: String):
	if check(type):
		return advance()
	errorAtCurrent(message)
	return null
		
func matches(type: GrammarTokenizer.eToken) -> bool:
	if not check(type):
		return false
	advance()
	return true
	
func parsePrimary() -> GrammarEvaluator.GNBase:
	
	if matches(GrammarTokenizer.eToken.Symbol):
		var token = previous()
		return GrammarEvaluator.GNSymbol.new(StringName(token.value))

	if matches(GrammarTokenizer.eToken.LeftBracket):
		var start_token = previous()
		var inner := parseSequence([GrammarTokenizer.eToken.RightBracket])
		consume(GrammarTokenizer.eToken.RightBracket, "Expected ']' after group.")
		return GrammarEvaluator.GNGroup.new(inner)

	if matches(GrammarTokenizer.eToken.LeftAngle):
		return parseFallback()

	if matches(GrammarTokenizer.eToken.LeftBrace):
		return parseWeightedChoice()

	errorAtCurrent("Expected symbol, group '[...]', fallback '<...>', or weighted choice '{...}'.")
	advance()
	return null

func parseWeightedChoice() -> GrammarEvaluator.GNBase:
	var start_token = previous()
	var options: Array[ GrammarEvaluator.GNBase ]= []
	var weights: Array[ int ]= []

	while not isAtEnd() and not check(GrammarTokenizer.eToken.RightBrace):
		var expr := parseTerm()
		if expr == null:
			break
		var weight := 1
		if matches(GrammarTokenizer.eToken.Colon):
			var number_token = consume(GrammarTokenizer.eToken.Number,"Expected number after ':' in weighted choice.")
			if number_token != null:
				weight = max(1, int(number_token.value))

		options.append( expr )
		weights.append( weight )

		if matches(GrammarTokenizer.eToken.Comma):
			if check(GrammarTokenizer.eToken.RightBrace):
				errorAtPrevious("Trailing comma in weighted choice.")
				break
			continue
		break

	consume(GrammarTokenizer.eToken.RightBrace,"Expected '}' after weighted choice.")
	if options.is_empty():
		errorAtToken(start_token, "Weighted choice must contain at least one option.")
	return GrammarEvaluator.GNWeighted.new( options, weights )

func parseFallback() -> GrammarEvaluator.GNBase:
	var start_token = previous()
	var options: Array[ GrammarEvaluator.GNBase ]= []

	while not isAtEnd() and not check(GrammarTokenizer.eToken.RightAngle):
		var option := parseTerm()
		if option == null:
			break
		options.append(option)
		if matches(GrammarTokenizer.eToken.Comma):
			if check(GrammarTokenizer.eToken.RightAngle):
				errorAtPrevious("Trailing comma in fallback.")
				break
			continue
		break
	consume(GrammarTokenizer.eToken.RightAngle,"Expected '>' after fallback.")
	if options.is_empty():
		errorAtToken(start_token, "Fallback must contain at least one option.")
	return GrammarEvaluator.GNFallback.new( options )

func parseTerm() -> GrammarEvaluator.GNBase:
	var node := parsePrimary()
	if node == null:
		return null

	if matches(GrammarTokenizer.eToken.Plus):
		return GrammarEvaluator.GNRepeat.new(node, 1, -1)

	if matches(GrammarTokenizer.eToken.Star):
		return GrammarEvaluator.GNRepeat.new(node, 0, -1)

	if matches(GrammarTokenizer.eToken.Number):
		var token = previous()
		var count := int(token.value)
		if count < 0:
			errorAtPrevious("Repeat count cannot be negative.")
			count = 0
		return GrammarEvaluator.GNRepeat.new(node, count, count)
		
	return node
	
func parseSequence(stop_types: Array[GrammarTokenizer.eToken]) -> GrammarEvaluator.GNBase:
	var items: Array[ GrammarEvaluator.GNBase ] = []

	while not isAtEnd() and not checkAny(stop_types):
		var item := parseTerm()
		if item == null:
			print( "end of sequence")
			break
		items.append(item)
		if matches(GrammarTokenizer.eToken.Comma):
			if checkAny(stop_types):
				errorAtPrevious("Trailing comma before closing token.")
				break
			continue

		if not checkAny(stop_types) and not isAtEnd():
			errorAtCurrent("Expected ',' between grammar items.")
			break
	return GrammarEvaluator.GNSequence.new( items )

func parseString( grammar : String ) -> bool:
	_errors.clear()
	var tokenizer = GrammarTokenizer.new()
	if not tokenizer.tokenize( grammar ):
		_errors.append("Error tokenizing grammar %s" % grammar )
		return false
	_tokens = tokenizer.tokens
	_current = 0
	ast = parseSequence([GrammarTokenizer.eToken.EOF])
	consume(
		GrammarTokenizer.eToken.EOF,
		"Expected end of grammar."
	)
	return _errors.size() == 0
