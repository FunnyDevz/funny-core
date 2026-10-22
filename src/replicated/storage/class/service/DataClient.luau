--!strict
const Service = require("@game/ReplicatedStorage/class/core/Service")
const Event = require("@game/ReplicatedStorage/class/common/signal/Event")
const SharedNet = require("@game/ReplicatedStorage/class/service/SharedNet")
const NetPack = require("@game/ReplicatedStorage/class/struct/common/NetPack")
const SharedNetLink = require("@game/ReplicatedStorage/enums/descriptor/SharedNetLink")
const DataNotification = require("@game/ReplicatedStorage/enums/notification/DataNotification")
const NetNotification = require("@game/ReplicatedStorage/enums/notification/NetNotification")
const DataState = require("@game/ReplicatedStorage/enums/state/DataState")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

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
	end, declare["nil"], "dataclient"),

	get_state = ftype:write(function(self: dataclient): enumitem_data_state
		return private.state
	end, "enumitem", "dataclient"),

	get_value = ftype:write(function<T>(self: dataclient, path: data_path): T
		local node: any = private.data

		for k, v in private.split(path) do
			if type(node) ~= declare.table then
				return nil :: any
			end

			node = node[v]
		end

		return node
	end, ftype:opt(declare.anyt), "dataclient", ftype:uor(declare.string, declare.table)),

	wait_loaded = ftype:write(function(self: dataclient): ()
		if private.state ~= DataState.ProfileLoaded then
			private.event:wait(DataNotification.DataLoaded)
		end
	end, declare["nil"], "dataclient"),

	get_data_event = ftype:write(function(self: dataclient): data_event
		return private.event
	end, "event", "dataclient"),
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
		if type(path) == declare.table then
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

			if type(node) ~= declare.table then
				project.console_out_error(`bad replicated path {table.concat(segments, "/")}`)
				return
			end
		end

		node[segments[#segments]] = to
		private.event:invoke(DataNotification.DataChanged, table.concat(segments, "/"), to)
	end
end

return class
