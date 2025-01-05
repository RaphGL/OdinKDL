package kdl

import "core:fmt"
import "core:mem"

make_parser :: proc(data: []byte, spec := DEFAULT_SPECIFICATION, allocator := context.allocator) {
	// TODO
}

parse :: proc(data: []u8, spec := DEFAULT_SPECIFICATION) {
	// TODO
}

KDL_DEBUG :: #config(KDL_DEBUG, false)

when KDL_DEBUG {
	main :: proc() {
		input :: `
		test one

		this fitson \
			multiple lines

		oneline_str "test test hehe"

		something true // just an inline comment

		// here's a comment
		true_true #true

		test x=#true

		multilinecom /* here's a comment */ --commentbeforehere #false

		anotehr comemnt /* here herher
		yep

		there's another comment here 

		command -> */ 
		command here

		multine """
		some string here
		hsldfjadf
		"""

		/- some #"raw str"#

		infm #-inf
		`


		tokenizer := make_tokenizer(input)

		for token, err := get_token(&tokenizer);
		    token.kind != .EOF;
		    token, _ = get_token(&tokenizer) {
			fmt.println(token)
		}
	}
}

