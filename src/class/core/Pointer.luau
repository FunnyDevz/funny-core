--!strict
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const stderr = require("@extension/stderr")
const ftype = require("@static/ftype")
const types = require("@declare/types")
const ctype = require("@static/ctype")
const ctags = require("@static/ctags")

const private = {}
const class: pointer = LuaObject:new({
	type = "pointer",
	set_point = ftype:write(function<Y>(self: pointer, to: Y, hard: boolean?): ()
		if stderr:assert(private.points_set[self] == nil, "cannot reload existed Pointer to new value, abort") then
			return
		end
		private.points_set[self] = true

		if hard then
			private.points_hard[self] = to
		else
			private.points[self] = to
		end
	end, mtypes.never, "pointer", mtypes.anyt, ftype:opt(types.boolean)),

	get_pointed = ftype:write(function(self: pointer): unknown
		if private.points_set[self] ~= true then
			return nil
		end

		if self:is_pointed_hard() then
			return private.points_hard[self]
		end

		return private.points[self]
	end, ftype:opt(mtypes.anyt), "pointer"),

	is_pointed_hard = ftype:write(function(self: pointer): boolean
		return private.points_hard[self] ~= nil
	end, types.boolean, "pointer"),

	is_pointed_exists = ftype:write(function(self: pointer): boolean
		return private.points_set[self] == true and (private.points[self] ~= nil or self:is_pointed_hard())
	end, types.boolean, "pointer"),
})

do
	type list<T = unknown> = { [pointer]: T }

	private.meta = table.freeze({ __mode = "ks" })
	private.points_set = setmetatable({} :: list<boolean>, private.meta)
	private.points_hard = setmetatable({} :: list<unknown>, private.meta)
	private.points = setmetatable({} :: list<unknown>, table.freeze({ __mode = "kvs" }))
end

return class
