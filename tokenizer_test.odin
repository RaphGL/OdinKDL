package kdl

import "core:strings"
import "core:testing"

@(test)
invalid_token :: proc(t: ^testing.T) {
	invalid := []string{"inf", "nan", "true", "false", "null"}

	valid := map[string]Token_Kind {
		"#inf"   = .Inf,
		"#-inf"  = .NegInf,
		"#nan"   = .NaN,
		"#true"  = .True,
		"#false" = .False,
		"#null"  = .Null,
	}
	defer delete(valid)

	for i in invalid {
		tokenizer := make_tokenizer(i)
		token, _ := get_token(&tokenizer)
		testing.expect_value(t, token.kind, Token_Kind.Invalid)
	}

	for k, v in valid {
		tokenizer := make_tokenizer(k)
		token, _ := get_token(&tokenizer)
		testing.expect_value(t, v, token.kind)
	}
}

@(test)
quoted_strings :: proc(t: ^testing.T) {
	input := `
quoted_str "hello world"	
raw_quoted_str #"hello world"#

multiline_str """
hello world
"""
raw_multiline_str ##"""
hello world
"""##
`


	tokenizer := make_tokenizer(input)

	line_is :: proc(t: ^testing.T, tokenizer: ^Tokenizer, token_type: Token_Kind) {
		get_token(tokenizer)
		tok, _ := get_token(tokenizer)
		testing.expect_value(t, tok.kind, token_type)
		testing.expect(t, strings.trim_space(tok.text) == "hello world")
	}

	is_newline :: proc(t: ^testing.T, tokenizer: ^Tokenizer) {
		tok, _ := get_token(tokenizer)
		testing.expect_value(t, tok.kind, Token_Kind.Newline)
	}

	is_newline(t, &tokenizer)
	line_is(t, &tokenizer, .Quoted_String)
	is_newline(t, &tokenizer)
	line_is(t, &tokenizer, .Raw_Quoted_String)
	is_newline(t, &tokenizer)
	is_newline(t, &tokenizer)
	line_is(t, &tokenizer, .Multiline_String)
	is_newline(t, &tokenizer)
	line_is(t, &tokenizer, .Raw_Multiline_String)
}

@(test)
slashdash :: proc(t: ^testing.T) {
	tokenizer := make_tokenizer("/- some command")
	tok, _ := get_token(&tokenizer)
	testing.expect_value(t, tok.kind, Token_Kind.Slash_Dash)
}

