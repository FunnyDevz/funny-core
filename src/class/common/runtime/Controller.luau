--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const ControllerState = require("@enums/state/ControllerState")
const ftype = require("@static/ftype")

const private = {type = "controller"}
const class: controller = (Observer :: observer<enumitem_controller_state>):new({
	type = private.type,
	state = ControllerState.Pause,

	continue = ftype:write(function(self: controller): ()
		if self.state == ControllerState.Continue then
			return
		end

		self.state = ControllerState.Continue
		self:notificate(ControllerState.Continue)
	end, mtypes.never, private.type),

	pause = ftype:write(function(self: controller): ()
		if self.state == ControllerState.Pause then
			return
		end

		self.state = ControllerState.Pause
		self:notificate(ControllerState.Pause)
	end, mtypes.never, private.type),

	reset = ftype:write(function(self: controller): ()
		if self.state == ControllerState.Reset then
			return
		end

		self.state = ControllerState.Reset
		self:notificate(ControllerState.Reset)
	end, mtypes.never, private.type),
})

return class
