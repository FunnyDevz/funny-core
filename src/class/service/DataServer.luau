--!strict
const Event = require("@class/common/signal/Event")
const EnumItem = require("@class/core/EnumItem")
const Scheduler = require("@class/core/Scheduler")
const Service = require("@class/core/Service")
const SharedNet = require("@class/service/SharedNet")
const NetPack = require("@class/struct/common/NetPack")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const DataInternalVariant = require("@enums/descriptor/DataInternalVariant")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const DataNotification = require("@enums/notification/DataNotification")
const NetNotification = require("@enums/notification/NetNotification")
const DataState = require("@enums/state/DataState")
const std = require("@extension/std")
const ttable = require("@extension/ttable")
const engine = require("@platform/roblox/engine")
const ProfileStore = engine.is_server and require("@include/ProfileStore") or nil
const players = require("@platform/roblox/players")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

type profile = any
type data_event = event<enumitem_data_notification, ...any>

const private = { type = "dataserver", active = false }
const class: dataserver = Service:new({
	type = private.type,
	name = "DataServer",

	start = ftype:write(function(self: dataserver): ()
		if self.enabled then
			return
		end

		if not ProfileStore then
			--#if DEBUG
			std:oute("DataServer cannot be called on the client, womp.")
			--#endif
			
			return
		end

		const succ, store =
			std:check(private.env.store, "DataServer env.store isn't set, call DataServer:set_env before start")
		if not succ then
			return
		end
		if private.active then
			return
		end

		self.enabled = true
		private.active = true

		private.template = private.env.template
		private.store = ProfileStore.New(store :: string, private.template :: any)

		const event = SharedNet:get_event(SharedNetLink.Data)
		private.net = event

		event:connect(NetNotification.Received, function(pack: netpack)
			const player = if pack.sender then players.get_by_user_id(pack.sender) else nil

			if player and not private.ready[player] and pack:payload() == DataInternalVariant.DataReady.hashlink then
				private.ready[player] = true
				private.send_snapshot(player)
			end
		end)

		players.on_added(private.player_added)
		players.on_removing(private.player_removing)
		const all = players.get_all()
		const scheduler = Scheduler:whose()

		if scheduler then
			for _, v in all do
				scheduler:plan(private.player_added, v)
			end
		else
			for _, v in all do
				task.spawn(private.player_added, v)
			end
		end
	end, mtypes.never, private.type),

	set_env = ftype:write(function(self: dataserver, env: any): dataserver_env
		if not std:check(engine.is_server, "DataServer env can be set only on the server") then
			return private.env
		end
		if not std:check(not self.enabled, "DataServer env can't be changed after start") then
			return private.env
		end

		if type(env) == types["function"] then
			const succ, result = pcall(env, ttable.copy(private.env))

			if
				std:check(
					succ and type(result) == types.table,
					`DataServer env function must return a table, got {result}`
				)
			then
				private.env = result
			end
		elseif std:check(type(env) == types.table, "DataServer env must be a table or a function") then
			private.env = ttable.merge(private.env, env)
		end

		return private.env
	end, types.table, private.type, ftype:uor(types.table, types["function"])),

	get_env = ftype:write(function(self: dataserver): dataserver_env
		return private.env
	end, types.table, private.type),

	get_state = ftype:write(function(self: dataserver, player: Player): enumitem_data_state
		return private.states[player] or DataState.ProfileReleased
	end, EnumItem.type, private.type, rbxtypes.Instance),

	get_data = ftype:write(function(self: dataserver, player: Player): data_snapshot?
		const profile = private.profiles[player]
		return if profile then profile.Data else nil
	end, ftype:opt(types.table), private.type, rbxtypes.Instance),

	wait_data = ftype:write(function(self: dataserver, player: Player): data_snapshot?
		while private.states[player] == DataState.ProfileLoading do
			private.event:wait(DataNotification.DataStateChanged)
		end

		return self:get_data(player)
	end, ftype:opt(types.table), private.type, rbxtypes.Instance),

	get_value = ftype:write(function<T>(self: dataserver, player: Player, path: data_path): T
		const snapshot = self:get_data(player)

		if not std:check(snapshot, `{player.Name}'s data isn't loaded`) then
			return nil :: any
		end

		const parent, key = private.resolve(snapshot :: data_snapshot & exist, private.split(path))
		return parent[key]
	end, ftype:opt(mtypes.anyt), private.type, rbxtypes.Instance, ftype:uor(types.string, types.table)),

	set_value = ftype:write(function(self: dataserver, player: Player, path: data_path, to: unknown): ()
		const snapshot = self:get_data(player)

		if not std:check(snapshot, `{player.Name}'s data isn't loaded`) then
			return
		end

		const segments = private.split(path)
		const parent, key = private.resolve(snapshot :: data_snapshot & exist, segments)
		parent[key] = to
		private.replicate(player, segments, to)
	end, mtypes.never, private.type, rbxtypes.Instance, ftype:uor(types.string, types.table), ftype:opt(mtypes.anyt)),

	update_value = ftype:write(
		function<T>(self: dataserver, player: Player, path: data_path, f: (current: T) -> T): T
			const next_value = f(self:get_value(player, path))
			self:set_value(player, path, next_value)
			return next_value
		end,
		ftype:opt(mtypes.anyt),
		private.type,
		rbxtypes.Instance,
		ftype:uor(types.string, types.table),
		types["function"]
	),

	reset = ftype:write(function(self: dataserver, player: Player): boolean
		const profile = private.profiles[player]

		if not profile then
			return false
		end

		profile.Data = private.deep_copy(private.template)
		private.send_snapshot(player)
		return true
	end, types.boolean, private.type, rbxtypes.Instance),

	send_message = ftype:write(function(self: dataserver, user_id: number, message: { [string]: any }): boolean
		const store = private.get_store()
		const succ, err = pcall(store.MessageAsync, store, private.env.key(user_id), message)

		--#if DEBUG
		if not succ then
			std:outw(`data failed to send a message to {user_id}:`, err)
		end
		--#endif

		return succ
	end, types.boolean, private.type, types.number, types.table),

	get_data_event = ftype:write(function(self: dataserver): data_event
		return private.event
	end, Event.type, private.type),
})

do
	private.env = {
		key = function(id: number): string
			return `player_{id}`
		end,
		template = {
			user = {
				joined_at = 0,
				last_seen_at = 0,
				previous_seen_at = 0,
				last_server_id = "",
				sessions = 0,
				played_time = 0,
				permissions = {},
				restrictions = {},
				platforms = {},
				configurated = {},
			},
		},
		replicating = {},
		studio = { mock = false },
	} :: dataserver_env
	private.template = {} :: data_snapshot
	private.meta = tables.__mode_ks
	private.store = nil :: any
	private.net = nil :: event<enumitem_net_notification, netpack>?
	private.event = Event:new() :: data_event
	private.profiles = {} :: { [Player]: profile }
	private.states = setmetatable({} :: { [Player]: enumitem_data_state }, private.meta)
	private.ready = setmetatable({} :: { [Player]: true }, private.meta)

	function private.get_store(): any
		const store: any = std:assert(private.store, "DataServer isn't started")
		if not store then
			return nil
		end

		--#if DEBUG
		if engine.is_studio and private.env.studio.mock then
			return store.Mock
		end
		--#endif

		return store
	end

	function private.set_state(player: Player, state: enumitem_data_state)
		private.states[player] = state
		private.event:invoke(DataNotification.DataStateChanged, player, state)
	end

	function private.player_added(player: Player)
		if private.states[player] ~= nil then
			return
		end

		private.set_state(player, DataState.ProfileLoading)

		const profile: profile? = private.get_store():StartSessionAsync(private.env.key(player.UserId), {
			Cancel = function()
				return not players.is_in_game(player)
			end,
		})

		if not profile then
			--#if DEBUG
			std:outw(`data Failed to load {player.Name}: the session is locked by another server or the store is down`)
			--#endif

			private.set_state(player, DataState.ProfileReleased)
			players.kick(player, "Your data couldn't be loaded, please rejoin")
			return
		end

		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			if players.is_in_game(player) then
				--#if DEBUG
				std:outw(`data session of {player.Name} ended by another server`)
				--#endif
			end
			private.release(player, profile)
			players.kick(player, "Your data was opened on another server, please rejoin")
		end)

		if not players.is_in_game(player) then
			profile:EndSession()
			private.set_state(player, DataState.ProfileReleased)
			return
		end

		private.profiles[player] = profile

		const user = profile.Data.user
		if type(user) == types.table then
			const now = os.time()

			if (user.joined_at or 0) == 0 then
				user.joined_at = now
			end

			user.previous_seen_at = if (user.last_seen_at or 0) == 0 then now else user.last_seen_at
			user.last_seen_at = now
			user.last_server_id = engine.job_id
			user.sessions = (user.sessions or 0) + 1
		end

		profile:MessageHandler(function(message: unknown, processed: () -> ())
			if type(message) == types.table then
				private.event:invoke(DataNotification.DataMessage, player, message, processed)
			end
		end)

		--#if DEBUG
		if engine.is_studio then
			std:out(`data {player.Name} loaded:`, profile.Data)
		end
		--#endif

		private.set_state(player, DataState.ProfileLoaded)
		private.send_snapshot(player)
		private.event:invoke(DataNotification.DataLoaded, player, profile.Data)
	end

	function private.player_removing(player: Player)
		const profile = private.profiles[player]

		if profile then
			const user = profile.Data.user
			if type(user) == types.table then
				const now = os.time()
				user.played_time = (user.played_time or 0) + now - (user.last_seen_at or now)
				user.last_seen_at = now
			end
			profile:EndSession()
		end

		private.ready[player] = nil
	end

	function private.release(player: Player, profile: profile)
		if private.profiles[player] ~= profile then
			return
		end

		private.profiles[player] = nil
		private.set_state(player, DataState.ProfileReleased)
		private.event:invoke(DataNotification.DataReleased, player, profile.Data)
	end

	function private.split(path: data_path): { string }
		if type(path) == types.table then
			return path :: { string }
		end

		return string.split(path :: string, "/")
	end

	function private.resolve(snapshot: data_snapshot, segments: { string }): ({ [string]: any }, string)
		local node: any = snapshot

		for k = 1, #segments - 1 do
			node = node[segments[k]]
			if not std:assert(type(node) == types.table, `bad data path {table.concat(segments, "/")}`) then
				return {}, ""
			end
		end

		return node, segments[#segments]
	end

	function private.deep_copy(from: any): any
		if type(from) ~= types.table then
			return from
		end

		const copy = {}
		for k, v in from do
			copy[k] = private.deep_copy(v)
		end

		return copy
	end

	function private.snapshot(snapshot: data_snapshot): data_snapshot
		const result = {}

		for k in private.env.replicating do
			result[k] = snapshot[k]
		end

		return result
	end

	function private.send_snapshot(player: Player)
		const profile = private.profiles[player]

		if profile and private.ready[player] and private.net then
			SharedNet:emit_event(
				private.net,
				NetPack:pack({ player }, DataInternalVariant.DataSnapshot.hashlink, private.snapshot(profile.Data))
			)
		end
	end

	function private.replicate(player: Player, segments: { string }, to: unknown)
		if not private.env.replicating[segments[1]] or not private.ready[player] or not private.net then
			return
		end

		SharedNet:emit_event(private.net, NetPack:pack({ player }, DataInternalVariant.DataSet.hashlink, segments, to))
	end
end

return class
