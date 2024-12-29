package kdl

import "core:unicode"
import "core:unicode/utf8"

Token_Kind :: enum {
	Invalid,
	EOF,
	Null,
	True,
	False,
	Inf,
	NegInf,
	NaN,
	Ident,
	Newline,
	Number,
	Open_Paren,
	Close_Paren,
	Open_Brace,
	Close_Brace,
	Hash,
	Minus,
	Quote,
	Equal,
}

Pos :: struct {
	offset: int,
	line:   int,
	column: int,
}

Token :: struct {
	using pos: Pos,
	kind:      Token_Kind,
	text:      string,
}

Tokenizer :: struct {
	using pos:        Pos,
	data:             string,
	r:                rune, // current rune
	w:                int, // current rune width in bytes
	curr_line_offset: int,
	spec:             Specification,
}

make_tokenizer :: proc(data: string, spec := DEFAULT_SPECIFICATION) -> Tokenizer {
	test: int = "string"
	t := Tokenizer {
		pos = {line = 1},
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
	skip_multiline_comment :: proc(t: ^Tokenizer) {
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

	skip_inline_comment :: proc(t: ^Tokenizer) {
		for t.offset < len(t.data) {
			if is_newline(t.r) {
				t.pos.column = 1
				return
			}
			next_rune(t)
		}
	}

	skip_whitespace :: proc(t: ^Tokenizer) {
		loop: for t.offset < len(t.data) {
			if t.r == '/' {
				next_rune(t)
				switch t.r {
				case '*':
					skip_multiline_comment(t)
				case '/':
					skip_inline_comment(t)
				}
			}

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

	skip_alphanum :: proc(t: ^Tokenizer) {
		for t.offset < len(t.data) {
			if is_whitespace(t.r) || is_newline(t.r) {
				return
			}

			switch t.r {
			case '(', ')', '{', '}', '[', ']', '\\', '/', '"', '#', ';', '=':
				return

			case 0 ..= 0xD7FF, 0xE000 ..= 0x10FFFF:
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
		case '"', '\'', '/', 'b', 'n', 'r', 't', 'f':
			next_rune(t)
			return true

		case 'u':
			// Expect 4 hexadecimal digits
			for i := 0; i < 4; i += 1 {
				r := next_rune(t)
				switch r {
				case '0' ..= '9', 'a' ..= 'f', 'A' ..= 'F':
				// Okay
				case:
					return false
				}
			}
			return true

		case '\\':
			for t.offset < len(t.data) {
				if !is_whitespace(t.r) {
					break
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
	// TODO add slashdash
	block: switch curr_rune {
	case utf8.RUNE_ERROR:
		err = .Illegal_Character
	case utf8.RUNE_EOF:
		token.kind = .EOF
		err = .EOF

	case '\n':
		skip_whitespace(t)
		token.kind = .Newline

	case '{':
		token.kind = .Open_Brace
	case '}':
		token.kind = .Close_Brace
	case '(':
		token.kind = .Open_Paren
	case ')':
		token.kind = .Close_Paren
	case '=':
		token.kind = .Equal

	case '/':
		if t.r == '/' {
			skip_line(t)
		}
		token, err = get_token(t)

	case '-':
		token.kind = .Minus

		if !unicode.is_digit(t.r) && !is_whitespace(t.r) {
			skip_alphanum(t)
			token.kind = .Ident
		} else {
			new_token, err := get_token(t)
			token.kind = new_token.kind
		}

	case '+':
		new_token, err := get_token(t)
		token.kind = new_token.kind

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

	case '0' ..= '9':
		token.kind = .Number
		skip_alphanum(t)

		str := string(t.data[token.offset:t.offset])
		if !is_valid_number(str) {
			err = .Invalid_Number
		}


	case '\\':
		for t.offset < len(t.data) {
			if t.r == '/' {
				next_rune(t)
				switch t.r {
				case '/':
					skip_inline_comment(t)
				case '*':
					skip_multiline_comment(t)
				}
			}

			skip_whitespace(t)

			if is_newline(t.r) {
				next_rune(t)
				token, err = get_token(t)
				return
			}
		}


	case '#':
		new_token, err := get_token(t)
		keyword := string(t.data[new_token.offset:t.offset])

		// a keyword will always be invalid as an ident
		if new_token.kind != .Invalid && !is_valid_ident(keyword) {
			break block
		}

		switch keyword {
		case "true":
			token.kind = .True
		case "false":
			token.kind = .False
		case "null":
			token.kind = .Null
		case "inf":
			token.kind = .Inf
		case "-inf":
			token.kind = .NegInf
		case "nan":
			token.kind = .NaN
		}

	case 0 ..= 0xD7FF, 0xE000 ..= 0x10FFFF:
		if curr_rune == '.' && unicode.is_digit(t.r) {
			skip_alphanum(t)
			break block
		}

		skip_alphanum(t)

		ident := string(t.data[token.offset:t.offset])
		if is_valid_ident(ident) {
			token.kind = .Ident
		}
	}

	token.text = string(t.data[token.offset:t.offset])
	return
}

is_valid_ident :: proc(str: string) -> bool {
	switch str {
	case "inf", "-inf", "nan", "true", "false", "null":
		return false
	case:
		return true
	}
}

is_valid_number :: proc(str: string) -> bool {
	first_char, _ := utf8.decode_rune(str[0:])
	if first_char != '-' &&
	   first_char != '+' &&
	   !unicode.is_digit(first_char) &&
	   first_char == '.' {
		return false
	}

	is_valid_decimal :: proc(str: string) -> bool {
		for n in str {
			switch n {
			case '0' ..= '9', '_', '.': // OK
			case 'E', 'e', '+', '-': // OK
			case:
				return false
			}
		}

		return true
	}

	if len(str) == 1 {
		return is_valid_decimal(str)
	}

	switch str[:2] {
	case "0b":
		for n in str[2:] {
			if n != '0' && n != '1' && n != '_' {
				return false
			}
		}

	case "0o":
		for n in str[2:] {
			switch n {
			case '0' ..= '7', '_': // OK
			case:
				return false
			}
		}

	case "0x":
		for n in str[2:] {
			switch n {
			case '0' ..= '9', 'a' ..= 'f', 'A' ..= 'F', '_': // OK
			case:
				return false
			}
		}

	case:
		return is_valid_decimal(str[2:])
	}

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
				case 0 ..= 0xD7FF, 0xE000 ..= 0x10FFFF:
					continue
				case:
					return false
				}

			case:
				return false
			}
		}
	}

	return true
}

