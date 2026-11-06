--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const LuaObject = require("@class/core/LuaObject")
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const std = require("@extension/std")
const ftype = require("@static/ftype")


const private = {type = "maybe"}
const class: maybe = (Observer :: observer<enumitem_operation_variant>):new({
	type = private.type,

	extract = ftype:write(function(self: maybe, it: unknown, make: () -> any): any
		const stored = private.get(self)
		const that = stored[it] or make()

		if stored[it] == nil then
			stored[it] = that
			self:notificate(OperationVariant.New, it, that)
		end

		return that
	end, mtypes.anyt, private.type, mtypes.anyt, types["function"]),

	enactment = ftype:write(function (self: maybe, it: unknown, of: luaobject) : luaobject
		if not std:assert(self:that(of, LuaObject.type), "unexpected object") then
			return of
		end

		const stored = private.get(self)
		local current = stored[it]

		if current == nil then
			current = of:new()
			stored[it] = current
			self:notificate(OperationVariant.New, it, current)
		end

		return current :: any
	end, LuaObject.type, private.type, mtypes.anyt, LuaObject.type),

	exist = ftype:write(function(self: maybe, it: unknown): boolean
		return private.get(self)[it] ~= nil
	end, types.boolean, private.type, mtypes.anyt),

	erase = ftype:write(function(self: maybe, it: unknown): ()
		const stored = private.get(self)

		if stored[it] == nil then return end
		stored[it] = nil

		self:notificate(OperationVariant.Remove, it)
	end, mtypes.never, private.type, mtypes.anyt),
})

class:host(function(new)
	const new = new:as <<maybe>> (class.type)
	new:set(private.key, setmetatable({}, tables.__mode_ks))
end)

do
	private.key = newproxy()
	private.get = function (self: maybe)
		return self:get <<{[unknown]: unknown}>>(private.key)
	end
end

return class
