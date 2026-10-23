--!strict
const Reference = require("@class/common/Reference")
const Value = require("@class/common/Value")
const Maybe = require("@class/common/gc/Maybe")
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const CharacterInfo = require("@class/struct/game/CharacterInfo")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const Cryptography = require("@import/Cryptography")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const private = {}
const class : character = (Observer :: observer<>) :new {
    type = "character",

    get_token = ftype:write(function (self: character) : enumitem
        return self:get <<enumitem>>(private.token_key)
    end, EnumItem.type, "character"),

    set_token = ftype:write(function (self: character, new: enumitem) : ()
        self:set(private.token_key, new)
    end, mtypes.never, "character", EnumItem.type),

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
    end, types.boolean, "character", ftype:var(EnumItem.type)),

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
    end, mtypes.never, "character", CharacterInfo.type)
}

class:host(function(new)
    const new = new:as <<character>> (class.type)

    new:set_info(private.default_character_info)
    new:set_token(DefaultVariant.Unknown)
    new:set(private.maybe_key, Maybe:new())
end)

do
    private.default_character_info = CharacterInfo:new()
    private.info_key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "character_info_key")
    private.maybe_key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "character_maybe_key")
    private.token_key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "character_token_key")
    private.maybe_hum = Maybe:new() :: maybe<reference<Humanoid>, character>
    private.maybe_model = Maybe:new() :: maybe<reference<Model>, character>
    
    private.get_maybe = function (self: character)
        return self:get <<maybe<value<number>, enumitem>>>(private.maybe_key)
    end

    ctype:read(class):write_tag(ctags.game)
end

return class