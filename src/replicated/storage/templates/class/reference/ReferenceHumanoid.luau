--!strict
const Reference = require("@game/ReplicatedStorage/class/common/Reference")
const ConnectionVariant = require("@game/ReplicatedStorage/enums/descriptor/ConnectionVariant")
const ReferenceNotification = require("@game/ReplicatedStorage/enums/notification/ReferenceNotification")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: reference<Humanoid?> = (Reference :: reference<Humanoid?>):new()

do
	private.register = function(new: luaobject)
		const new = new:as <<reference<Humanoid?>>> (class.type)
		new:subscribe(
			{ ReferenceNotification.NewInstance, ReferenceNotification.ChangedInstance },
			ConnectionVariant.Ever,
			function()
				const var = new:get_instance() :: Instance

				if var ~= nil and not var:IsA("Humanoid") then
					new:set_instance(nil)
					project.console_out(
						"an unsuitable instance of the RbxObject was passed, cancellation of the assignment"
					)
					return
				elseif var == nil then
					return
				end
			end
		)
	end

	class:host(private.register)
	if project.game.smalltalk_like then
		private.register(class)
	end

	ctype:read(class):write_tag(ctags.class, ctags.common, ctags.template)
end

return class
