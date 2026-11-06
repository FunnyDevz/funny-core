--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Event = require("@class/common/signal/Event")

const private = { type = "itembehavior" }
const class: itembehavior = (Event :: event<enumitem_item_notification, itembehavior, itemcontext>):new({
	type = private.type,
})

do
	private.new = function(new: luaobject): ()
		const _new = new:as<<itembehavior>>(class.type)
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif
end

class:host(private.new)

return class
