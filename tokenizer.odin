package kdl

import "core:unicode/utf8"
import "core:unicode"

Token_Kind :: enum {
	Invalid,
	EOF,

	Null,
	True, False,
	Inf,
	NaN,
	Ident,
	Newline,
	Int,
	Float,
	Open_Paren, Close_Paren,
	Open_Brace, Close_Brace,
	Hash,
	Minus,
	Quote,
	Equal,
}

Pos :: struct {
	offset: int,
	line: int,
	column: int,
}

Token :: struct {
	using pos: Pos,
	kind: Token_Kind,
	text: string,
}

Tokenizer :: struct {
	using pos: Pos,
	data: string,
	r: rune, // current rune
	w: int, // current rune width in bytes
	curr_line_offset: int,
	spec: Specification,
}

make_tokenizer :: proc(data: string, spec := DEFAULT_SPECIFICATION) -> Tokenizer {
	t := Tokenizer {
		pos = {line=1},
		data = data,
		spec = spec,
	}

	next_rune(&t)
	if t.r == utf8.RUNE_BOM {
		next_rune(&t)
	}

	return t
}

next_rune :: proc(t: ^Tokenizer) -> rune #no_bounds_check {
	if t.offset >= len(t.data) {
		t.r = utf8.RUNE_EOF
	} else {
		t.offset += t.w
		t.r, t.w = utf8.decode_rune_in_string(t.data[t.offset:])
		t.pos.column = t.offset - t.curr_line_offset
		if t.offset >= len(t.data) {
			t.r = utf8.RUNE_EOF
		}
	}
	return t.r
}

get_token :: proc(t: ^Tokenizer) -> (token: Token, err: Error) {
	skip_digits :: proc(t: ^Tokenizer) {
		for t.offset < len(t.data) {
			switch t.r {
				case '0'..='9': next_rune(t)
				case: return
			}
		}
	}
	
	skip_multiline_comment :: proc(t: ^Tokenizer) {
		if t.r != '/' {	
			return
		}

		next_rune(t)
		if t.r != '*' {
			return
		}

		for t.offset < len(t.data) {
			if is_newline(t.r) {
				t.line += 1
				t.curr_line_offset = t.offset
				t.pos.column = 1
			}

			if t.r == '*' {
				next_rune(t)
				if t.r == '/' {
					return	
				}	
			}			

			next_rune(t)
		}
	}
	
	skip_whitespace :: proc(t: ^Tokenizer) {
		loop: for t.offset < len(t.data) {
			skip_multiline_comment(t)

			if is_newline(t.r) {
				t.line += 1
				t.curr_line_offset = t.offset
				t.pos.column = 1
				return
			}

			if is_whitespace(t.r) {
				next_rune(t)
			} else {
				break loop
			}
		}
	}

	skip_hex_digits :: proc(t: ^Tokenizer) {
		for t.offset < len(t.data) {
			next_rune(t)
			switch t.r {
			case '0'..='9', 'a'..='f', 'A'..='F':
				// Okay
			case:
				return
			}
		}
	}

	skip_alphanum :: proc(t: ^Tokenizer) {
		for t.offset < len(t.data) {
			if is_whitespace(t.r) || is_newline(t.r) {				
				return
			}

			switch t.r {
			case '(', ')', '{', '}', 
				'[', ']', '\\', '/', 
				'"', '#', ';', '=':
				return

			case 0..=0xD7FF, 0xE000..=0x10FFFF:
				next_rune(t)
				continue
			}

			return
		}
	}

	skip_line :: proc(t: ^Tokenizer) {
		for t.offset < len(t.data) {
			if is_newline(t.r) {
				t.line += 1
				t.curr_line_offset = t.offset
				t.pos.column = 1
				return
			}
			next_rune(t)
		}
	}

	scan_escape :: proc(t: ^Tokenizer) -> bool {
		switch t.r {
		case '"', '\'', '\\', '/', 'b', 'n', 'r', 't', 'f':
			next_rune(t)
			return true
		case 'u':
			// Expect 4 hexadecimal digits
			for i := 0; i < 4; i += 1 {
				r := next_rune(t)
				switch r {
				case '0'..='9', 'a'..='f', 'A'..='F':
					// Okay
				case:
					return false
				}
			}
			return true
		case:
			// Ignore the next rune regardless
			next_rune(t)
		}
		return false
	}

	skip_whitespace(t)
	token.pos = t.pos
	token.kind = .Invalid

	curr_rune := t.r
	next_rune(t)

	if is_disallowed(curr_rune) {
		return
	}

	// TODO add multiline strings
	// TODO add raw strings
	// TODO slashdash comments
	block: switch curr_rune {
	case utf8.RUNE_ERROR: err = .Illegal_Character
	case utf8.RUNE_EOF:
		token.kind = .EOF
		err = .EOF

	case '\n':
		skip_whitespace(t)
		token.kind = .Newline

	case '{': token.kind = .Open_Brace
	case '}': token.kind = .Close_Brace
	case '(': token.kind = .Open_Paren
	case ')': token.kind = .Close_Paren
	case '=': token.kind = .Equal

	case '/':
		if t.r == '/' {
			skip_line(t)
		}
		token, err = get_token(t)

	case '-': 
		token.kind = .Minus

		if !unicode.is_digit(t.r) && !is_whitespace(t.r) {
			skip_alphanum(t)
			token.kind = .Quote
		}


	case '"':
		token.kind = .Quote

		for t.offset < len(t.data) {
			r := t.r
			if is_newline(r) || r < 0 {
				err = .String_Not_Terminated
				break
			}
			next_rune(t)

			if r == '"' {
				break
			}

			if r == '\\' {
				scan_escape(t)
			}
		}

		str := string(t.data[token.offset:t.offset])
		if !is_valid_string_literal(str) {
			err = .Invalid_String
		}
	
	case '0'..='9':
		token.kind = .Int
		skip_hex_digits(t)

		if t.r == '.' {
			token.kind = .Float
			next_rune(t)
		}
		skip_digits(t)

		str := string(t.data[token.offset:t.offset])
		if !is_valid_number(str) {
			err = .Invalid_Number
		}


	case '\\': 
		next_rune(t)
		skip_whitespace(t)

		// TODO handle ocmments
		if !is_newline(t.r) {
			return
		}

	case '#': token.kind = .Hash

	case 0..=0xD7FF, 0xE000..=0x10FFFF:
		token.kind = .Ident
		skip_alphanum(t)

		switch str := string(t.data[token.offset:t.offset]); str {
			case "null": token.kind = .Null
			case "true": token.kind = .True
			case "false": token.kind = .False
			case "inf": token.kind = .Inf
			case "nan": token.kind = .NaN
		}
	}

	token.text = string(t.data[token.offset:t.offset])
	return
}

// TODO
is_valid_number :: proc(str: string) -> bool {
	return true
}

is_valid_string_literal :: proc(str: string) -> bool {
	i := 0
	for i < len(str) {
		r, width := utf8.decode_rune(str[i:])
		if r == utf8.RUNE_ERROR && width == 1 {
			return false
		}
		defer i += width

		if is_disallowed(r) {
			return false
		}

		if r == '\\' {
			i += 1

			if is_whitespace(r) {
				continue
			}

			switch r {
			case 'n', 'r', 't', '\\', '"', 'b', 'f', 's':
				continue

			case 'u':
				switch r {
				case 0..=0xD7FF, 0xE000..=0x10FFFF:
					continue
				case: return false
				}

			case: return false
			}
		}
	}

	return true
}
