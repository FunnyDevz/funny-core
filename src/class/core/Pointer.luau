--!strict
--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>


const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const ftype = require("@static/ftype")
const types = require("@declare/types")
const std = require("@extension/std")
const tables = require("@declare/tables")

const private = {type = "pointer"}
const class: pointer = LuaObject:new({
	type = private.type,
	set_point = ftype:write(function<Y>(self: pointer, to: Y, hard: boolean?): ()
		if std:assert(private.points_set[self] == nil, "cannot reload existed Pointer to new value, abort") then
			return
		end
		private.points_set[self] = true

		if hard then
			private.points_hard[self] = to
		else
			private.points[self] = to
		end
	end, mtypes.never, private.type, mtypes.anyt, ftype:opt(types.boolean)),

	get_pointed = ftype:write(function(self: pointer): unknown
		if private.points_set[self] ~= true then
			return nil
		end

		if self:is_pointed_hard() then
			return private.points_hard[self]
		end

		return private.points[self]
	end, ftype:opt(mtypes.anyt), private.type),

	is_pointed_hard = ftype:write(function(self: pointer): boolean
		return private.points_hard[self] ~= nil
	end, types.boolean, private.type),

	is_pointed_exists = ftype:write(function(self: pointer): boolean
		return private.points_set[self] == true and (private.points[self] ~= nil or self:is_pointed_hard())
	end, types.boolean, private.type),
})

do
	type list<T = unknown> = { [pointer]: T }

	private.points_set = setmetatable({} :: list<boolean>, tables.__mode_ks)
	private.points_hard = setmetatable({} :: list<unknown>, tables.__mode_ks)
	private.points = setmetatable({} :: list<unknown>, tables.__mode_kvs)
end

return class
