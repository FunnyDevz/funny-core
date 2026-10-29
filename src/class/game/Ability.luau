--!strict
const StateMachine = require("@class/common/StateMachine")
const Maybe = require("@class/common/gc/Maybe")
const Timer = require("@class/common/runtime/Timer")
const Observer = require("@class/core/Observer")
const AbilityInfo = require("@class/struct/game/AbilityInfo")
const tables = require("@declare/tables")
const AbilityNotification = require("@enums/notification/AbilityNotification")
const RoundState = require("@enums/state/RoundState")
const stdout = require("@extension/stdout")
const Cryptography = require("@import/Cryptography")


const private = {}
const class: ability = (Observer :: observer<enumitem_ability_notification>):new {
    type = "ability",

    activate = function (self: ability, on: character, ...: any) : ()
        if not self:cooldown():is_finished() then

            --#if DEBUG && ABILITY_PRINT_ACT
            stdout:out("cannot active current ability, cooldown")
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

    get_collision = function (self: ability) : ...collision
        return unpack(private.get_collision_list(self))
    end,

    add_collision = function (self: ability, ...: collision) : ()
        const list = private.get_collision_list(self)

        for _, v in {...} do
            if not table.find(list, v) then
                table.insert(list, v)
            end
        end
    end,

    rem_collision = function (self: ability, ...: collision) : ()
        const list = private.get_collision_list(self)

        for _, v in {...} do
            table.remove(list, table.find(list, v) or 0)
        end
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
    private.collision_key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring  "ability_collisions_key")
    private.info_key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring  "ability_info_key")
    private.maybe_statemachine = Maybe:new() :: maybe<statemachine, ability>
    private.maybe_cooldown = Maybe:new() :: maybe<timer, ability>

    private.get_collision_list = function (self: ability)
        return self:get <<{collision}>>(private.collision_key)
    end
end

return class