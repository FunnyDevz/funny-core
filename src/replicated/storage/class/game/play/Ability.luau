--!strict
const StateMachine = require("@game/ReplicatedStorage/class/common/StateMachine")
const Maybe = require("@game/ReplicatedStorage/class/common/gc/Maybe")
const Timer = require("@game/ReplicatedStorage/class/common/runtime/Timer")
const Observer = require("@game/ReplicatedStorage/class/core/Observer")
const SecurityRNG = require("@game/ReplicatedStorage/class/service/SecurityRNG")
const AbilityInfo = require("@game/ReplicatedStorage/class/struct/game/AbilityInfo")
const AbilityNotification = require("@game/ReplicatedStorage/enums/notification/AbilityNotification")
const RoundState = require("@game/ReplicatedStorage/enums/state/RoundState")
const declare = require("@game/ReplicatedStorage/static/declare")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: ability = (Observer :: observer<enumitem_ability_notification>):new {
    type = "ability",

    activate = function (self: ability, on: character, ...: any) : ()
        if not self:cooldown():is_finished() then
            if project.debug then
                project.console_out("cannot activate current ability")
            end
            
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
    new:set(private.collision_key, setmetatable({}, declare.tables.__mode_vs))
end)

do
    private.default_ability_info = AbilityInfo:new()
    private.collision_key = SecurityRNG:get_hash_blake3("ability_collisions_key")
    private.info_key = SecurityRNG:get_hash_sha256("ability_info_key")
    private.maybe_statemachine = Maybe:new() :: maybe<statemachine, ability>
    private.maybe_cooldown = Maybe:new() :: maybe<timer, ability>

    private.get_collision_list = function (self: ability)
        return self:get <<{collision}>>(private.collision_key)
    end
end

return class