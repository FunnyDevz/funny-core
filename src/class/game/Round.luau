--!strict
const StateMachine = require("@class/common/StateMachine")
const Maybe = require("@class/common/gc/Maybe")
const Timer = require("@class/common/runtime/Timer")
const Faction = require("@class/game/Faction")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const Cryptography = require("@import/Cryptography")
const ftype = require("@static/ftype")

const private = {}
const class : round = Timer:new {
    type = "round",

    get_faction = ftype:write(function (self: round) : ...faction
        return unpack(private.get_factions(self))
    end, ftype:var(Faction.type), "round"),

    add_faction = ftype:write(function (self: round, ...: faction) : ()
        const list = private.get_factions(self)

        for _, v in {...} do
            if not table.find(list, v) then
                table.insert(list, v)
            end
        end
    end, mtypes.never, "round", ftype:var(Faction.type)),

    rem_faction = ftype:write(function (self: round, ...: faction) : ()
        const list = private.get_factions(self)

        for _, v in {...} do
            table.remove(list, table.find(list, v) or 0)
        end
    end, mtypes.never, "round", ftype:var(Faction.type)),

    has_faction = ftype:write(function (self: round, ...: faction) : boolean
        const list = private.get_factions(self)

        for _, v in {...} do
            if not table.find(list, v) then
                return false
            end
        end

        return true
    end, types.boolean, "round", ftype:var(Faction.type)),

    find_member = ftype:write(function (self: round, ...: character) : {[character]: {faction}?}
        const list = private.get_factions(self)
        const result: {[character]: {faction}?} = {}

        for _, character in {...} do
            for _, faction in list do
                if faction:is_member(character) then
                    if not result[character] then
                        result[character] = {faction}
                    else
                        table.insert(result[character] :: {faction}, faction)
                    end
                end
            end
        end

        return result
    end, types.table, "round", ftype:var(Faction.type)),

    get_members = ftype:write(function (self: round): faction
        return private.members:enactment(self, Faction)
    end, Faction.type, "round"),

    get_states = ftype:write(function (self: round) : statemachine
        return private.machines:enactment(self, StateMachine)
    end, StateMachine.type, "round")
}

class:host(function(new)
    const new = new:as <<round>> (class.type)
    new:set(private.factions_key, {})
end)

do
    private.factions_key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring("round_factions_key"))
    private.members = Maybe:new() :: maybe<faction, round>
    private.machines = Maybe:new() :: maybe<statemachine, round>

    private.get_factions = function (self: round)
        return self:get <<{faction}>>(private.factions_key)
    end
end

return class