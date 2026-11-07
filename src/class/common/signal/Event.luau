--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Connection = require("@class/common/signal/Connection")
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const Scheduler = require("@class/core/Scheduler")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const SetupNotification = require("@enums/notification/SetupNotification")
const ftype = require("@static/ftype")

const private = {type = "event"}
const class: event = Observer:new({
	type = private.type,

	connect = ftype:write(function(self: event, on: enumitem?, f: any): connection
		return private.attach(self, on, ConnectionVariant.Ever, f)
	end, Connection.type, private.type, ftype:opt(EnumItem.type), ftype:uor(Observer.type, types["function"], types.thread)),

	once = ftype:write(function(self: event, on: enumitem?, f: any): connection
		return private.attach(self, on, ConnectionVariant.Once, f)
	end, Connection.type, private.type, ftype:opt(EnumItem.type), ftype:uor(Observer.type, types["function"], types.thread)),

	wait = ftype:write(function(self: event, on: enumitem?): ...any
		const to = (on or DefaultVariant.Unknown) :: enumitem
		const waiting = private.get_waiting(self)
		const con = private.attach(self, to, ConnectionVariant.Once, coroutine.running())

		waiting[con] = true
		const result = table.pack(coroutine.yield())
		waiting[con] = nil

		return table.unpack(result, 1, result.n)
	end, ftype:var(mtypes.anyt), private.type, ftype:opt(EnumItem.type)),

	invoke = ftype:write(function(self: event, call: enumitem, ...: any): ()
		const list = private.get_store(self)

		for _, v in table.clone(list) do
			v:notificate(SetupNotification.Require, call, ...)
		end
	end, mtypes.never, private.type, EnumItem.type, ftype:var_opt(mtypes.anyt)),

	invoke_deferred = ftype:write(function (self: event, on: enumitem, ...: any) : ()
		const scheduler = Scheduler:whose()
		if scheduler then
			scheduler:last(self.invoke, self, on, ...)
		else
			task.defer(self.invoke, self, on, ...)
		end
	end, mtypes.never, private.type, EnumItem.type, ftype:var_opt(mtypes.anyt)),

	copy_connections_from = ftype:write(function (self: event, which_is_a: enumitem_connection_variant?, ...: event) : ()
		const my_store = private.get_store(self)
		for _, v in {...} do
			const store = private.get_store(v)
			table.move(store, 1, #store, #my_store + 1, my_store)
		end
	end, mtypes.never, private.type, ftype:opt(EnumItem.type), ftype:var(private.type)),

	get_all_connections = ftype:write(function (self: event, which_is_a: enumitem_connection_variant?) : ...connection
		return table.unpack(private.get_store(self))
	end, ftype:var_opt(Connection.type), private.type, ftype:opt(EnumItem.type)),

	disconnect_connection = ftype:write(function (self: event, ...: connection) : ()
		const my_store = private.get_store(self)
		for _, v in {...} do
			if table.find(my_store, v) then
				v:disconnect()
			end
		end
	end, mtypes.never, private.type, ftype:var_opt(Connection.type)),

	disconnect_all_connections = ftype:write(function (self: event, which_is_a: enumitem_connection_variant?) : ()
		if which_is_a then
			for _, v in private.get_store(self) do
				if v:get_mode() == which_is_a then
					v:disconnect()
				end
			end
		else
			for _, v in private.get_store(self) do
				v:disconnect()
			end
		end
	end, mtypes.never, private.type, ftype:opt(EnumItem.type)),
})

--[[
    read invoke_deferred: (self: event<T, U...>, on: T, U...) -> (),

    read get_all_connections: (self: event<T,U...>, which_is_a: enumitem_connection_variant?) -> ...connection<T, U...>,
    read copy_connections_from: (self: event<T, U...>, which_is_a: enumitem_connection_variant?, ...event) -> (),
    read disconnect_connection: (self: event<T,U...>, ...connection) -> (),
    read disconnect_all_connections: (self: event<T,U...>, which_is_a: enumitem_connection_variant?) -> (),
    read whose: (self: event<T, U...>, ...connection) -> ...event
]]

class:host(function(new)
	const new = new:as <<event>> (class.type)
	new:set(private.key, setmetatable({}, private.meta))
	new:set(private.waiting_key, {})
end)

do
	type store = {connection}
	type waiting = {[connection]: true}

	private.meta = tables.__mode_vs
	private.key = newproxy()
	private.waiting_key = newproxy()
	private.get_store = function (of: event)
		return of:get(private.key) :: store
	end

	private.get_waiting = function (of: event)
		return of:get(private.waiting_key) :: waiting
	end

	private.attach = function (of: event, on: enumitem?, mode: enumitem_connection_variant, f: any): connection
		const list = private.get_store(of)
		const con = Connection:new({ on = on, deferred_call = false })

		con:notificate(SetupNotification.Install, mode, f)
		con:subscribe(SetupNotification.Disconnected, ConnectionVariant.Once, function ()
			table.remove(list, table.find(list, con) or 0)
		end)
		con.deferred_call = Connection.deferred_call

		table.insert(list, con)
		return con
	end
end

return class
