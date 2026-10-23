--!strict
const Observer = require("@class/core/Observer")
const Character = require("@class/game/character/Character")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const Cryptography = require("@import/Cryptography")
const ftype = require("@static/ftype")

const private = {}
const class : faction = (Observer :: observer<enumitem_faction_notification>):new {
    type = "faction",
    name = "default_faction_name",

    get_member = ftype:write(function (self: faction) : ...character
        return table.unpack(private.get(self))
    end, ftype:var(Character.type), "faction"),

    add_member = ftype:write(function (self: faction, ...: character) : ()
        const list = private.get(self)

        for _, v in {...} do
            if not table.find(list, v) then
                table.insert(list, v)
            end
        end
    end, mtypes.never, "faction", ftype:var(Character.type)),

    rem_member = ftype:write(function (self: faction, ...: character) : ()
        const list = private.get(self)

        for _, v in {...} do
            table.remove(list, table.find(list, v) or 0)
        end
    end, mtypes.never, "faction", ftype:var(Character.type)),

    is_member = ftype:write(function (self: faction, ...:character) : boolean
        const list = private.get(self)

        for _, v in list do
            if not table.find(list, v) then
                return false
            end
        end

        return true
    end, types.boolean, "faction", ftype:var(Character.type))
}


class:host(function(new)
    const new = new:as <<faction>> (class.type)

    new:set(private.key, setmetatable({}, tables.__mode_vs))
end)

do
    private.key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring("Faction_Key_Unique"))
    private.get = function (self: faction)
        return self:get <<{character}>>(private.key)
    end
end

return class