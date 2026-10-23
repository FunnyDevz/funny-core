--!strict
const Connection = require("@class/common/signal/Connection")
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const SetupNotification = require("@enums/notification/SetupNotification")
const Cryptography = require("@import/Cryptography")
const ftype = require("@static/ftype")

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
	end, Connection.type, "event", ftype:opt(EnumItem.type), ftype:uor("observer", types["function"], types.thread)),

	once = ftype:write(function(self: event, on: enumitem?, f: any): connection
		const list = private.get_store(self)
		const con = Connection:new({ on = on or self.on})

		con:notificate(SetupNotification.Install, ConnectionVariant.Once, f)
		con:subscribe(SetupNotification.Disconnected, ConnectionVariant.Once, function ()
			table.remove(list, table.find(list, con) or 0)
		end)

		table.insert(list, con)
		return con
	end, Connection.type, "event", ftype:opt(EnumItem.type), ftype:uor("observer", types["function"], types.thread)),

	wait = ftype:write(function(self: event, on: enumitem?): ...any
		const to = (on or self.on or DefaultVariant.Unknown) :: enumitem

		self:once(to, coroutine.running())
		return coroutine.yield()
	end, ftype:var(mtypes.anyt), "event", ftype:opt(EnumItem.type)),

	invoke = ftype:write(function(self: event, call: enumitem, ...: any): ()
		const list = private.get_store(self)

		for _, v in list do
			v:notificate(SetupNotification.Require, call, ...)
		end 
	end, mtypes.never, "event", EnumItem.type, ftype:var_opt(mtypes.anyt)),
})

class:host(function(new)
	const new = new:as <<event>> (class.type)
	new:set(private.key, setmetatable({}, private.meta))
end)

do
	type store = {connection}

	private.meta = tables.__mode_vs
	private.key =  Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "event_store_code")
	private.get_store = function (of: event)
		return of:get(private.key) :: store
	end
end

return class
