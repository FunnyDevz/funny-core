--!strict
const types = require("@static/declare/types")

--[==[
	Represents a type value.

	A type value is either a concrete type name or a nested `argument`
	descriptor, allowing compound type expressions to be represented
	recursively.
]==]
export type tval = string | argument

--[==[
	Describes the type and modifiers of a single function argument or result.

	`tval` contains the type representation itself. A value may be either a
	concrete type name (`string`) or a nested argument descriptor (`argument`).

	`opt` marks the value as optional, `var` marks it as variadic, and `uor`
	marks the descriptor as representing a union of alternative types.
]==]
export type argument = setmetatable<{
	read tval: { read tval },
	read opt: boolean,
	read var: boolean,
	read uor: boolean,
}, metatable>

type metatable = {
	read __utype: "argument"
}

const argument = {}

argument.metatable = table.freeze {
	__utype = "argument" :: "argument"
}


--[==[
	Packs a single type value into an `argument` descriptor.

	If `value` is already an `argument` (i.e. not a string), it is returned
	unchanged — the modifiers `opt`, `var`, `uor` only apply when constructing
	a descriptor from a raw type name.
]==]
function argument.pack(value: tval, opt: boolean?, var: boolean?, uor: boolean?): argument
	if type(value) == types.string then
		return table.freeze(setmetatable({
			tval = table.freeze({
				value :: string,
			}),

			opt = opt == true,
			var = var == true,
			uor = uor == true,
		}, argument.metatable))
	end

	return value :: argument
end

function argument.new(value: { tval }, opt: boolean?, var: boolean?, uor: boolean?): argument
	if type(value) == types.string then
		return table.freeze(setmetatable({
			tval = value,
			opt = opt == true,
			var = var == true,
			uor = uor == true,
		}, argument.metatable))
	end

	return value :: argument
end

--[==[
	Returns the raw type-value list stored inside an argument descriptor.
]==]
function argument.get_tval(self: argument): { tval }
	return self.tval :: any
end

--[==[
	Checks whether the argument contains a specific `tval` (string or nested
	argument) by reference equality.
]==]
function argument.has_tval(self: argument, value: tval): boolean
	for _, current in self.tval do
		if current == value then
			return true
		end
	end

	return false
end

argument.unknown = argument.pack(types["nil"], false, false, false)

return table.freeze(argument)