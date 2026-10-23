--!strict
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const private = {}
const class: variable = LuaObject:new({
	creation_time = os.clock(),

	get_value = ftype:write(function<T>(self: variable<T>): unknown
		return private.space[self][#private.space[self]]
	end, ftype:opt(mtypes.anyt), "variable"),

	set_value = ftype:write(function<T>(self: variable<T>, to: T): ()
		private.space[self][#private.space[self]] = to
	end, mtypes.never, "variable", ftype:opt(mtypes.anyt)),

	history = ftype:write(function<T>(self: variable<T>): { [number]: T }
		return table.clone(private.space[self])
	end, types.table, "variable"),
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
