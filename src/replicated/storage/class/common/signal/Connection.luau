--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const Observer = require("@game/ReplicatedStorage/class/core/Observer")
const Pointer = require("@game/ReplicatedStorage/class/core/Pointer")
const SecurityRNG = require("@game/ReplicatedStorage/class/service/SecurityRNG")
const ConnectionVariant = require("@game/ReplicatedStorage/enums/descriptor/ConnectionVariant")
const SetupNotification = require("@game/ReplicatedStorage/enums/notification/SetupNotification")
const declare = require("@game/ReplicatedStorage/static/declare")
const project = require("@game/ReplicatedStorage/static/project")
const ftype = require("@game/ReplicatedStorage/static/ftype")

--[[

	setup

	connection = new connection
	pointer = connection:subscribe (SetupNotification.Install, mode, func|thread|observer)
	connection:notificate (SetupNotification.Installed)

	call

	connection:invoke(...) or connection:notificate(SetupNotification.Require, enumitem, ...)
]]

const private = {}
const class: connection = (Observer :: observer<enumitem_setup_notification>):new({
	type = "connection",
	on = nil :: enumitem<any>?,
	count = 1,

	get_mode = ftype:write(function(self: connection): enumitem_connection_variant
		if self:is_connected() then
			const cvar = self:subscription_get_mode(self:get(private.key) :: pointer)
			return cvar
		else
			return ConnectionVariant.Ever
		end
	end, "enumitem", "connection"),

	set_mode = ftype:write(function(self: connection, mode: enumitem_connection_variant): ()
		if not self:is_connected() then
			return
		end
		self:subscription_set_mode(mode, self:get <<pointer>>(private.key))
	end, declare["nil"], "connection", "enumitem"),

	is_connected = ftype:write(function(self: connection): boolean
		return self:get(private.key) ~= nil
	end, declare.boolean, "connection"),

	disconnect = ftype:write(function(self: connection): ()
		const func = self:get(private.key)
		if self:that(func, Pointer.type) then
			self:unsubscribe(func :: pointer)
		end

		self:notificate(SetupNotification.Disconnected)
	end, declare["nil"], "connection"),

	invoke = ftype:write(function(self: connection, ...): ()
		for i = 1, self.count do
			self:notificate(private.special, ...)
		end
	end, declare["nil"], "connection", ftype:var(declare.anyt)),
})

class:host(function(new)
	const new = new:as <<connection>> (class.type)
	local pointer: pointer
	
	pointer = new:subscribe(SetupNotification.Install, ConnectionVariant.Ever, function(mode: enumitem, func: any)
		if not project.assert(class.is(mode, EnumItem.type), "unexpected LuaObject", true) then
			return
		end
		if not project.assert(ConnectionVariant:is_my_enumitem(mode), "unexpected move variant", true) then
			return
		end

		new:set(private.key, new:subscribe(private.special, mode :: enumitem_connection_variant, func)
)
		new:subscribe(SetupNotification.Require, ConnectionVariant.Ever, function(item, ...)
			if not project.assert(class.is(item, EnumItem.type), "unknown enumitem") then
				return
			end

			if item == new.on or new.on == nil then
				new:invoke(...)
			end
		end)

		new:notificate(SetupNotification.Installed)
		new:unsubscribe(pointer)
	end)
end)

do
	private.special = EnumItem:new({ name = "InternalConnectionCallItem" })
	private.key = SecurityRNG:get_hash_sha256("connection_func_code")
end

return class
