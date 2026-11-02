--!strict
const mtypes = require("@static/declare/mtypes")
const types = require("@static/declare/types")
const utypes = require("@static/declare/utypes")

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
	if getmetatable(value :: any) == argument.metatable then
		return value :: any
	end

	return table.freeze(setmetatable({
		tval = value,
		opt = opt == true,
		var = var == true,
		uor = uor == true,
	}, argument.metatable)) :: any
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

const relevant_meta = table.freeze({
	[mtypes.anyt] = function(value: unknown): boolean
		return true
	end,

	[mtypes.never] = function(value: unknown): boolean
		return value == nil
	end,

	[mtypes.error] = function(value: unknown): boolean
		return false
	end,

	[mtypes.inf_positive] = function(value: unknown): boolean
		return value == math.huge
	end,

	[mtypes.inf_negative] = function(value: unknown): boolean
		return value == -math.huge
	end,

	[mtypes.nan] = function(value: unknown): boolean
		return type(value) == types.number and value ~= value
	end,

	[utypes.luaobject] = function(value: unknown): boolean
		return argument.is_luaobject(value)
	end,
}) :: { read [string]: (value: unknown) -> boolean }

function argument.is_luaobject(value: unknown): boolean
	if type(value) ~= types.table then
		return false
	end

	const that = value :: any
	return type(that.type) == types.string and type(that.is) == types["function"] and type(that.that) == types["function"]
end

function argument.match_tval(value: unknown, name: string): boolean
	const meta = relevant_meta[name]

	if meta then
		return meta(value)
	end

	if type(value) == name or typeof(value) == name or utypes:utype(value) == name then
		return true
	end

	if argument.is_luaobject(value) then
		const succ, result = pcall((value :: any).is, value, name)
		return succ and result == true
	end

	return false
end

function argument.match(self: argument, value: unknown): boolean
	if value == nil and (self.opt or self.var) then
		return true
	end

	for k, v in self.tval do
		if type(v) == types.string then
			if argument.match_tval(value, v :: string) then
				return true
			end
		elseif argument.match(v :: argument, value) then
			return true
		end
	end

	return false
end

argument.unknown = argument.pack(types["nil"], false, false, false)

return table.freeze(argument)