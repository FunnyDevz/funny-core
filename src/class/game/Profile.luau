--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Reference = require("@class/common/Reference")
const Maybe = require("@class/common/gc/Maybe")
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")
const Observer = require("@class/core/Observer")
const Scheduler = require("@class/core/Scheduler")
const SharedNet = require("@class/service/SharedNet")
const NetPack = require("@class/struct/common/NetPack")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const DataNotification = require("@enums/notification/DataNotification")
const NetNotification = require("@enums/notification/NetNotification")
const UserNotification = require("@enums/notification/UserNotification")
const std = require("@extension/std")
const engine = require("@platform/roblox/engine")
const players = require("@platform/roblox/players")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

type user = {
	joined_at: number?,
	last_seen_at: number?,
	previous_seen_at: number?,
	last_server_id: string?,
	sessions: number?,
	played_time: number?,
	permissions: { [string]: true }?,
	restrictions: { [string]: true }?,
	platforms: { [string]: true }?,
	configurated: { [string]: unknown }?,
	in_server: boolean?,
}

type net_event = event<enumitem_net_notification, netpack>

const private = { type = "profile" }
const class: profile = (Observer :: observer<enumitem_user_notification>):new({
	type = private.type,
	uid = 0,

	get_inlined = ftype:write(function(self: profile, uid: number): profile
		const of, created = private.inline(uid)
		private.boot()

		if created and not engine.is_server then
			private.request({ uid })
		end

		return of
	end, private.type, private.type, types.number),

	get_player = ftype:write(function(self: profile): Player?
		return if self.uid > 0 then players.get_by_user_id(self.uid) else nil
	end, ftype:opt(rbxtypes.Instance), private.type),

	get_reference = ftype:write(function(self: profile): reference<Player?>
		const reference = private.maybe_reference:enactment(self, Reference)
		private.sync_reference(self, reference)
		return reference
	end, Reference.type, private.type),

	get_configurated = ftype:write(function<Y>(self: profile, of: enumitem): Y?
		const configurated = private.read(self).configurated
		return if configurated then configurated[private.key_of(of)] :: any else nil
	end, ftype:opt(mtypes.anyt), private.type, EnumItem.type),

	get_joined_at = ftype:write(function(self: profile): number
		return private.read(self).joined_at or 0
	end, types.number, private.type),

	get_last_seen_at = ftype:write(function(self: profile): number
		return private.read(self).last_seen_at or 0
	end, types.number, private.type),

	get_previous_seen_at = ftype:write(function(self: profile): number
		return private.read(self).previous_seen_at or 0
	end, types.number, private.type),

	get_days_since_previous_seen = ftype:write(function(self: profile): number
		const previous = self:get_previous_seen_at()
		const last = self:get_last_seen_at()

		if previous <= 0 or last <= 0 then
			return 0
		end

		return math.max(math.floor((last - previous) / private.day), 0)
	end, types.number, private.type),

	get_last_server_id = ftype:write(function(self: profile): string?
		const id = private.read(self).last_server_id
		return if id ~= "" then id else nil
	end, ftype:opt(types.string), private.type),

	get_played_time = ftype:write(function(self: profile): number
		const user = private.read(self)
		const last_seen_at = user.last_seen_at or 0
		const session = if self:is_in_server() and last_seen_at > 0 then os.time() - last_seen_at else 0

		return (user.played_time or 0) + math.max(session, 0)
	end, types.number, private.type),

	get_sessions = ftype:write(function(self: profile): number
		return private.read(self).sessions or 0
	end, types.number, private.type),

	get_permissions = ftype:write(function(self: profile, of: enumobject): { enumitem }
		return private.collect(private.read(self).permissions, of)
	end, types.table, private.type, EnumObject.type),

	get_restrictions = ftype:write(function(self: profile, of: enumobject): { enumitem }
		return private.collect(private.read(self).restrictions, of)
	end, types.table, private.type, EnumObject.type),

	set_configurated = ftype:write(function(self: profile, of: enumitem, to: unknown): ()
		const user = private.writable(self)

		if user then
			const configurated = table.clone(user.configurated or {})
			configurated[private.key_of(of)] = to
			private.write(self, "configurated", configurated)
		end
	end, mtypes.never, private.type, EnumItem.type, ftype:opt(mtypes.anyt)),

	set_permissions = ftype:write(function(self: profile, to: boolean, ...: enumitem): ()
		const user = private.writable(self)

		if user then
			private.write(self, "permissions", private.toggle(user.permissions, to, ...))
		end
	end, mtypes.never, private.type, types.boolean, ftype:var(EnumItem.type)),

	set_restrictions = ftype:write(function(self: profile, to: boolean, ...: enumitem): ()
		const user = private.writable(self)

		if user then
			private.write(self, "restrictions", private.toggle(user.restrictions, to, ...))
		end
	end, mtypes.never, private.type, types.boolean, ftype:var(EnumItem.type)),

	set_platform = ftype:write(function(self: profile, to: boolean, ...: enumitem_user_machine_variant): ()
		const user = private.writable(self)

		if user then
			private.write(self, "platforms", private.toggle(user.platforms, to, ...))
		end
	end, mtypes.never, private.type, types.boolean, ftype:var(EnumItem.type)),

	request_data = ftype:write(function(self: profile): ()
		private.boot()

		if not engine.is_server then
			private.request({ self.uid })
		end
	end, mtypes.never, private.type),

	wait_loaded = ftype:write(function(self: profile): ()
		private.boot()

		while not self:is_loaded() and not private.resolved[self] do
			if not coroutine.isyieldable() then
				return
			end

			const scheduler = Scheduler:whose()

			if scheduler then
				scheduler:wait()
			else
				task.wait()
			end
		end
	end, mtypes.never, private.type),

	has_platform = ftype:write(function(self: profile, ...: enumitem_user_machine_variant): boolean
		const platforms = private.read(self).platforms or {}

		for k, v in { ... } do
			if not platforms[private.key_of(v)] then
				return false
			end
		end

		return true
	end, types.boolean, private.type, ftype:var(EnumItem.type)),

	has_restrictions = ftype:write(function(self: profile, ...: enumitem): ...boolean
		return private.contains(private.read(self).restrictions, ...)
	end, ftype:var(types.boolean), private.type, ftype:var(EnumItem.type)),

	has_permissions = ftype:write(function(self: profile, ...: enumitem): ...boolean
		return private.contains(private.read(self).permissions, ...)
	end, ftype:var(types.boolean), private.type, ftype:var(EnumItem.type)),

	is_loaded = ftype:write(function(self: profile): boolean
		return private.source.load(self) ~= nil
	end, types.boolean, private.type),

	is_in_server = ftype:write(function(self: profile): boolean
		return private.read(self).in_server == true
	end, types.boolean, private.type),
})

do
	type source = {
		read load: (of: profile) -> user?,
		read boot: () -> (),
	}

	private.day = 86400
	private.nothing = table.freeze({}) :: user
	private.meta = tables.__mode_vs
	private.booted = false
	private.net = nil :: net_event?
	private.queue = {} :: { number }
	private.request_limit = 64
	private.request_cooldown = 0.25
	private.flushing = false :: boolean
	private.requested = setmetatable({} :: { [Player]: number }, tables.__mode_ks)
	private.profiles = setmetatable({} :: { [number]: profile }, private.meta)
	private.online = {} :: { [number]: profile }
	private.ready = setmetatable({} :: { [Player]: true }, tables.__mode_ks)
	private.snapshots = setmetatable({} :: { [profile]: user }, tables.__mode_ks)
	private.resolved = setmetatable({} :: { [profile]: true }, tables.__mode_ks)
	private.maybe_reference = Maybe:new() :: maybe<reference<Player?>, profile>

	private.inline = function(uid: number): (profile, boolean)
		const existing = private.profiles[uid]

		if existing then
			return existing, false
		end

		const new = class:new({ uid = uid }) :: profile
		private.profiles[uid] = new
		return new, true
	end

	private.key_of = function(item: enumitem): string
		const enum = item.enum :: enumobject?
		return if enum then `{enum.name}.{item.name}` else item.name
	end

	private.read = function(of: profile): user
		return private.source.load(of) or private.nothing
	end

	private.collect = function(from: { [string]: true }?, of: enumobject): { enumitem }
		const result: { enumitem } = {}
		const from = from or {}

		for k, v in of:get_enums_list() do
			if from[private.key_of(v)] then
				table.insert(result, v)
			end
		end

		return result
	end

	private.contains = function(from: { [string]: true }?, ...: enumitem): ...boolean
		const result: { boolean } = {}
		const from = from or {}

		for k, v in { ... } do
			table.insert(result, from[private.key_of(v)] == true)
		end

		return unpack(result)
	end

	private.toggle = function(from: { [string]: true }?, to: boolean, ...: enumitem): { [string]: true }
		const result = table.clone(from or {})

		for k, v in { ... } do
			result[private.key_of(v)] = if to then true else nil
		end

		return result
	end

	private.sync_reference = function(of: profile, reference: reference<Player?>)
		const player = of:get_player()

		if reference:get_instance() ~= player then
			reference:set_instance(player)
		end
	end

	private.refresh = function(of: profile)
		if private.maybe_reference:exist(of) then
			private.sync_reference(of, of:get_reference())
		end
	end

	private.plan = function(f: () -> ())
		const scheduler = Scheduler:whose()

		if scheduler then
			scheduler:plan(f)
		else
			task.defer(f)
		end
	end

	private.boot = function()
		if private.booted then
			return
		end

		private.booted = true
		private.plan(private.source.boot)
	end

	private.writable = function(of: profile): user?
		if not std:check(engine.is_server, "profile is read-only on the client") then
			return nil
		end

		const succ, user = std:check(private.source.load(of), `profile {of.uid} isn't loaded`)
		return if succ then user else nil
	end

	private.write = function(of: profile, key: string, to: unknown)
		const player = of:get_player()

		if not player then
			return
		end

		private.DataServer:set_value(player, { "user", key }, to)
		of:notificate(UserNotification.ServerDataChanged, key, to)
		private.broadcast(of)
	end

	private.snapshot = function(of: profile, for_owner: boolean): user?
		const user = private.source.load(of)

		if not user then
			return nil
		end

		if not for_owner then
			user.configurated = nil
		end

		return user
	end

	private.send = function(to: Player, of: profile)
		const net = private.net

		if not net or not private.ready[to] then
			return
		end

		const snapshot = private.snapshot(of, to.UserId == of.uid)

		if snapshot then
			SharedNet:emit_event(net, NetPack:pack({ to }, "snapshot", of.uid, snapshot))
		else
			SharedNet:emit_event(net, NetPack:pack({ to }, "exit", of.uid))
		end
	end

	private.broadcast = function(of: profile)
		for k, v in private.ready do
			private.send(k, of)
		end
	end

	private.flush = nil :: any

	private.request = function(uids: { number }?)
		const net = private.net

		if uids == nil then
			if net then
				SharedNet:emit_event(net, NetPack:pack(nil, "request", nil))
			end
			return
		end

		for k, v in uids do
			if not table.find(private.queue, v) then
				table.insert(private.queue, v)
			end
		end

		if net and not private.flushing then
			private.flushing = true
			private.plan(private.flush)
		end
	end

	private.flush = function()
		const net = private.net

		if not net or #private.queue == 0 then
			private.flushing = false
			return
		end

		const batch: { number } = {}

		for k = 1, math.min(#private.queue, private.request_limit) do
			table.insert(batch, table.remove(private.queue, 1) :: number)
		end

		SharedNet:emit_event(net, NetPack:pack(nil, "request", batch))

		if #private.queue > 0 then
			task.delay(private.request_cooldown, private.flush)
		else
			private.flushing = false
		end
	end

	private.send_exit = function(to: Player, uid: number)
		const net = private.net

		if net and private.ready[to] then
			SharedNet:emit_event(net, NetPack:pack({ to }, "exit", uid))
		end
	end

	private.server = table.freeze({
		load = function(of: profile): user?
			const player = of:get_player()
			const data = if player then private.DataServer:get_data(player) else nil
			const user = if data then data.user else nil

			if type(user) ~= types.table then
				return nil
			end

			const view = table.clone(user) :: user
			view.in_server = private.online[of.uid] ~= nil
			return view
		end,

		boot = function()
			const net = SharedNet:get_event(SharedNetLink.Profile)
			const data_event = private.DataServer:get_data_event()
			private.net = net

			net:connect(NetNotification.Received, function(pack: netpack)
				const sender = if pack.sender then players.get_by_user_id(pack.sender) else nil
				const action, uids = pack:payload()

				if not sender or action ~= "request" then
					return
				end

				if uids == nil then
					if private.ready[sender] then
						return
					end

					private.ready[sender] = true

					for k, v in private.online do
						private.send(sender, v)
					end

					return
				end

				if not private.ready[sender] or type(uids) ~= types.table then
					return
				end

				const now = os.clock()

				if now - (private.requested[sender] or -math.huge) < private.request_cooldown then
					return
				end

				private.requested[sender] = now

				const list = uids :: { unknown }

				for k = 1, math.min(#list, private.request_limit) do
					const v = list[k]

					if type(v) ~= types.number or v ~= math.floor(v :: number) or (v :: number) <= 0 then
						continue
					end

					const of = private.online[v :: number]

					if of then
						of:notificate(UserNotification.ServerDataRequest, sender)
						private.send(sender, of)
					else
						private.send_exit(sender, v :: number)
					end
				end
			end)

			data_event:connect(DataNotification.DataLoaded, function(player: any)
				private.server.join(player)
			end)

			data_event:connect(DataNotification.DataReleased, function(player: any)
				private.server.exit(player)
			end)

			for k, v in players.get_all() do
				if private.DataServer:get_data(v) then
					private.server.join(v)
				end
			end
		end,

		join = function(player: Player)
			const of = private.inline(player.UserId)

			private.online[of.uid] = of
			private.refresh(of)
			of:notificate(UserNotification.ServerJoin, player)
			private.broadcast(of)
		end,

		exit = function(player: Player)
			const of = private.profiles[player.UserId]
			private.ready[player] = nil

			if not of then
				return
			end

			private.online[of.uid] = nil
			private.refresh(of)
			of:notificate(UserNotification.ServerExit, player)
			private.broadcast(of)
		end,
	}) :: source & {
		read join: (player: Player) -> (),
		read exit: (player: Player) -> (),
	}

	private.client = table.freeze({
		load = function(of: profile): user?
			return private.snapshots[of]
		end,

		boot = function()
			const net = SharedNet:get_event(SharedNetLink.Profile)

			net:connect(NetNotification.Received, function(pack: netpack)
				const action, uid, snapshot = pack:payload()

				if type(uid) ~= types.number then
					return
				end

				if action == "snapshot" and type(snapshot) == types.table then
					private.client.apply(uid :: number, snapshot :: user)
				elseif action == "exit" then
					private.client.exit(uid :: number)
				end
			end)

			private.net = net
			private.request(nil)

			if #private.queue > 0 and not private.flushing then
				private.flushing = true
				task.delay(private.request_cooldown, private.flush)
			end
		end,

		apply = function(uid: number, snapshot: user)
			const of = private.inline(uid)
			const previous = private.snapshots[of]

			private.snapshots[of] = snapshot
			private.resolved[of] = true
			private.refresh(of)

			if snapshot.in_server and not (previous and previous.in_server) then
				of:notificate(UserNotification.ServerJoin)
			end

			of:notificate(UserNotification.ServerDataChanged)
		end,

		exit = function(uid: number)
			const of = private.inline(uid)
			const previous = private.snapshots[of]

			private.resolved[of] = true

			if previous then
				const snapshot = table.clone(previous)
				snapshot.in_server = false
				private.snapshots[of] = snapshot
			end

			private.refresh(of)

			if previous and previous.in_server then
				of:notificate(UserNotification.ServerExit)
			end
		end,
	}) :: source & {
		read apply: (uid: number, snapshot: user) -> (),
		read exit: (uid: number) -> (),
	}

	private.DataServer = if engine.is_server then require("@class/service/DataServer") else nil :: never
	private.source = if engine.is_server then private.server else private.client :: source

	if engine.is_server then
		private.boot()
	end
end

return class
