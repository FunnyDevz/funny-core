--!strict

--#include <build.gpp>

const Reference = require("@class/common/Reference")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const ReferenceNotification = require("@enums/notification/ReferenceNotification")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

const private = {}
--[==[
	Это шаблон референса для хранения только экземпляров `BasePart?`.
]==]
const class: reference<BasePart?> = (Reference :: reference<BasePart?>):new()

do
	private.register = function(new: luaobject)
		const new = new:as <<reference<BasePart?>>> (class.type)
		new:subscribe(
			{ ReferenceNotification.NewInstance, ReferenceNotification.ChangedInstance },
			ConnectionVariant.Ever,
			function()
				const var = new:get_instance() :: Instance

				if var ~= nil and not var:IsA("BasePart") then
					new:set_instance(nil)
					return
				elseif var == nil then
					return
				end
			end
		)
	end

	class:host(private.register)

	--#if LUAOBJECT_SELF_REG
	private.register(class)
	--#endif

	ctype:read(class):write_tag(ctags.class, ctags.common, ctags.template)
end

return class
