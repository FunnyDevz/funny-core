--!strict
const Event = require("@class/common/signal/Event")
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")
const Service = require("@class/core/Service")
const NetPack = require("@class/struct/common/NetPack")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const NetSource = require("@enums/descriptor/NetSource")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const SharedNetVariant = require("@enums/descriptor/SharedNetVariant")
const NetNotification = require("@enums/notification/NetNotification")
const std = require("@extension/std")
const ttable = require("@extension/ttable")
const engine = require("@platform/roblox/engine")
const network = require("@platform/roblox/network")
const players = require("@platform/roblox/players")
const ftype = require("@static/ftype")

type net_event = event<enumitem_net_notification, netpack>
type bucket = {
	tokens: number,
	time: number,
	dropped: number,
	window: number,
}

type metadata = {
	variant: enumitem_shared_net_variant,
	link: enumitem,
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
		function(self: sharednet, link: enumitem, variant: enumitem_shared_net_variant?): net_event
			const kind = variant or SharedNetVariant.Safe

			if not self:has_link(link) or not SharedNetVariant:is_my_enumitem(kind) then
				self.errors += 1
				std:oute("unexpected link or SharedNetVariant, register the link enum with SharedNet:register_links")
				return Event:new() :: any
			end

			const name = `{(link.enum :: enumobject).name}.{link.name}@{kind.name}`
			const existing = private.events[name]
			if existing then
				return existing
			end

			const event = Event:new() :: net_event
			const instance = private.get_instance(self, kind, name)

			private.events[name] = event
			private.metadata[event] = { variant = kind, link = link, instance = instance }
			private.setup_behaviour(event, instance, name)

			return event
		end,
		"event",
		"sharednet",
		"enumitem",
		ftype:opt("enumitem")
	),

	register_links = ftype:write(function(self: sharednet, ...: enumobject): ()
		for k, v in { ... } do
			if not std:check(self:that(v, EnumObject.type), "SharedNet links must be an enumobject") then
				continue
			end

			if not table.find(private.links, v) then
				table.insert(private.links, v)
			end
		end
	end, mtypes.never, "sharednet", ftype:var(EnumObject.type)),

	has_link = ftype:write(function(self: sharednet, link: enumitem): boolean
		if not self:that(link, EnumItem.type) then
			return false
		end

		for k, v in private.links do
			if v:is_my_enumitem(link) then
				return true
			end
		end

		return false
	end, types.boolean, "sharednet", EnumItem.type),

	set_env = ftype:write(function(self: sharednet, env: any): sharednet_env
		if not std:check(engine.is_server, "SharedNet env can be set only on the server") then
			return private.get_env()
		end

		if not std:check(next(private.events) == nil, "SharedNet env can't be changed after the first event") then
			return private.env
		end

		if type(env) == types["function"] then
			const succ, result = pcall(env, ttable.copy(private.env))

			if std:check(succ and type(result) == types.table, `SharedNet env function must return a table, got {result}`) then
				private.env = result
			end
		elseif std:check(type(env) == types.table, "SharedNet env must be a table or a function") then
			private.env = ttable.merge(private.env, env)
		end

		private.publish()
		return private.env
	end, types.table, "sharednet", ftype:uor(types.table, types["function"])),

	get_env = ftype:write(function(self: sharednet): sharednet_env
		return private.get_env()
	end, types.table, "sharednet"),

	emit_event = ftype:write(function(self: sharednet, event: net_event, pack: netpack): ()
		const metadata = private.metadata[event]

		if not metadata then
			self.errors += 1
			std:oute("unknown event, take it from SharedNet:get_event")
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
	private.env = {
		max_network_packages = 4,
		deploy_placement_name = "shared_net_placement",
		rate_limit = 60,
		rate_burst = 120,
		rate_kick = 600,
	} :: sharednet_env
	private.buckets = setmetatable({} :: { [Player]: { [string]: bucket } }, tables.__mode_ks)
	private.replicated = nil :: sharednet_env?
	private.links = { SharedNetLink } :: { enumobject }
	private.events = {} :: { [string]: net_event }
	private.metadata = setmetatable({} :: { [net_event]: metadata }, tables.__mode_ks)

	function private.attribute(key: string): string
		return `sharednet_{key}`
	end

	function private.publish()
		for k, v in private.env :: { [string]: unknown } do
			network.set_shared_attribute(private.attribute(k), v)
		end
	end

	function private.get_env(): sharednet_env
		if engine.is_server then
			return private.env
		end

		if private.replicated then
			return private.replicated
		end

		const env = table.clone(private.env) :: { [string]: unknown }

		for k, v in private.env :: { [string]: unknown } do
			const value = network.get_shared_attribute(private.attribute(k))

			if value ~= nil and type(value) == type(v) then
				env[k] = value
			end
		end

		const replicated = table.freeze(env) :: sharednet_env
		private.replicated = replicated
		return replicated
	end

	function private.get_instance(that: sharednet, variant: enumitem_shared_net_variant, name: string): Instance
		const folder = network.get_folder(private.get_env().deploy_placement_name, that.timeout)
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
		std:oute(`{name} wasn't created by the server, replaced with a local event`)
		return network.create_remote(nil, name, "BindableEvent")
	end

	function private.limit(pack: netpack?): netpack?
		const max = private.get_env().max_network_packages

		if pack and pack.count > max then
			return pack:clone({ count = max })
		end

		return pack
	end

	function private.allow(sender: Player, name: string): boolean
		const env = private.get_env()
		const now = os.clock()
		const buckets = private.buckets[sender] or {}
		private.buckets[sender] = buckets

		local bucket = buckets[name]

		if not bucket then
			bucket = { tokens = env.rate_burst, time = now, dropped = 0, window = now }
			buckets[name] = bucket
		end

		bucket.tokens = math.min(env.rate_burst, bucket.tokens + (now - bucket.time) * env.rate_limit)
		bucket.time = now

		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end

		if now - bucket.window >= 1 then
			bucket.window = now
			bucket.dropped = 0
		end

		bucket.dropped += 1

		if env.rate_kick > 0 and bucket.dropped >= env.rate_kick then
			players.kick(sender, "Too many network packets")
		end

		return false
	end

	function private.setup_behaviour(event: net_event, instance: Instance, name: string)
		network.listen(instance, function(sender: Player?, flat: unknown)
			if not sender then
				const pack = private.limit(NetPack:from_flat(flat))

				if pack then
					event:invoke(NetNotification.Received, pack)
				end
				return
			end

			if not private.allow(sender, name) then
				return
			end

			if type(flat) == types.table and (flat :: any).from == NetSource.FromServer.name then
				players.kick(sender, "Invalid network packet")
				return
			end

			const pack = private.limit(NetPack:from_flat(flat))
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
