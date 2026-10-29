--!strict
const Event = require("@class/common/signal/Event")
const EnumItem = require("@class/core/EnumItem")
const Service = require("@class/core/Service")
const SharedNet = require("@class/service/SharedNet")
const NetPack = require("@class/struct/common/NetPack")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const DataNotification = require("@enums/notification/DataNotification")
const NetNotification = require("@enums/notification/NetNotification")
const DataState = require("@enums/state/DataState")
const stdout = require("@extension/stdout")
const ftype = require("@static/ftype")

type data_event = event<enumitem_data_notification, ...any>

const private = {}
const class: dataclient = Service:new({
	type = "dataclient",
	name = "DataClient",

	start = ftype:write(function(self: dataclient): ()
		if self.enabled then
			return
		end

		self.enabled = true
		task.spawn(private.connect)
	end, mtypes.never, "dataclient"),

	get_state = ftype:write(function(self: dataclient): enumitem_data_state
		return private.state
	end, EnumItem.type, "dataclient"),

	get_value = ftype:write(function<T>(self: dataclient, path: data_path): T
		local node: any = private.data

		for k, v in private.split(path) do
			if type(node) ~= types.table then
				return nil :: any
			end

			node = node[v]
		end

		return node
	end, ftype:opt(mtypes.anyt), "dataclient", ftype:uor(types.string, types.table)),

	wait_loaded = ftype:write(function(self: dataclient): ()
		if private.state ~= DataState.ProfileLoaded then
			private.event:wait(DataNotification.DataLoaded)
		end
	end, mtypes.never, "dataclient"),

	get_data_event = ftype:write(function(self: dataclient): data_event
		return private.event
	end, Event.type, "dataclient"),
})

do
	private.state = DataState.ProfileLoading :: enumitem_data_state
	private.data = {} :: data_snapshot
	private.event = Event:new() :: data_event

	function private.connect()
		const net = SharedNet:get_event(SharedNetLink.Data)

		net:connect(NetNotification.Received, function(pack: netpack)
			const action, a, b = pack:payload()

			if action == "snapshot" then
				private.apply_snapshot(a)
			elseif action == "set" then
				private.apply_set(a, b)
			end
		end)

		SharedNet:emit_event(net, NetPack:pack(nil, "ready"))
	end

	function private.split(path: data_path): { string }
		if type(path) == types.table then
			return path :: { string }
		end

		return string.split(path :: string, "/")
	end

	function private.apply_snapshot(snapshot: data_snapshot)
		private.data = snapshot

		for k, v in snapshot do
			private.event:invoke(DataNotification.DataChanged, k, v)
		end

		if private.state ~= DataState.ProfileLoaded then
			private.state = DataState.ProfileLoaded
			private.event:invoke(DataNotification.DataLoaded)
		end
	end

	function private.apply_set(segments: { string }, to: unknown)
		local node: any = private.data

		for k = 1, #segments - 1 do
			node = node[segments[k]]

			if type(node) ~= types.table then
				stdout:oute(`bad replicated path {table.concat(segments, "/")}`)
				return
			end
		end

		node[segments[#segments]] = to
		private.event:invoke(DataNotification.DataChanged, table.concat(segments, "/"), to)
	end
end

return class
