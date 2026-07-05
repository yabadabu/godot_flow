extends RefCounted
class_name GrammarTokenizer

enum eToken {
	EOF,
	Symbol,
	Number,
	Comma,
	Plus,
	Star,
	Colon,
	LeftBracket,
	RightBracket,
	LeftAngle,
	RightAngle,
	LeftBrace,
	RightBrace,
}

class Token:
	var token : eToken = eToken.EOF
	var value : String
	func _init( in_token : eToken, in_value : String ):
		token = in_token
		value = in_value
	func _to_string() -> String:
		return "Token(%s, value=%s)" % [ eToken.keys()[ token ], value ]

var tokens : Array[ Token ]
var _errors : Array[ String ]
var _source : String
var _position : int
var _source_len : int

func isAtEnd() -> bool:
	return _position >= _source_len
	
func peek() -> String:
	if isAtEnd():
		return ""
	return _source.substr(_position, 1)
	
func advance() -> String:
	var c := _source.substr(_position, 1)
	_position += 1
	return c		
	
func skipWhitespace():
	while not isAtEnd():
		var c := peek()
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			advance()
		else:
			return

func isDigit(c: String) -> bool:
	if c.is_empty():
		return false
	var code := c.unicode_at(0)
	return code >= 48 and code <= 57

func isAlpha(c: String) -> bool:
	if c.is_empty():
		return false
	var code := c.unicode_at(0)
	return (
		(code >= 65 and code <= 90) # A-Z
		or (code >= 97 and code <= 122) # a-z
	)

func isSymbolStart(c: String) -> bool:
	return isAlpha(c) or c == "_"

func isSymbolChar(c: String) -> bool:
	return isAlpha(c) or c == "_" or c == "-"

func addToken( token : eToken, value : String ):
	tokens.append(Token.new(token, value))

func scanNumber(start: int) -> void:
	while not isAtEnd() and isDigit(peek()):
		advance()
	var text := _source.substr(start, _position - start)
	var value := int(text)
	addToken(eToken.Number, text)

func scanSymbol(start: int) -> void:
	while not isAtEnd() and isSymbolChar(peek()):
		advance()
	var text := _source.substr(start, _position - start)
	addToken(eToken.Symbol, text)

func scanToken() -> bool:
	skipWhitespace()
	if isAtEnd():
		return false
	var start := _position
	var c := advance()
	match c:
		",":
			addToken(eToken.Comma, ",")
		":":
			addToken(eToken.Colon, ":")
		"+":
			addToken(eToken.Plus, "+")
		"*":
			addToken(eToken.Star, "*")
		"[":
			addToken(eToken.LeftBracket, "[")
		"]":
			addToken(eToken.RightBracket, "]")
		"<":
			addToken(eToken.LeftAngle, "<")
		">":
			addToken(eToken.RightAngle, ">")
		"{":
			addToken(eToken.LeftBrace, "{")
		"}":
			addToken(eToken.RightBrace, "}")
		_:
			if isDigit(c):
				scanNumber(start)
			elif isSymbolStart(c):
				scanSymbol(start)
			else:
				_errors.append("Unexpected character '%s' at position %d." % [c, start])
	return true
	
func tokenize( in_grammar : String ) -> bool:
	tokens.clear()
	_errors.clear()
	_source = in_grammar
	_source_len = in_grammar.length()
	_position = 0
	while not isAtEnd():
		scanToken()
	addToken(eToken.EOF, "")
	return true
	
	
