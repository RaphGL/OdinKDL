package kdl

is_whitespace :: proc(r: rune) -> bool {
	switch r {
		case '\u0009', '\u0020', '\u00A0', '\u1680', 
			'\u2000', '\u2001', '\u2002','\u2003', 
			'\u2004', '\u2005', '\u2006', '\u2007', 
			'\u2008', '\u2009', '\u200A', '\u202F', 
			'\u205F', '\u3000': return true

		case: return false
	}
}

is_newline :: proc(r: rune) -> bool {
	switch r {
		case '\u000D', '\u000A', '\u0085', '\u000B',
			'\u000C', '\u2028', '\u2029': return true

		case: return false
	}
}

is_disallowed :: proc(r: rune) -> bool {
	switch r {
		case '\u0000'..='\u0008', // control characters  
			'\u000E'..='\u001F', // control characters
			'\uD800', // ..='\uDFFF', TODO: check why its saying its a duplicate // scalar values
			'\u200E'..='\u200F', // direction control characters 
			'\u202A'..='\u202E', // direction control characters 
			'\u2066'..='\u2069', // direction control characters 
			'\u007F', // delete control character
			'\uFEFF': // zero width non breaking space
			return true

		case: return false
	}
}
