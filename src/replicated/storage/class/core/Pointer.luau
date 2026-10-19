--!strict
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: pointer = LuaObject:new({
	type = "pointer",
	set_point = ftype:write(function<Y>(self: pointer, to: Y, hard: boolean?): ()
		if project.assert(private.points_set[self] == nil, "cannot reload existed Pointer to new value, abort") then
			return
		end
		private.points_set[self] = true

		if hard then
			private.points_hard[self] = to
		else
			private.points[self] = to
		end
	end, declare["nil"], "pointer", declare.anyt, ftype:opt(declare.boolean)),

	get_pointed = ftype:write(function(self: pointer): unknown
		if private.points_set[self] ~= true then
			return nil
		end

		if self:is_pointed_hard() then
			return private.points_hard[self]
		end

		return private.points[self]
	end, ftype:opt(declare.anyt), "pointer"),

	is_pointed_hard = ftype:write(function(self: pointer): boolean
		return private.points_hard[self] ~= nil
	end, declare.boolean, "pointer"),

	is_pointed_exists = ftype:write(function(self: pointer): boolean
		return private.points_set[self] == true and (private.points[self] ~= nil or self:is_pointed_hard())
	end, declare.boolean, "pointer"),
})

do
	type list<T = unknown> = { [pointer]: T }

	private.meta = table.freeze({ __mode = "ks" })
	private.points_set = setmetatable({} :: list<boolean>, private.meta)
	private.points_hard = setmetatable({} :: list<unknown>, private.meta)
	private.points = setmetatable({} :: list<unknown>, table.freeze({ __mode = "kvs" }))
end

ctype:read(class):write_tag(ctags.core)

return class
