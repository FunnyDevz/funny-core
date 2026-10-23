--!strict
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const ControllerState = require("@enums/state/ControllerState")
const ftype = require("@static/ftype")

const class: controller = (Observer :: observer<enumitem_controller_state>):new({
	type = "controller",
	state = ControllerState.Pause,

	continue = ftype:write(function(self: controller): ()
		if self.state == ControllerState.Continue then
			return
		end

		self.state = ControllerState.Continue
		self:notificate(ControllerState.Continue)
	end, mtypes.never, "controller"),

	pause = ftype:write(function(self: controller): ()
		if self.state == ControllerState.Pause then
			return
		end

		self.state = ControllerState.Pause
		self:notificate(ControllerState.Pause)
	end, mtypes.never, "controller"),

	reset = ftype:write(function(self: controller): ()
		if self.state == ControllerState.Reset then
			return
		end

		self.state = ControllerState.Reset
		self:notificate(ControllerState.Reset)
	end, mtypes.never, "controller"),
})

return class
