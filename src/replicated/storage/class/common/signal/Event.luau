--!strict

const Observer = require("@game/ReplicatedStorage/class/core/Observer")
const Connection = require("@game/ReplicatedStorage/class/common/signal/Connection")
const SecurityRNG = require("@game/ReplicatedStorage/class/service/SecurityRNG")
const ConnectionVariant = require("@game/ReplicatedStorage/enums/descriptor/ConnectionVariant")
const DefaultVariant = require("@game/ReplicatedStorage/enums/descriptor/DefaultVariant")
const SetupNotification = require("@game/ReplicatedStorage/enums/notification/SetupNotification")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")

const private = {}
const class: event = (Observer :: observer<enumitem<any>>):new({
	type = "event",
	on = DefaultVariant.Unknown,

	connect = ftype:write(function(self: event, on: enumitem?, f: any): connection
		const list = private.get_store(self)
		const con = Connection:new({ on = on or self.on})
		con:notificate(SetupNotification.Install, ConnectionVariant.Ever, f)
		con:subscribe(SetupNotification.Disconnected, ConnectionVariant.Once, function ()
			table.remove(list, table.find(list, con) or 0)
		end)

		table.insert(list, con)
		return con
	end, "connection", "event", ftype:opt("enumitem"), ftype:uor("observer", declare["function"], declare.thread)),

	once = ftype:write(function(self: event, on: enumitem?, f: any): connection
		const list = private.get_store(self)
		const con = Connection:new({ on = on or self.on})

		con:notificate(SetupNotification.Install, ConnectionVariant.Once, f)
		con:subscribe(SetupNotification.Disconnected, ConnectionVariant.Once, function ()
			table.remove(list, table.find(list, con) or 0)
		end)

		table.insert(list, con)
		return con
	end, "connection", "event", ftype:opt("enumitem"), ftype:uor("observer", declare["function"], declare.thread)),

	wait = ftype:write(function(self: event, on: enumitem?): ...any
		const to = (on or self.on or DefaultVariant.Unknown) :: enumitem

		self:once(to, coroutine.running())
		return coroutine.yield()
	end, ftype:var(declare.anyt), "event", ftype:opt("enumitem")),

	invoke = ftype:write(function(self: event, call: enumitem, ...: any): ()
		const list = private.get_store(self)

		for _, v in list do
			v:notificate(SetupNotification.Require, call, ...)
		end 
	end, declare["nil"], "event", "enumitem", ftype:var_opt(declare.anyt)),
})

class:host(function(new)
	const new = new:as <<event>> (class.type)
	new:set(private.key, setmetatable({}, private.meta))
end)

do
	type store = {connection}

	private.meta = table.freeze {__mode = "vs"}
	private.key =  SecurityRNG:get_hash_sha256("event_store_code")
	private.get_store = function (of: event)
		return of:get(private.key) :: store
	end
end

return class
