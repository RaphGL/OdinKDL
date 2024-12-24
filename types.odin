package kdl

import "core:mem"

Specification :: enum {
	KDL1,
	KDL2,
}

DEFAULT_SPECIFICATION :: Specification.KDL2

Document :: distinct []Node

Value :: distinct Maybe(union {
	string, 
	bool, 
	union {i64, i128, u64, u128, f32, f64}
})

Argument :: distinct Value

Property :: struct{
	key: string,
	val: Value,
}

Entry :: union {Argument, Property}

Type :: enum {
	I8, I16, I32, I64, I128,
	U8, U16, U32, U64, U128,
	F32, F64,
	Decimal64, Decimal128,
	Date_Time,
	Time,
	Date,
	Duration,
	Decimal,
	Currency,
	Country_2, Country_3,
	Country_Subdivision,
	Email, IDN_Email,
	Hostname, IDN_Hostname,
	IPV4, IPV6,
	URL, URL_Reference,
	IRL, IRL_Reference, 
	URL_Template,
	UUID,
	Regex,
	Base64,
}

Node :: struct {
	type: string,
	name: string,
	entries: []Entry,
	children: []Node,
}

Parser :: struct {
	tok: Tokenizer,
	prev_token: Token,
	curr_token: Token,
	spec: Specification,
	allocator: mem.Allocator,
}

Error :: enum {
	None,
	Invalid,
	Illegal_Character,
	Invalid_Number,
	Invalid_String,
	String_Not_Terminated,
	EOF,
}
