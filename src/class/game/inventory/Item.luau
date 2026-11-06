--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Struct = require("@class/core/Struct")
const ItemBehavior = require("@class/game/inventory/ItemBehavior")
const ItemObject = require("@class/game/inventory/ItemObject")
const ItemStack = require("@class/game/inventory/ItemStack")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const private = { type = "item" }
const class: item = Struct:new({
	type = private.type,
	name = "default_item_name",
	max = 1,
	count = 1,
	description = "",
	behavior = ItemBehavior:new(),

	get_stack = ftype:write(function(self: item, count: number?): itemstack
		const stack = ItemStack:new()
		stack:get_item():set_value(self)
		stack:set_behavior(self.behavior)
		stack:adjust(count or self.count)
		return stack
	end, ItemStack.type, private.type, ftype:opt(types.number)),

	get_object = ftype:write(function(self: item): itemobject
		const object = ItemObject:new()
		object:get_item():set_value(self)
		object:set_behavior(self.behavior)
		return object
	end, ItemObject.type, private.type),

	get_by_name = ftype:write(function(self: item, name: string): item?
		return private.registry[name]
	end, ftype:opt(private.type), private.type, types.string),

	get_all = ftype:write(function(self: item): ...item
		const result: { item } = {}

		for _, v in private.registry do
			table.insert(result, v)
		end

		return table.unpack(result)
	end, ftype:var(private.type), private.type),

	get_null_item = ftype:write(function (self: item) : item
		return private.nullitem
	end, private.type, private.type)
})

do
	private.registry = setmetatable({} :: { [string]: item }, tables.__mode_vs)

	private.new = function(new: luaobject)
		const new = new:as<<item>>(class.type)
		private.registry[new.name] = new
	end

	private.nullitem = class:new({
		name = "NullItem",
		description = "NullItem"
	})
	private.new(private.nullitem)

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif
end

class:host(private.new)

return class
