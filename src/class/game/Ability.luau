--!strict
const StateMachine = require("@class/common/StateMachine")
const Maybe = require("@class/common/gc/Maybe")
const Timer = require("@class/common/runtime/Timer")
const Observer = require("@class/core/Observer")
const AbilityInfo = require("@class/struct/game/AbilityInfo")
const tables = require("@declare/tables")
const AbilityNotification = require("@enums/notification/AbilityNotification")
const RoundState = require("@enums/state/RoundState")
const std = require("@extension/std")

const private = {}
const class: ability = (Observer :: observer<enumitem_ability_notification>):new {
    type = "ability",

    activate = function (self: ability, on: character, ...: any) : ()
        if not self:cooldown():is_finished() then
            --#if DEBUG
            std:out("cannot active current ability, cooldown")
            --#endif

            return
        end

        -- We expect further code to manually manage the domain capability model
        -- Therefore, we only send activation notifications if there is no cooldown 

        self:get_states():set_state(true, RoundState.Begining)
        self:notificate(AbilityNotification.CastAbility, on, ...)
    end,

    cooldown = function (self: ability) : timer
        return private.maybe_cooldown:enactment(self, Timer)
    end,

    get_info = function (self: ability) : abilityinfo
        return self:get <<abilityinfo>> (private.info_key)
    end,

    set_info = function (self: ability, new: abilityinfo) : ()
	    self:set(private.info_key, new)
    end,

    get_states = function (self: ability) : statemachine
        return private.maybe_statemachine:enactment(self, StateMachine)
    end
}

class:host(function(new)
    const new = new:as <<ability>> (class.type)

    new:set_info(private.default_ability_info)
    new:set(private.collision_key, setmetatable({}, tables.__mode_vs))
end)

do
    private.default_ability_info = AbilityInfo:new()
    private.collision_key = newproxy()
    private.info_key = newproxy()
    private.maybe_statemachine = Maybe:new() :: maybe<statemachine, ability>
    private.maybe_cooldown = Maybe:new() :: maybe<timer, ability>
end

return class