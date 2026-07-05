@tool
extends BaseTest

func test_grammar_basic():
	var grammar = "A,[B,C]*,A"
	var tokenizer = GrammarTokenizer.new()
	if tokenizer.tokenize( grammar ):
		for token in tokenizer.tokens:
			print( token )
