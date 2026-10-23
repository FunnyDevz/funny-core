--!strict
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const private = {}
const class: stack = LuaObject:new({
	type = "stack",
	max = 10000,

	pick = ftype:write(function<T>(self: stack): T?
		const stack = private.stacks[self]
		const index = #stack
		const value = stack[index]
		stack[index] = nil
		return value
	end, ftype:opt(mtypes.anyt), "stack"),

	put = ftype:write(function<T>(self: stack, item: T): ()
		const stack = private.stacks[self]
		stack[#stack + 1] = item

		assert(#stack <= self.max, "stack limit capacity reached")
	end, mtypes.never, "stack", mtypes.anyt),

	count = ftype:write(function(self: stack): number
		return #private.stacks[self]
	end, types.number, "stack"),
})

class:host(function(new)
	const new = new:as <<stack>> (class.type)
	private.stacks[new] = {}
end)

do
	private.meta = tables.__mode_ks
	private.stacks = setmetatable({} :: { [stack]: { any } }, private.meta)
end

return class
