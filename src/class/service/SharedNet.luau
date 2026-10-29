--!strict
const Event = require("@class/common/signal/Event")
const Service = require("@class/core/Service")
const NetPack = require("@class/struct/common/NetPack")
const tables = require("@declare/tables")
const types = require("@declare/types")
const NetSource = require("@enums/descriptor/NetSource")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const SharedNetVariant = require("@enums/descriptor/SharedNetVariant")
const NetNotification = require("@enums/notification/NetNotification")
const stdout = require("@extension/stdout")
const engine = require("@platform/roblox/engine")
const network = require("@platform/roblox/network")
const players = require("@platform/roblox/players")
const SharedNetPref = require("@setting/SharedNetPref")
const ftype = require("@static/ftype")

type net_event = event<enumitem_net_notification, netpack>
type metadata = {
	variant: enumitem_shared_net_variant,
	link: enumitem_shared_net_link,
	instance: Instance,
}

const private = {}
const class: sharednet = Service:new({
	type = "sharednet",
	name = "SharedNet",
	timeout = 5,
	emitted = 0,
	errors = 0,

	get_event = ftype:write(
		function(self: sharednet, link: enumitem_shared_net_link, variant: enumitem_shared_net_variant?): net_event
			const kind = variant or SharedNetVariant.Safe

			if not SharedNetLink:is_my_enumitem(link) or not SharedNetVariant:is_my_enumitem(kind) then
				self.errors += 1
				stdout:oute("unexpected SharedNetLink or SharedNetVariant")
				return Event:new() :: any
			end

			const name = `{link.name}@{kind.name}`
			const existing = private.events[name]
			if existing then
				return existing
			end

			const event = Event:new() :: net_event
			const instance = private.get_instance(self, kind, name)

			private.events[name] = event
			private.metadata[event] = { variant = kind, link = link, instance = instance }
			private.setup_behaviour(event, instance)

			return event
		end,
		"event",
		"sharednet",
		"enumitem",
		ftype:opt("enumitem")
	),

	emit_event = ftype:write(function(self: sharednet, event: net_event, pack: netpack): ()
		const metadata = private.metadata[event]

		if not metadata then
			self.errors += 1
			stdout:oute("unknown event, take it from SharedNet:get_event")
			return
		end

		const flat = pack:get_flat()
		if engine.is_server then
			flat.from = NetSource.FromServer.name
			flat.sender = nil
		end

		network.fire(metadata.instance, pack:get_players(), flat)

		if pack.rpc and not network.is_local(metadata.instance) then
			event:invoke(NetNotification.Received, pack)
		end

		self.emitted += 1
	end, types["nil"], "sharednet", "event", "netpack"),
})

do
	private.events = {} :: { [string]: net_event }
	private.metadata = setmetatable({} :: { [net_event]: metadata }, tables.__mode_ks)

	function private.get_instance(that: sharednet, variant: enumitem_shared_net_variant, name: string): Instance
		const folder = network.get_folder(SharedNetPref.deploy_placement_name, that.timeout)
		const existing = network.find_remote(folder, name)

		if existing then
			return existing
		end

		if engine.is_server or variant == SharedNetVariant.Internal then
			return network.create_remote(folder, name, SharedNetVariant:get_variant(variant))
		end

		const found = network.find_remote(folder, name, that.timeout)
		if found then
			return found
		end

		that.errors += 1
		stdout:oute(`{name} wasn't created by the server, replaced with a local event`)
		return network.create_remote(nil, name, "BindableEvent")
	end

	function private.setup_behaviour(event: net_event, instance: Instance)
		network.listen(instance, function(sender: Player?, flat: unknown)
			if not sender then
				const pack = NetPack:from_flat(flat)

				if pack then
					event:invoke(NetNotification.Received, pack)
				end
				return
			end

			if type(flat) == types.table and (flat :: any).from == NetSource.FromServer.name then
				players.kick(sender, "Invalid network packet")
				return
			end

			const pack = NetPack:from_flat(flat)
			if pack then
				event:invoke(
					NetNotification.Received,
					pack:clone({ from = NetSource.FromClient.name, sender = sender.UserId })
				)
			end
		end)
	end
end

return class
