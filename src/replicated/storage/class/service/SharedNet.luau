--!strict
const Service = require("@game/ReplicatedStorage/class/core/Service")
const Event = require("@game/ReplicatedStorage/class/common/signal/Event")
const NetPack = require("@game/ReplicatedStorage/class/struct/common/NetPack")
const NetSource = require("@game/ReplicatedStorage/enums/descriptor/NetSource")
const SharedNetLink = require("@game/ReplicatedStorage/enums/descriptor/SharedNetLink")
const SharedNetVariant = require("@game/ReplicatedStorage/enums/descriptor/SharedNetVariant")
const NetNotification = require("@game/ReplicatedStorage/enums/notification/NetNotification")
const engine = require("@game/ReplicatedStorage/platform/engine")
const network = require("@game/ReplicatedStorage/platform/network")
const players = require("@game/ReplicatedStorage/platform/players")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const FOLDER = "sharednet"

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

	get_event = ftype:write(function(self: sharednet, link: enumitem_shared_net_link, variant: enumitem_shared_net_variant?): net_event
		const kind = variant or SharedNetVariant.Safe

		if not SharedNetLink:is_my_enumitem(link) or not SharedNetVariant:is_my_enumitem(kind) then
			self.errors += 1
			project.console_out_error("unexpected SharedNetLink or SharedNetVariant")
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
	end, "event", "sharednet", "enumitem", ftype:opt("enumitem")),

	emit_event = ftype:write(function(self: sharednet, event: net_event, pack: netpack): ()
		const metadata = private.metadata[event]

		if not metadata then
			self.errors += 1
			project.console_out_error("unknown event, take it from SharedNet:get_event")
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
	end, declare["nil"], "sharednet", "event", "netpack"),
})

do
	private.events = {} :: { [string]: net_event }
	private.metadata = setmetatable({} :: { [net_event]: metadata }, declare.tables.__mode_ks)

	function private.get_instance(that: sharednet, variant: enumitem_shared_net_variant, name: string): Instance
		const folder = network.get_folder(FOLDER, that.timeout)
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
		project.console_out_error(`{name} wasn't created by the server, replaced with a local event`)
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

			if type(flat) == declare.table and (flat :: any).from == NetSource.FromServer.name then
				players.kick(sender, "Invalid network packet")
				return
			end

			const pack = NetPack:from_flat(flat)
			if pack then
				event:invoke(NetNotification.Received, pack:clone({ from = NetSource.FromClient.name, sender = sender.UserId }))
			end
		end)
	end
end

return class
