--!strict
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")

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
	end, ftype:opt(declare.anyt), "stack"),

	put = ftype:write(function<T>(self: stack, item: T): ()
		const stack = private.stacks[self]
		stack[#stack + 1] = item

		assert(#stack <= self.max, "stack limit capacity reached")
	end, declare["nil"], "stack", declare.anyt),

	count = ftype:write(function(self: stack): number
		return #private.stacks[self]
	end, declare.number, "stack"),
})

class:host(function(new)
	const new = new:as <<stack>> (class.type)
	private.stacks[new] = {}
end)

do
	private.meta = table.freeze({ __mode = "ks" })
	private.stacks = setmetatable({} :: { [stack]: { any } }, private.meta)
end

return class
