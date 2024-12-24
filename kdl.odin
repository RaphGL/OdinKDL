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

		oneline_str "test test hehe"

		something true

		// here's a comment
		true_true #true

		hash_style #

		multilinecom /* here's a comment */ --commentbeforehere #false

		anotehr comemnt /* here herher
		yep

		there's another comment here 

		command -> */ 
		command here
		
		`

		tokenizer := make_tokenizer(input)

		for token, err := get_token(&tokenizer); token.kind != .EOF; token, err = get_token(&tokenizer) {
			fmt.println(token, err)
		}
	}
}
