--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Observer = require("@class/core/Observer")
const Variable = require("@class/core/Variable")
const ftype = require("@static/ftype")

const private = { type = "iteminstance" }
const class: iteminstance = (Observer :: observer<enumitem_list_notification>):new({
	type = private.type,

	get_item = ftype:write(function(self: iteminstance): variable<item?>
		return self:get <<variable<item?>>> (private.item_key)
	end, Variable.type, private.type),
})

class:host(function(new)
	const new = new:as <<iteminstance>> (class.type)
	new:set(private.item_key, Variable:new())
end)

do
	private.item_key = newproxy()

	--#if CORE_CLASS_USEABLE
	class:set(private.item_key, Variable:new())
	--#endif
end

return class
