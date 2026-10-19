--!strict
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")

const private = {}
const class: variable = LuaObject:new({
	creation_time = os.clock(),

	get_value = function<T>(self: variable<T>): unknown
		return private.space[self][#private.space[self]]
	end,

	set_value = function<T>(self: variable<T>, to: T): ()
		private.space[self][#private.space[self]] = to
	end,

	history = function<T>(self: variable<T>): { [number]: T }
		return table.clone(private.space[self])
	end,
})

class:host(function(new: luaobject)
    const new = new:as <<variable>> (class.type)
	private.space[new] = {}
end)

do
	private.meta = table.freeze({ __mode = "ks" })
	private.space = setmetatable({} :: { [variable]: { [number]: unknown } }, private.meta)
	private.space[class] = {}
end

ctype:read(class):write_tag(ctags.core)

return class
