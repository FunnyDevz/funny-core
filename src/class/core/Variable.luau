--!strict
--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const private = {type = "variable"}
const class: variable = LuaObject:new({
	type = private.type,
	creation_time = os.clock(),

	get_value = ftype:write(function<T>(self: variable<T>): unknown
		return private.space[self][#private.space[self]]
	end, ftype:opt(mtypes.anyt), private.type),

	set_value = ftype:write(function<T>(self: variable<T>, to: T): ()
		private.space[self][#private.space[self]] = to
	end, mtypes.never, private.type, ftype:opt(mtypes.anyt)),

	history = ftype:write(function<T>(self: variable<T>): { [number]: T }
		return table.clone(private.space[self])
	end, types.table, private.type),
})

class:host(function(new: luaobject)
    const new = new:as <<variable>> (class.type)
	private.space[new] = {}
end)

do
	private.space = setmetatable({} :: { [variable]: { [number]: unknown } }, tables.__mode_ks)
	private.space[class] = {}
end

return class
