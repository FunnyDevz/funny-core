--!strict
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const Pointer = require("@class/core/Pointer")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const SetupNotification = require("@enums/notification/SetupNotification")
const stderr = require("@extension/stderr")
const ftype = require("@static/ftype")

--[[

	setup

	connection = new connection
	pointer = connection:subscribe (SetupNotification.Install, mode, func|thread|observer)
	connection:notificate (SetupNotification.Installed)

	call

	connection:invoke(...) or connection:notificate(SetupNotification.Require, enumitem, ...)
]]

const private = {type = "connection"}
const class: connection = (Observer :: observer<enumitem_setup_notification>):new({
	type = private.type,
	on = nil :: enumitem<any>?,
	count = 1,

	get_mode = ftype:write(function(self: connection): enumitem_connection_variant
		if self:is_connected() then
			const cvar = self:subscription_get_mode(self:get(private.key) :: pointer)
			return cvar
		else
			return ConnectionVariant.Ever
		end
	end, EnumItem.type, private.type),

	set_mode = ftype:write(function(self: connection, mode: enumitem_connection_variant): ()
		if not self:is_connected() then
			return
		end
		self:subscription_set_mode(mode, self:get <<pointer>>(private.key))
	end, mtypes.never, private.type, EnumItem.type),

	is_connected = ftype:write(function(self: connection): boolean
		return self:get(private.key) ~= nil
	end, types.boolean, private.type),

	disconnect = ftype:write(function(self: connection): ()
		const func = self:get(private.key)
		if self:that(func, Pointer.type) then
			self:unsubscribe(func :: pointer)
		end

		self:notificate(SetupNotification.Disconnected)
	end, mtypes.never, private.type),

	invoke = ftype:write(function(self: connection, ...): ()
		for i = 1, self.count do
			self:notificate(private.special, ...)
		end
	end, mtypes.never, private.type, ftype:var(mtypes.anyt)),
})

class:host(function(new)
	const new = new:as <<connection>> (class.type)
	local pointer: pointer
	
	pointer = new:subscribe(SetupNotification.Install, ConnectionVariant.Ever, function(mode: enumitem, func: any)
		--#if DEBUG
		if not stderr:assert(class.is(mode, EnumItem.type), "unexpected LuaObject") then
			return
		end
		if not stderr:assert(ConnectionVariant:is_my_enumitem(mode), "unexpected move variant") then
			return
		end
		--#endif

		new:set(private.key, new:subscribe(private.special, mode :: enumitem_connection_variant, func)
)
		new:subscribe(SetupNotification.Require, ConnectionVariant.Ever, function(item, ...)
			if not stderr:check(class.is(item, EnumItem.type), "unknown enumitem") then
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
	private.key = newproxy()
end

return class
