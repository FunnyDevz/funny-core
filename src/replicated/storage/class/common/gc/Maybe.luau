--!strict
const LuaObject = require("@class/core/LuaObject")
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const stderr = require("@extension/stderr")
const Cryptography = require("@import/Cryptography")
const ftype = require("@static/ftype")


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
	end, mtypes.anyt, "maybe", mtypes.anyt, types["function"]),

	enactment = ftype:write(function (self: maybe, it: unknown, of: luaobject) : luaobject
		if not stderr:assert(self:that(of, "LuaObject"), "unexpected obhect") then
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
	end, LuaObject.type, "maybe", mtypes.anyt, LuaObject.type),

	exist = ftype:write(function(self: maybe, it: unknown): boolean
		return private.get(self)[it] ~= nil
	end, types.boolean, "maybe", mtypes.anyt),

	erase = ftype:write(function(self: maybe, it: unknown): ()
		const stored = private.get(self)

		if stored[it] == nil then return end
		stored[it] = nil

		self:notificate(OperationVariant.Remove, it)
	end, mtypes.never, "maybe", mtypes.anyt),
})

class:host(function(new)
	const new = new:as <<maybe>> (class.type)
	new:set(private.key, setmetatable({}, tables.__mode_ks))
end)

do
	private.key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "maybe_key")
	private.get = function (self: maybe)
		return self:get <<{[unknown]: unknown}>>(private.key)
	end
end

return class
