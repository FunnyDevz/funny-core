--!strict
const Observer = require("@game/ReplicatedStorage/class/core/Observer")
const SecurityRNG = require("@game/ReplicatedStorage/class/service/SecurityRNG")
const OperationVariant = require("@game/ReplicatedStorage/enums/descriptor/OperationVariant")
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: maybe = (Observer :: observer<enumitem_operation_variant>):new({
	type = "maybe",

	extract = ftype:write(function(self: maybe, it: unknown, make: () -> any): any
		const stored = private.get(self)
		const that = stored[it] or make()

		if stored[it] == nil then
			stored[it] = that
			self:notificate(OperationVariant.New, it, that)
		end

		return that
	end, declare.anyt, "maybe", declare.anyt, declare["function"]),

	enactment = ftype:write(function (self: maybe, it: unknown, of: luaobject) : luaobject
		if not project.assert(self:that(of, "LuaObject"), "unexpected obhect", true) then
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
	end, LuaObject.type, "maybe", declare.anyt, LuaObject.type),

	exist = ftype:write(function(self: maybe, it: unknown): boolean
		return private.get(self)[it] ~= nil
	end, declare.boolean, "maybe", declare.anyt),

	erase = ftype:write(function(self: maybe, it: unknown): ()
		const stored = private.get(self)

		if stored[it] == nil then return end
		stored[it] = nil

		self:notificate(OperationVariant.Remove, it)
	end, declare["nil"], "maybe", declare.anyt),
})

class:host(function(new)
	const new = new:as <<maybe>> (class.type)
	new:set(private.key, setmetatable({}, declare.tables.__mode_ks))
end)

do
	private.key = SecurityRNG:get_hash_blake3("maybe_key")
	private.get = function (self: maybe)
		return self:get <<{[unknown]: unknown}>>(private.key)
	end
end

return class
