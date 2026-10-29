--!strict
const Event = require("@class/common/signal/Event")
const EnumItem = require("@class/core/EnumItem")
const Service = require("@class/core/Service")
const SharedNet = require("@class/service/SharedNet")
const NetPack = require("@class/struct/common/NetPack")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const DataNotification = require("@enums/notification/DataNotification")
const NetNotification = require("@enums/notification/NetNotification")
const DataState = require("@enums/state/DataState")
const stderr = require("@extension/stderr")
const ProfileStore = require("@include/ProfileStore")
const engine = require("@platform/roblox/engine")
const players = require("@platform/roblox/players")
const rbxtypes = require("@platform/roblox/rbxtypes")
const DataServerPref = require("@setting/DataServerPref")
const ftype = require("@static/ftype")

const REPLICATING = DataServerPref.replicating :: { [string]: boolean }

type profile = any
type data_event = event<enumitem_data_notification, ...any>

const private = {}
const class: dataserver = Service:new({
	type = "dataserver",
	name = "DataServer",

	start = ftype:write(function(self: dataserver): ()
		if self.enabled then
			return
		end

		self.enabled = true
		private.store = ProfileStore.New(DataServerPref.store, DataServerPref.template :: any)

		const event = SharedNet:get_event(SharedNetLink.Data)
		private.net = event

		event:connect(NetNotification.Received, function(pack: netpack)
			const player = if pack.sender then players.get_by_user_id(pack.sender) else nil

			if player and pack:payload() == "ready" then
				private.ready[player] = true
				private.send_snapshot(player)
			end
		end)

		players.on_added(private.player_added)
		players.on_removing(private.player_removing)

		for k, v in players.get_all() do
			task.spawn(private.player_added, v)
		end
	end, mtypes.never, "dataserver"),

	get_state = ftype:write(function(self: dataserver, player: Player): enumitem_data_state
		return private.states[player] or DataState.ProfileReleased
	end, EnumItem.type, "dataserver", rbxtypes.Instance),

	get_data = ftype:write(function(self: dataserver, player: Player): data_snapshot?
		const profile = private.profiles[player]
		return if profile then profile.Data else nil
	end, ftype:opt(types.table), "dataserver", rbxtypes.Instance),

	wait_data = ftype:write(function(self: dataserver, player: Player): data_snapshot?
		while private.states[player] == DataState.ProfileLoading do
			private.event:wait(DataNotification.DataStateChanged)
		end

		return self:get_data(player)
	end, ftype:opt(types.table), "dataserver", rbxtypes.Instance),

	get_value = ftype:write(function<T>(self: dataserver, player: Player, path: data_path): T
		const snapshot = self:get_data(player)

		if not stderr:check(snapshot, `{player.Name}'s data isn't loaded`) then
			return nil :: any
		end

		const parent, key = private.resolve(snapshot :: data_snapshot & exist, private.split(path))
		return parent[key]
	end, ftype:opt(mtypes.anyt), "dataserver", rbxtypes.Instance, ftype:uor(types.string, types.table)),

	set_value = ftype:write(
		function(self: dataserver, player: Player, path: data_path, to: unknown): ()
			const snapshot = self:get_data(player)

			if not stderr:check(snapshot, `{player.Name}'s data isn't loaded`) then
				return
			end

			const segments = private.split(path)
			const parent, key = private.resolve(snapshot :: data_snapshot & exist, segments)
			parent[key] = to
			private.replicate(player, segments, to)
		end,
		mtypes.never,
		"dataserver",
		rbxtypes.Instance,
		ftype:uor(types.string, types.table),
		ftype:opt(mtypes.anyt)
	),

	update_value = ftype:write(
		function<T>(self: dataserver, player: Player, path: data_path, f: (current: T) -> T): T
			const next_value = f(self:get_value(player, path))
			self:set_value(player, path, next_value)
			return next_value
		end,
		ftype:opt(mtypes.anyt),
		"dataserver",
		rbxtypes.Instance,
		ftype:uor(types.string, types.table),
		types["function"]
	),

	reset = ftype:write(function(self: dataserver, player: Player): boolean
		const profile = private.profiles[player]

		if not profile then
			return false
		end

		profile.Data = private.deep_copy(DataServerPref.template)
		private.send_snapshot(player)
		return true
	end, types.boolean, "dataserver", rbxtypes.Instance),

	send_message = ftype:write(function(self: dataserver, user_id: number, message: { [string]: any }): boolean
		const store = private.get_store()
		const succ, err = pcall(store.MessageAsync, store, DataServerPref.key(user_id), message)

		if not succ then
			warn(`data failed to send a message to {user_id}:`, err)
		end

		return succ
	end, types.boolean, "dataserver", types.number, types.table),

	get_data_event = ftype:write(function(self: dataserver): data_event
		return private.event
	end, Event.type, "dataserver"),
})

do
	private.meta = tables.__mode_ks
	private.store = nil :: any
	private.net = nil :: event<enumitem_net_notification, netpack>?
	private.event = Event:new() :: data_event
	private.profiles = {} :: { [Player]: profile }
	private.states = setmetatable({} :: { [Player]: enumitem_data_state }, private.meta)
	private.ready = setmetatable({} :: { [Player]: true }, private.meta)

	function private.get_store(): any
		const store = assert(private.store, "DataServer isn't started")

		if engine.is_studio and DataServerPref.studio.mock then
			return store.Mock
		end

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

		const profile: profile? = private.get_store():StartSessionAsync(DataServerPref.key(player.UserId), {
			Cancel = function()
				return not players.is_in_game(player)
			end,
		})

		if not profile then
			warn(`data Failed to load {player.Name}: the session is locked by another server or the store is down`)
			private.set_state(player, DataState.ProfileReleased)
			players.kick(player, "Your data couldn't be loaded, please rejoin")
			return
		end

		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			if players.is_in_game(player) then
				warn(`data session of {player.Name} ended by another server`)
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

			if user.joined_at == 0 then
				user.joined_at = now
			end

			user.last_seen_at = now
			user.last_server_id = engine.job_id
			user.sessions += 1
		end

		profile:MessageHandler(function(message: unknown, processed: () -> ())
			if type(message) == types.table then
				private.event:invoke(DataNotification.DataMessage, player, message, processed)
			end
		end)

		if engine.is_studio then
			print(`data {player.Name} loaded:`, profile.Data)
		end

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
				user.played_time += now - user.last_seen_at
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
			assert(type(node) == types.table, `bad data path {table.concat(segments, "/")}`)
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

		for k in REPLICATING do
			result[k] = snapshot[k]
		end

		return result
	end

	function private.send_snapshot(player: Player)
		const profile = private.profiles[player]

		if profile and private.ready[player] and private.net then
			SharedNet:emit_event(private.net, NetPack:pack({ player }, "snapshot", private.snapshot(profile.Data)))
		end
	end

	function private.replicate(player: Player, segments: { string }, to: unknown)
		if not REPLICATING[segments[1]] or not private.ready[player] or not private.net then
			return
		end

		SharedNet:emit_event(private.net, NetPack:pack({ player }, "set", segments, to))
	end
end

return class
