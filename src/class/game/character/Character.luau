--!strict
const Reference = require("@class/common/Reference")
const Value = require("@class/common/Value")
const Maybe = require("@class/common/gc/Maybe")
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const Inventory = require("@class/game/inventory/Inventory")
const ItemContext = require("@class/game/inventory/ItemContext")
const ItemInstance = require("@class/game/inventory/ItemInstance")
const ItemStack = require("@class/game/inventory/ItemStack")
const CharacterInfo = require("@class/struct/game/CharacterInfo")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const ItemContextVariant = require("@enums/descriptor/ItemContext")
const std = require("@extension/std")
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

    get_inventory = ftype:write(function (self: character) : inventory
        return private.maybe_inventory:extract(self, function ()
            return Inventory:new({ max = self:get_info().inventory_max })
        end)
    end, Inventory.type, "character"),

    get_equipped = ftype:write(function (self: character) : iteminstance?
        return self:get <<iteminstance?>> (private.equipped_key)
    end, ftype:opt(ItemInstance.type), "character"),

    set_equipped = ftype:write(function (self: character, to: iteminstance?) : ()
        const current = self:get_equipped()

        if current == to then
            return
        end

        if to and not std:check(self:get_inventory():find(to), "cannot equip an item that isn't in the inventory") then
            return
        end

        self:set(private.equipped_key, to)

        if current then
            private.invoke(self, current, "on_unequip", ItemContextVariant.Primary)
        end

        if to then
            private.invoke(self, to, "on_equip", ItemContextVariant.Primary)
        end
    end, mtypes.never, "character", ftype:opt(ItemInstance.type)),

    take_item = ftype:write(function (self: character, ...: iteminstance) : ()
        const inventory = self:get_inventory()

        for k, v in { ... } do
            const stack = self:that <<itemstack>> (v, ItemStack.type)
            const before = if stack then stack:count() else 0

            inventory:insert(v)

            if inventory:find(v) or (stack and stack:count() < before) then
                private.invoke(self, v, "on_take", ItemContextVariant.Primary)
            end
        end
    end, mtypes.never, "character", ftype:var(ItemInstance.type)),

    drop_item = ftype:write(function (self: character, ...: iteminstance) : ()
        const inventory = self:get_inventory()

        for k, v in { ... } do
            if not inventory:find(v) then
                continue
            end

            if self:get_equipped() == v then
                self:set_equipped(nil)
            end

            inventory:remove(v)
            private.invoke(self, v, "on_drop", ItemContextVariant.Primary)
        end
    end, mtypes.never, "character", ftype:var(ItemInstance.type)),

    use_item = ftype:write(function (self: character, context: enumitem_item_context, delta: number) : ()
        const equipped = self:get_equipped()

        if equipped then
            private.invoke(self, equipped, "action", context, delta)
        end
    end, mtypes.never, "character", EnumItem.type, types.number),

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

        if private.maybe_inventory:exist(self) then
            self:get_inventory().max = new.inventory_max
        end
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
    private.info_key = newproxy()
    private.maybe_key = newproxy()
    private.token_key = newproxy()
    private.equipped_key = newproxy()
    private.maybe_inventory = Maybe:new() :: maybe<inventory, character>
    private.maybe_hum = Maybe:new() :: maybe<reference<Humanoid>, character>
    private.maybe_model = Maybe:new() :: maybe<reference<Model>, character>
    
    private.invoke = function (self: character, instance: iteminstance, hook: string, context: enumitem_item_context, ...: any)
        const item = instance:get_item():get_value()

        if not item then
            return
        end

        const behavior = item.behavior :: any
        const callback = behavior[hook]

        if type(callback) ~= types["function"] then
            return
        end

        const succ, err = pcall(callback, behavior, ItemContext:new({
            related = instance,
            user = self,
            context = context,
        }), ...)

        if not succ then
            std:outw(`item {item.name} {hook} failed: {err}`)
        end
    end

    private.get_maybe = function (self: character)
        return self:get <<maybe<value<number>, enumitem>>>(private.maybe_key)
    end
end

return class