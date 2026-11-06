--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Observer = require("@class/core/Observer")
const Variable = require("@class/core/Variable")
const ItemBehavior = require("@class/game/inventory/ItemBehavior")
const mtypes = require("@declare/mtypes")
const ftype = require("@static/ftype")

const private = { type = "iteminstance" }
const class: iteminstance = (Observer :: observer<enumitem_list_notification>):new({
	type = private.type,

	get_item = ftype:write(function(self: iteminstance): variable<item>
		return self:get <<variable<item>>> (private.item_key)
	end, Variable.type, private.type),

	get_behavior = ftype:write(function(self: iteminstance): itembehavior?
		return self:get <<itembehavior?>> (private.behavior_key)
	end, ftype:opt(ItemBehavior.type), private.type),

	set_behavior = ftype:write(function(self: iteminstance, to: itembehavior?): ()
		self:set(private.behavior_key, to)
	end, mtypes.never, private.type, ftype:opt(ItemBehavior.type)),
})

do
	private.item_key = newproxy()
	private.behavior_key = newproxy()

	private.new = function(new: luaobject)
		const new = new:as<<iteminstance>>(class.type)
		new:set(private.item_key, Variable:new())
		new:set(private.behavior_key, nil)
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif
end

class:host(private.new)

return class
