--!strict
const Reference = require("@game/ReplicatedStorage/class/common/Reference")
const Value = require("@game/ReplicatedStorage/class/common/Value")
const Maybe = require("@game/ReplicatedStorage/class/common/gc/Maybe")
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const Observer = require("@game/ReplicatedStorage/class/core/Observer")
const SecurityRNG = require("@game/ReplicatedStorage/class/service/SecurityRNG")
const CharacterInfo = require("@game/ReplicatedStorage/class/struct/game/CharacterInfo")
const DefaultVariant = require("@game/ReplicatedStorage/enums/descriptor/DefaultVariant")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")

const private = {}
const class : character = (Observer :: observer<>) :new {
    type = "character",

    get_token = ftype:write(function (self: character) : enumitem
        return self:get <<enumitem>>(private.token_key)
    end, EnumItem.type, "character"),

    set_token = ftype:write(function (self: character, new: enumitem) : ()
        self:set(private.token_key, new)
    end, declare["nil"], "character", EnumItem.type),

    get_parameter = ftype:write(function (self: character, ...: enumitem_character_parameter_variant) : ...value<number>
        const result: {value<number>} = {}
        const params = private.get_maybe(self)

        for _, v in {...} do
            table.insert(result, params:enactment(v, Value))
        end

        return unpack(result)
    end, ftype:var(Value.type), "character", ftype:var(EnumItem.type)),

    has_parameter = ftype:write(function (self: character, ...: enumitem_character_parameter_variant) : boolean
        const params = private.get_maybe(self)

        for _, v in {...} do
            if not params:exist(v) then
                return false
            end
        end

        return true
    end, declare.boolean, "character", ftype:var(EnumItem.type)),

    get_abilities = ftype:write(function (self: character) : ...ability
        return error "TODO"
    end, ftype:var("ability"), "character"),

    get_inventory = ftype:write(function (self: character) : any
        return error "TODO"
    end, "inventory", "character"),

    get_model_reference = ftype:write(function (self: character) : reference<Model>
        return private.maybe_model:enactment(self, Reference) 
    end, Reference.type, "character"),

    get_humanoid_reference = ftype:write(function (self: character) : reference<Humanoid>
        return private.maybe_hum:enactment(self, Reference) 
    end, Reference.type, "character"),

    get_info = ftype:write(function (self: character) : characterinfo
        return self:get <<characterinfo>> (private.info_key)
    end, CharacterInfo.type, "character"),

    set_info = ftype:write(function (self: character, new: characterinfo) : ()
        self:set(private.info_key, new)
    end, declare["nil"], "character", CharacterInfo.type)
}

class:host(function(new)
    const new = new:as <<character>> (class.type)

    new:set_info(private.default_character_info)
    new:set_token(DefaultVariant.Unknown)
    new:set(private.maybe_key, Maybe:new())
end)

do
    private.default_character_info = CharacterInfo:new()
    private.info_key = SecurityRNG:get_hash_blake3("character_info_key")
    private.maybe_key = SecurityRNG:get_hash_blake3("character_maybe_key")
    private.token_key = SecurityRNG:get_hash_sha256("character_token_key")
    private.maybe_hum = Maybe:new() :: maybe<reference<Humanoid>, character>
    private.maybe_model = Maybe:new() :: maybe<reference<Model>, character>
    
    private.get_maybe = function (self: character)
        return self:get <<maybe<value<number>, enumitem>>>(private.maybe_key)
    end

    ctype:read(class):write_tag(ctags.game)
end

return class