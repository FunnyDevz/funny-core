--!strict

const declare = require("./declare")
const project = require("./project")

const arg = require("./mtargument")
const outs = require("./mtout")

type argument = arg.argument
type tval = arg.tval
type out = outs.out

--[==[
	Represents an arbitrary function type.

	The type is intentionally unconstrained because `ftype` stores type
	information separately from the function's native Luau type.
]==]
type func = (...any) -> ...any

--[==[
	Provides storage and querying operations for runtime function type
	descriptions.

	`ftype` maps functions to their declared argument and result types and
	provides helpers for constructing, inspecting, and testing those
	descriptions.

	Type expressions are represented recursively through `tval` and `argument`,
	allowing modifiers such as optional, variadic, and union arguments to be
	encoded without depending on Luau's native type objects.
]==]
type ftype = {

	--[==[
		Writes type information for a function into the ftype registry.

		`func` is the function whose type should be registered.
		`rtype` describes the function's result type.
		`...tval` describes the types of its arguments.

		Returns the original function unchanged, allowing the result of
		this call to be used directly where the function itself is expected.
	]==]
	read write: <T>(self: ftype, func: T, rtype: tval, ...tval) -> T,

	--[==[
		Reads the type information previously registered for one or more functions.

		Returns one `out` descriptor for each supplied function. If a function
		has not been registered, its returned descriptor represents that
		unknown/unregistered state according to the implementation.
	]==]
	read read: (self: ftype, ...func) -> ...out,

	--[==[
		Checks whether the type information guarantees that a function's return
		value can be described by its declared result type.

		This is intended to distinguish guaranteed type information from
		information which may be incomplete or conditional.
	]==]
	read is_guaranteed: (self: ftype, out: out) -> boolean,

	--[==[
		Checks whether an argument descriptor is optional.

		An optional argument may be omitted by the caller and therefore does not
		necessarily have to be supplied at runtime.
	]==]
	read is_opt: (self: ftype, argument: argument) -> boolean,

	--[==[
		Checks whether an argument descriptor is variadic.

		arg variadic argument represents zero or more values of its declared type
		rather than one fixed argument position.
	]==]
	read is_var: (self: ftype, argument: argument) -> boolean,

	--[==[
		Checks whether an argument descriptor represents a union of types.

		arg union argument may accept more than one alternative type.
	]==]
	read is_or: (self: ftype, argument: argument) -> boolean,

	--[==[
		Checks whether an argument descriptor contains all of the specified
		types.

		The meaning of multiple `types` is determined by the implementation,
		but the check is intended for querying the concrete type names stored
		in the descriptor.
	]==]
	read is_type: (self: ftype, argument: argument, ...string) -> boolean,

	--[==[
		Checks whether a function result descriptor has the specified result
		type or types.

		This is the result-side counterpart of `is_type`.
	]==]
	read is_result: (self: ftype, out: out, ...string) -> boolean,

	--[==[
		Checks whether an argument contains the specified type value.

		The value may be either a concrete type name or another argument
		descriptor used as a nested type expression.
	]==]
	read has_tval: (self: ftype, argument: argument, value: tval) -> boolean,

	--[==[
		Checks whether an argument contains all of the specified concrete
		type names.
	]==]
	read has_type: (self: ftype, argument: argument, ...string) -> boolean,

	--[==[
		Checks whether any argument of the function is optional.
	]==]
	read has_opt: (self: ftype, out: out) -> boolean,

	--[==[
		Checks whether any argument of the function is variadic.
	]==]
	read has_var: (self: ftype, out: out) -> boolean,

	--[==[
		Checks whether any argument of the function is a union.
	]==]
	read has_or: (self: ftype, out: out) -> boolean,

	--[==[
		Gets the descriptor of the function's return value.
	]==]
	read get_result: (self: ftype, out: out) -> argument,

	--[==[
		Gets all declared argument descriptors of the function.
	]==]
	read get_arguments: (self: ftype, out: out) -> { argument },

	--[==[
		Extracts the raw type values stored in an argument descriptor.

		Each returned value is either a concrete type name or a nested argument
		descriptor.
	]==]
	read get_tval: (self: ftype, argument: argument) -> ...tval,

	--[==[
		Extracts the concrete type names represented by an argument descriptor.

		Nested argument descriptors are not returned.
	]==]
	read get_types: (self: ftype, argument: argument) -> ...string,

	--[==[
		Extracts nested argument descriptors contained inside an argument's
		type-value representation.
	]==]
	read get_arguments_from_tval: (self: ftype, argument: argument) -> ...argument,

	--[==[
		Creates an optional argument descriptor from the supplied type values.

		The resulting argument accepts the described type while allowing the
		argument itself to be omitted.
	]==]
	read opt: (self: ftype, ...tval) -> ...argument,

	--[==[
		Creates a variadic argument descriptor from the supplied type values.

		The resulting argument describes a variable-length sequence of values
		of the given type.
	]==]
	read var: (self: ftype, ...tval) -> argument,

	--[==[
		Creates a union argument descriptor from the supplied type values.

		The resulting argument accepts one of the supplied alternatives.
	]==]
	read uor: (self: ftype, ...tval) -> argument,

	--[==[
		Creates a variadic union argument descriptor.

		The resulting argument accepts zero or more values, where each value may
		match one of the supplied type alternatives.
	]==]
	read var_or: (self: ftype, ...tval) -> argument,

	--[==[
		Creates an argument descriptor that is both variadic and optional.

		This represents a variable-length argument sequence which may also be
		omitted entirely.
	]==]
	read var_or_opt: (self: ftype, ...tval) -> argument,

	--[==[
		Creates an argument descriptor that is both variadic and optional.
		
		This is the non-union form of `var_or_opt`: the supplied type values
		describe the accepted repeated value type directly.
	]==]
	read var_opt: (self: ftype, ...tval) -> argument,

	--[==[
		Creates an optional union argument descriptor.

		The resulting argument may be omitted, and when supplied its value must
		match one of the specified type alternatives.
	]==]
	read or_opt: (self: ftype, ...tval) -> argument,
}

const packed = setmetatable(
	{} :: { [func]: out? },
	table.freeze({
		__mode = "ks" :: "ks",
	})
)

const ftype: ftype = table.freeze({
	write = function<T>(self: ftype, func: T, rtype: tval, ...: tval): T
		const args: { argument } = {}

		local has_var = false

		for _, value in { ... } do
			const argument = arg.pack(value)

			if argument.var then
				if has_var then
					project.console_out_error("ftype arg with .var already exists, skip")

					continue
				end

				has_var = true
			elseif has_var then
				project.console_out_error("ftype arg after .var is not allowed, skip")

				continue
			end

			table.insert(args, argument)
		end

		packed[func] = outs.new(arg.pack(rtype), args, true)

		return func
	end,

	read = function(self: ftype, ...: func): ...out
		const result: { out } = {}

		for _, func in { ... } do
			table.insert(result, packed[func] or outs.unknown)
		end

		return unpack(result)
	end,

	is_opt = function(_self: ftype, argument: argument): boolean
		return argument.opt
	end,

	is_var = function(_self: ftype, argument: argument): boolean
		return argument.var
	end,

	is_or = function(_self: ftype, argument: argument): boolean
		return argument.uor
	end,

	is_type = function(_self: ftype, argument: argument, ...: string): boolean
		for _, expected in { ... } do
			for _, actual in argument.tval do
				if type(actual) == declare.string and actual == expected then
					return true
				end
			end
		end

		return false
	end,

	has_tval = function(_self: ftype, argument: argument, value: tval): boolean
		return arg.has_tval(argument, value)
	end,

	has_type = function(self: ftype, argument: argument, ...: string): boolean
		return self:is_type(argument, ...)
	end,

	is_guaranteed = function(_self: ftype, out: out): boolean
		return out.guaranteed
	end,

	has_opt = function(_self: ftype, out: out): boolean
		for _, argument in out.arguments_types do
			if argument.opt then
				return true
			end
		end

		return false
	end,

	has_var = function(_self: ftype, out: out): boolean
		for _, argument in out.arguments_types do
			if argument.var then
				return true
			end
		end

		return false
	end,

	has_or = function(_self: ftype, out: out): boolean
		for _, argument in out.arguments_types do
			if argument.uor then
				return true
			end
		end

		return false
	end,

	is_result = function(self: ftype, out: out, ...: string): boolean
		return self:is_type(out.result_type, ...)
	end,

	get_result = function(_self: ftype, out: out): argument
		return out.result_type
	end,

	get_arguments = function(_self: ftype, out: out): { argument }
		return out.arguments_types :: any
	end,

	get_tval = function(_self: ftype, argument: argument): ...tval
		const values = arg.get_tval(argument)

		return unpack(values)
	end,

	get_types = function(_self: ftype, argument: argument): ...string
		const result: { string } = {}

		for _, value in argument.tval do
			if type(value) == declare.string then
				table.insert(result, value :: string)
			end
		end

		return unpack(result)
	end,

	get_arguments_from_tval = function(_self: ftype, argument: argument): ...argument
		const result: { argument } = {}

		for _, value in argument.tval do
			if type(value) == declare.table then
				table.insert(result, value :: argument)
			end
		end

		return unpack(result)
	end,

	opt = function(_self: ftype, ...: tval): ...argument
		const result: { argument } = {}

		for _, value in { ... } do
			local argument = arg.pack(value, true, false, false)

			table.insert(result, argument)
		end

		return unpack(result)
	end,

	var = function(_self: ftype, ...: tval): argument
		return arg.new(table.freeze {...}, false, true, false)
	end,

	uor = function(_self: ftype, ...: tval): argument
		return arg.new(table.freeze {...}, false, false, true)
	end,

	var_or = function(_self: ftype, ...: tval): argument
		return arg.new(table.freeze {...}, false, true, true)
	end,

	var_or_opt = function(_self: ftype, ...: tval): argument
		return arg.new(table.freeze { ... }, true, true, true)
	end,

	var_opt = function(_self: ftype, ...: tval): argument
		return arg.new(table.freeze {...}, true, true, false)
	end,

	or_opt = function(_self: ftype, ...: tval): argument
		return arg.new(table.freeze{...}, true, false, true)
	end,
})

return ftype
