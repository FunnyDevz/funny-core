--!strict
const Maybe = require("@class/common/gc/Maybe")
const Controller = require("@class/common/runtime/Controller")
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const TickNotification = require("@enums/notification/TickNotification")
const ControllerState = require("@enums/state/ControllerState")
const ftype = require("@static/ftype")


const private = {}
const class : timer = (Observer :: observer<enumitem_tick_notification>):new {
	type = "timer",
	iterate = 1,
	modifier = 1,

	get_control = ftype:write(function (self: timer): controller
		return private.maybe:enactment(self, Controller)
	end, Controller.type, "timer"),

	get_elapsed = ftype:write(function (self: timer) : number
		return self:get_duration() - self:get_remaining()
	end, types.number, "timer"),

	get_remaining = ftype:write(function (self: timer) : number
		return private.get(self).remaining
	end, types.number, "timer"),

	get_duration = ftype:write(function (self: timer) : number
		return private.get(self).duration
	end, types.number, "timer"),

	get_step = ftype:write(function (self: timer) : number
		return private.get(self).step
	end, types.number, "timer"),

	set_duration = ftype:write(function (self: timer, duration: number) : ()
		private.get(self).duration = duration
	end, mtypes.never, "timer", types.number),

	set_step = ftype:write(function (self: timer, step: number) : ()
		private.get(self).step = step
	end, mtypes.never, "timer", types.number),

	is_running = ftype:write(function (self: timer) : boolean
		return private.get(self).remaining > 0
	end, types.boolean, "timer"),

	is_finished = ftype:write(function (self: timer) : boolean
		return private.get(self).remaining <= 0
	end, types.boolean, "timer")

}

class:host(function(new)
	const new = new:as <<observer>> (class.type)
	const internal = private.mk_internal()
	
	new:set(private.internal_item.hashlink, internal)
	new:subscribe(private.internal_item, ConnectionVariant.Once, function (controller: controller)
		controller:subscribe(ControllerState.Continue, ConnectionVariant.Ever, function ()
			internal.yield = false
			
			if internal.cycle then
				if coroutine.status(internal.cycle) == "suspended" then
					task.defer(internal.cycle)
				end
			else
				internal.remaining = internal.duration

				const timer = coroutine.create(function()				
					new:notificate(TickNotification.Started)

					while task.wait(internal.step) and internal.remaining > 0 do
						if internal.yield then
							task.cancel(coroutine.running())
							new:notificate(TickNotification.Paused)
							coroutine.yield()
							new:notificate(TickNotification.Resumed)
						end

						internal.remaining -= internal.step
						internal.remaining = math.clamp(internal.remaining, 0, internal.duration)

						new:notificate(TickNotification.Stepped)
					end

					internal.cycle = nil
					task.cancel(coroutine.running())
					new:notificate(TickNotification.Finished)
				end)
				
				internal.cycle = timer
				task.defer(timer)
			end


		end)

		controller:subscribe(ControllerState.Pause, ConnectionVariant.Ever, function ()
			internal.yield = true
		end)

		controller:subscribe(ControllerState.Reset, ConnectionVariant.Ever, function ()
			internal.yield = true
			task.wait()

			if internal.cycle then
				task.cancel(internal.cycle)
				coroutine.close(internal.cycle)
				internal.cycle = nil
			end

			internal.remaining = 0
		end)

	end)
end)

do
	type internal = {
		step: number,
		duration: number,
		remaining: number,
		cycle: thread?,
		yield: boolean
	}

	private.maybe = Maybe:new() :: maybe<controller, timer>
	private.internal_item = EnumItem:new {name = "InternalTimerItem"}
	private.maybe:subscribe(OperationVariant.New, ConnectionVariant.Ever, function (it: timer, controller: controller)
		it:notificate(private.internal_item, controller)
	end)

	private.get = function (self: timer)
		return self:get <<internal>> (private.internal_item.hashlink)
	end

	private.mk_internal = function () : internal
		return {
			step = 1,
			duration = 0,
			remaining = 0,
			yield = false
		}
	end
end

return class