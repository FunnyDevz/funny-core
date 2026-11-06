--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const ItemInstance = require("@class/game/inventory/ItemInstance")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const ListNotification = require("@enums/notification/ListNotification")
const ftype = require("@static/ftype")

const private = { type = "itemstack" }
const class: itemstack = (ItemInstance :: iteminstance):new({
	type = private.type,

	count = ftype:write(function(self: itemstack): number
		return self:get <<number?>> (private.count_key) or 0
	end, types.number, private.type),

	length = ftype:write(function(self: itemstack): number
		return private.get_max(self)
	end, types.number, private.type),

	get_max = ftype:write(function(self: itemstack): number
		return private.get_max(self)
	end, types.number, private.type),

	is_full = ftype:write(function(self: itemstack): boolean
		const max = private.get_max(self)
		return max > 0 and self:count() >= max
	end, types.boolean, private.type),

	is_empty = ftype:write(function(self: itemstack): boolean
		return self:count() <= 0
	end, types.boolean, private.type),

	is_half = ftype:write(function(self: itemstack): boolean
		const max = private.get_max(self)
		return max > 0 and self:count() >= max / 2
	end, types.boolean, private.type),

	clear = ftype:write(function(self: itemstack): ()
		private.set_count(self, 0)
	end, mtypes.never, private.type),

	adjust = ftype:write(function(self: itemstack, count: number): ()
		private.set_count(self, self:count() + count)
	end, mtypes.never, private.type, types.number),

	insert = ftype:write(function(self: itemstack, ...: itemstack): ()
		for k, v in { ... } do
			if v == self or not private.is_same(self, v) then
				continue
			end

			const moved = math.min(v:count(), private.get_max(self) - self:count())

			if moved > 0 then
				v:adjust(-moved)
				self:adjust(moved)
			end
		end
	end, mtypes.never, private.type, ftype:var(private.type)),

	remove = ftype:write(function(self: itemstack, ...: itemstack): ()
		for k, v in { ... } do
			if v ~= self and private.is_same(self, v) then
				self:adjust(-v:count())
			end
		end
	end, mtypes.never, private.type, ftype:var(private.type)),

	collect = ftype:write(function(self: itemstack, utype: string): ...any
		if self:is(utype) then
			return self
		end

		return
	end, ftype:var_opt(private.type), private.type, types.string),

	find = ftype:write(function(self: itemstack, ...: itemstack): ...boolean
		const result: { boolean } = {}

		for k, v in { ... } do
			table.insert(result, v == self or private.is_same(self, v))
		end

		return unpack(result)
	end, ftype:var(types.boolean), private.type, ftype:var(private.type)),
})

do
	private.count_key = newproxy()

	private.new = function (new: luaobject)
		const new = new:as<<itemstack>>(class.type)
		new:set(private.count_key, 0)
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif

	private.get_max = function(of: itemstack): number
		const item = of:get_item():get_value()
		return if item then item.max else 0
	end

	private.is_same = function(of: itemstack, that: itemstack): boolean
		const item = of:get_item():get_value()
		return item ~= nil and item == that:get_item():get_value()
	end

	private.set_count = function(of: itemstack, to: number)
		const previous = of:count()
		const max = private.get_max(of)
		const count = math.clamp(math.floor(to), 0, max)

		if count == previous then
			return
		end

		of:set(private.count_key, count)

		if count > previous then
			of:notificate(ListNotification.AddedElement, count - previous)
		else
			of:notificate(ListNotification.RemovedElement, previous - count)
		end

		if count >= max then
			of:notificate(ListNotification.ListFull)
		elseif count <= 0 then
			of:notificate(ListNotification.ListEmpty)
		elseif (previous < max / 2) ~= (count < max / 2) then
			of:notificate(ListNotification.ListHalf)
		end
	end
end

class:host(private.new)

return class
