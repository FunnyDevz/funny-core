--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Observer = require("@class/core/Observer")
const Scheduler = require("@class/core/Scheduler")
const Item = require("@class/game/inventory/Item")
const ItemInstance = require("@class/game/inventory/ItemInstance")
const ItemObject = require("@class/game/inventory/ItemObject")
const ItemStack = require("@class/game/inventory/ItemStack")
const SharedNet = require("@class/service/SharedNet")
const NetPack = require("@class/struct/common/NetPack")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const SharedNetLink = require("@enums/descriptor/SharedNetLink")
const ListNotification = require("@enums/notification/ListNotification")
const NetNotification = require("@enums/notification/NetNotification")
const std = require("@extension/std")
const engine = require("@platform/roblox/engine")
const players = require("@platform/roblox/players")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

type entry = {
	id: number,
	kind: string,
	item: string?,
	count: number,
}

type snapshot = {
	max: number,
	entries: { entry },
}

type net_event = event<enumitem_net_notification, netpack>

const private = { type = "inventory" }
const class: inventory = (Observer :: observer<enumitem_list_notification>):new({
	type = private.type,
	max = 16,

	get_stacks = ftype:write(function(self: inventory): ...iteminstance
		return unpack(table.clone(private.get(self)))
	end, ftype:var(ItemInstance.type), private.type),

	count_item = ftype:write(function(self: inventory, of: item): number
		local total = 0

		for _, v in private.get(self) do
			if v:get_item():get_value() ~= of then
				continue
			end

			const stack = self:that <<itemstack>> (v, ItemStack.type)
			total += if stack then stack:count() else 1
		end

		return total
	end, types.number, private.type, Item.type),

	has_item = ftype:write(function(self: inventory, of: item): boolean
		return self:count_item(of) > 0
	end, types.boolean, private.type, Item.type),

	count = ftype:write(function(self: inventory): number
		return #private.get(self)
	end, types.number, private.type),

	length = ftype:write(function(self: inventory): number
		return self.max
	end, types.number, private.type),

	is_full = ftype:write(function(self: inventory): boolean
		return self:count() >= self.max
	end, types.boolean, private.type),

	is_empty = ftype:write(function(self: inventory): boolean
		return self:count() == 0
	end, types.boolean, private.type),

	is_half = ftype:write(function(self: inventory): boolean
		return self.max > 0 and self:count() >= self.max / 2
	end, types.boolean, private.type),

	clear = ftype:write(function(self: inventory): ()
		if not private.writable(self) then
			return
		end

		const entries = private.get(self)
		const removed = table.clone(entries)
		table.clear(entries)

		for k, v in removed do
			private.unwatch(self, v)
			self:notificate(ListNotification.RemovedElement, v)
		end

		self:notificate(ListNotification.ListEmpty)
		private.mark(self)
	end, mtypes.never, private.type),

	adjust = ftype:write(function(self: inventory, count: number): ()
		if not private.writable(self) then
			return
		end

		self.max = math.max(math.floor(self.max + count), 0)

		if self:count() > self.max then
			self:notificate(ListNotification.ListFull)
		end

		private.mark(self)
	end, mtypes.never, private.type, types.number),

	insert = ftype:write(function(self: inventory, ...: iteminstance): ()
		if not private.writable(self) then
			return
		end

		const entries = private.get(self)

		for k, v in { ... } do
			if not self:that(v, ItemInstance.type) or table.find(entries, v) then
				continue
			end

			const item = v:get_item():get_value()

			if not item then
				--#if DEBUG
				std:outw("cannot insert an item instance without an item description")
				--#endif
				continue
			end

			const stack = self:that <<itemstack>> (v, ItemStack.type)

			if stack then
				if stack:is_empty() then
					continue
				end

				for i, entry in table.clone(entries) do
					const target = self:that <<itemstack>> (entry, ItemStack.type)

					if target and not target:is_full() then
						target:insert(stack)
					end

					if stack:is_empty() then
						break
					end
				end

				if stack:is_empty() then
					continue
				end
			end

			if #entries >= self.max then
				self:notificate(ListNotification.ListFull, v)
				continue
			end

			const was_half = self:is_half()
			table.insert(entries, v)
			private.watch(self, v)
			self:notificate(ListNotification.AddedElement, v)

			if self:is_full() then
				self:notificate(ListNotification.ListFull)
			elseif self:is_half() and not was_half then
				self:notificate(ListNotification.ListHalf)
			end
		end

		private.mark(self)
	end, mtypes.never, private.type, ftype:var(ItemInstance.type)),

	remove = ftype:write(function(self: inventory, ...: iteminstance): ()
		if not private.writable(self) then
			return
		end

		const entries = private.get(self)

		for k, v in { ... } do
			const position = table.find(entries, v)

			if position then
				table.remove(entries, position)
				private.unwatch(self, v)
				self:notificate(ListNotification.RemovedElement, v)
			end
		end

		if #entries == 0 then
			self:notificate(ListNotification.ListEmpty)
		end

		private.mark(self)
	end, mtypes.never, private.type, ftype:var(ItemInstance.type)),

	collect = ftype:write(function(self: inventory, utype: string): ...any
		const result = {}

		for k, v in private.get(self) do
			if v:is(utype) then
				table.insert(result, v)
			end
		end

		return unpack(result)
	end, ftype:var_opt(ItemInstance.type), private.type, types.string),

	find = ftype:write(function(self: inventory, ...: iteminstance): ...boolean
		const entries = private.get(self)
		const result: { boolean } = {}

		for k, v in { ... } do
			table.insert(result, table.find(entries, v) ~= nil)
		end

		return unpack(result)
	end, ftype:var(types.boolean), private.type, ftype:var(ItemInstance.type)),

	set_replication = ftype:write(function(self: inventory, key: string?, ...: Player): ()
		if not std:check(engine.is_server, "inventory replication can be set only on the server") then
			return
		end

		private.boot()

		const previous = private.keys[self]
		const audience = private.audiences[self] or {}

		if previous and previous ~= key then
			private.release(self)
		end

		if key == nil then
			return
		end

		const existing = private.inventories[key]

		if existing and existing ~= self then
			private.release(existing)
		end

		const next_audience: { [Player]: true } = {}

		for k, v in { ... } do
			next_audience[v] = true
		end

		for k, v in audience do
			if not next_audience[k] and previous == key then
				private.send(k, "release", key)
			end
		end

		private.inventories[key] = self
		private.keys[self] = key
		private.audiences[self] = next_audience

		for k, v in next_audience do
			private.send(k, "snapshot", key, private.snapshot(self))
		end
	end, mtypes.never, private.type, ftype:opt(types.string), ftype:var_opt(rbxtypes.Instance)),

	get_replicated = ftype:write(function(self: inventory, key: string): inventory?
		if engine.is_server then
			return private.inventories[key]
		end

		return private.get_replica(key)
	end, ftype:opt(private.type), private.type, types.string),

	is_replica = ftype:write(function(self: inventory): boolean
		return private.is_replica[self] == true
	end, types.boolean, private.type),
})

do
	private.entries_key = newproxy()
	private.watch_key = newproxy()
	private.booted = false
	private.net = nil :: net_event?
	private.next_id = 0
	private.ids = setmetatable({} :: { [iteminstance]: number }, tables.__mode_ks)
	private.inventories = {} :: { [string]: inventory }
	private.keys = setmetatable({} :: { [inventory]: string }, tables.__mode_ks)
	private.audiences = setmetatable({} :: { [inventory]: { [Player]: true } }, tables.__mode_ks)
	private.dirty = setmetatable({} :: { [inventory]: true }, tables.__mode_ks)
	private.ready = setmetatable({} :: { [Player]: true }, tables.__mode_ks)
	private.replicas = {} :: { [string]: inventory }
	private.is_replica = setmetatable({} :: { [inventory]: true }, tables.__mode_ks)
	private.instances = {} :: { [string]: { [number]: iteminstance } }
	private.flushing = false

	private.new = function (new: luaobject)
		const new = new:as<<inventory>>(class.type)
		new:set(private.entries_key, {})
		new:set(private.watch_key, {})
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif

	private.get = function(of: inventory): { iteminstance }
		return of:get <<{ iteminstance }>> (private.entries_key)
	end

	private.writable = function(of: inventory): boolean
		return (std:check(private.is_replica[of] == nil, "replicated inventory is read-only on the client"))
	end

	private.get_replica = function(key: string): inventory
		const existing = private.replicas[key]

		if existing then
			return existing
		end

		const replica = class:new() :: inventory
		private.replicas[key] = replica
		private.is_replica[replica] = true
		private.boot()
		return replica
	end

	private.release = function(of: inventory)
		const key = private.keys[of]

		if not key then
			return
		end

		for k, v in private.audiences[of] or {} do
			private.send(k, "release", key)
		end

		private.inventories[key] = nil
		private.keys[of] = nil
		private.audiences[of] = nil
	end

	private.plan = function(f: () -> ())
		const scheduler = Scheduler:whose()

		if scheduler then
			scheduler:plan(f)
		else
			task.defer(f)
		end
	end

	private.watch = function(of: inventory, instance: iteminstance)
		const watched = of:get <<{ [iteminstance]: pointer }>> (private.watch_key)
		const pointer = instance:subscribe(
			{ ListNotification.AddedElement, ListNotification.RemovedElement },
			ConnectionVariant.Ever,
			function()
				private.mark(of)
			end
		)

		watched[instance] = pointer
	end

	private.unwatch = function(of: inventory, instance: iteminstance)
		const watched = of:get <<{ [iteminstance]: pointer }>> (private.watch_key)
		const pointer = watched[instance]

		if pointer then
			instance:unsubscribe(pointer)
			watched[instance] = nil
		end
	end

	private.mark = function(of: inventory)
		if not private.keys[of] then
			return
		end

		private.dirty[of] = true

		if private.flushing then
			return
		end

		private.flushing = true
		private.plan(private.flush)
	end

	private.flush = function()
		private.flushing = false

		for k, v in private.dirty do
			const key = private.keys[k]
			const audience = private.audiences[k]

			if key and audience then
				const snapshot = private.snapshot(k)

				for i, j in audience do
					private.send(i, "snapshot", key, snapshot)
				end
			end
		end

		table.clear(private.dirty)
	end

	private.get_id = function(instance: iteminstance): number
		const existing = private.ids[instance]

		if existing then
			return existing
		end

		private.next_id += 1
		private.ids[instance] = private.next_id
		return private.next_id
	end

	private.snapshot = function(of: inventory): snapshot
		const entries: { entry } = {}

		for k, v in private.get(of) do
			const item = v:get_item():get_value()
			const stack = class:that <<itemstack>> (v, ItemStack.type)

			table.insert(entries, {
				id = private.get_id(v),
				kind = if stack then ItemStack.type else ItemObject.type,
				item = if item then item.name else nil,
				count = if stack then stack:count() else 1,
			})
		end

		return { max = of.max, entries = entries }
	end

	private.send = function(to: Player, ...: any)
		const net = private.net

		if net and private.ready[to] then
			SharedNet:emit_event(net, NetPack:pack({ to }, ...))
		end
	end

	private.boot = function()
		if private.booted then
			return
		end

		private.booted = true

		if engine.is_server then
			private.boot_server()
		else
			private.plan(private.boot_client)
		end
	end

	private.boot_server = function()
		const net = SharedNet:get_event(SharedNetLink.Inventory)
		private.net = net

		net:connect(NetNotification.Received, function(pack: netpack)
			const sender = if pack.sender then players.get_by_user_id(pack.sender) else nil

			if not sender or private.ready[sender] or pack:payload() ~= "ready" then
				return
			end

			private.ready[sender] = true

			for k, v in private.audiences do
				const key = private.keys[k]

				if key and v[sender] then
					private.send(sender, "snapshot", key, private.snapshot(k))
				end
			end
		end)

		players.on_removing(function(player: Player)
			private.ready[player] = nil

			for k, v in private.audiences do
				v[player] = nil
			end
		end)
	end

	private.boot_client = function()
		const net = SharedNet:get_event(SharedNetLink.Inventory)
		private.net = net

		net:connect(NetNotification.Received, function(pack: netpack)
			const action, key, snapshot = pack:payload()

			if type(key) ~= types.string then
				return
			end

			if action == "snapshot" and type(snapshot) == types.table then
				private.apply(key :: string, snapshot :: snapshot)
			elseif action == "release" then
				private.apply(key :: string, { max = 0, entries = {} })
			end
		end)

		SharedNet:emit_event(net, NetPack:pack(nil, "ready"))
	end

	if engine.is_server then
		private.boot()
	end

	private.make_instance = function(data: entry): iteminstance
		const instance: iteminstance = if data.kind == ItemStack.type then ItemStack:new() else ItemObject:new()
		const item = if data.item then Item:get_by_name(data.item) else nil

		--#if DEBUG
		if data.item and not item then
			std:outw(`replicated item {data.item} isn't registered on the client`)
		end
		--#endif

		if class:that(item, Item.type) then
			instance:get_item():set_value(item :: item)
		else
			instance:get_item():set_value(Item:get_null_item())
		end

		return instance
	end

	private.apply = function(key: string, data: snapshot)
		const replica = private.get_replica(key)
		const known = private.instances[key] or {}
		const next_known: { [number]: iteminstance } = {}
		const entries = private.get(replica)
		const next_entries: { iteminstance } = {}

		for k, v in data.entries do
			const instance = known[v.id] or private.make_instance(v)
			const stack = class:that <<itemstack>> (instance, ItemStack.type)

			if stack then
				stack:adjust(v.count - stack:count())
			end

			next_known[v.id] = instance
			table.insert(next_entries, instance)
		end

		private.instances[key] = next_known
		replica.max = data.max

		const previous = table.clone(entries)
		table.clear(entries)
		table.move(next_entries, 1, #next_entries, 1, entries)

		for k, v in previous do
			if not table.find(entries, v) then
				replica:notificate(ListNotification.RemovedElement, v)
			end
		end

		for k, v in entries do
			if not table.find(previous, v) then
				replica:notificate(ListNotification.AddedElement, v)
			end
		end

		if #entries == 0 and #previous > 0 then
			replica:notificate(ListNotification.ListEmpty)
		end
	end
end

class:host(private.new)

return class
