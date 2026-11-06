--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Reference = require("@class/common/Reference")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const ReferenceNotification = require("@enums/notification/ReferenceNotification")

const private = {}
const class: reference<PVInstance?> = (Reference :: reference<PVInstance?>):new()

do
	private.register = function(new: luaobject)
		const new = new:as<<reference<PVInstance?>>>(class.type)
		new:subscribe(
			{ ReferenceNotification.NewInstance, ReferenceNotification.ChangedInstance },
			ConnectionVariant.Ever,
			function()
				const var = new:get_instance() :: Instance

				if var ~= nil and not var:IsA("PVInstance") then
					new:set_instance(nil)
					return
				elseif var == nil then
					return
				end
			end
		)
	end

	class:host(private.register)

	--#if ALL_CLASS_USEABLE
	private.register(class)
	--#endif
end

return class
