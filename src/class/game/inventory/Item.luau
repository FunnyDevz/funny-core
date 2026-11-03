--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Struct = require("@class/core/Struct")
const ItemBehavior = require("@class/game/inventory/ItemBehavior")
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
	behavior = ItemBehavior,

	get_stack = ftype:write(function(self: item, count: number): itemstack
		const stack = ItemStack:new()
		stack:get_item():set_value(self)
		stack:adjust(count)
		return stack
	end, ItemStack.type, private.type, types.number),

	get_by_name = ftype:write(function(self: item, name: string): item?
		return private.registry[name]
	end, ftype:opt(private.type), private.type, types.string),
})

class:host(function(new)
	const new = new:as <<item>> (class.type)
	private.registry[new.name] = new
end)

do
	private.registry = setmetatable({} :: { [string]: item }, tables.__mode_vs)
end

return class
