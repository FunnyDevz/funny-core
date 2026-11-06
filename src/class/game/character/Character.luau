--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Reference = require("@class/common/Reference")
const Value = require("@class/common/Value")
const Maybe = require("@class/common/gc/Maybe")
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const Ability = require("@class/game/Ability")
const Inventory = require("@class/game/inventory/Inventory")
const ItemContext = require("@class/game/inventory/ItemContext")
const ItemInstance = require("@class/game/inventory/ItemInstance")
const ItemStack = require("@class/game/inventory/ItemStack")
const CharacterInfo = require("@class/struct/game/CharacterInfo")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const DefaultVariant = require("@enums/descriptor/DefaultVariant")
const ItemContextVariant = require("@enums/descriptor/ItemContext")
const ItemNotification = require("@enums/notification/ItemNotification")
const std = require("@extension/std")
const ftype = require("@static/ftype")

const private = {type = "character"}
const class : character = (Observer :: observer<>) :new {
    type = private.type,

    get_token = ftype:write(function (self: character) : enumitem
        return self:get <<enumitem>>(private.token_key)
    end, EnumItem.type, private.type),

    set_token = ftype:write(function (self: character, new: enumitem) : ()
        self:set(private.token_key, new)
    end, mtypes.never, private.type, EnumItem.type),

    get_parameter = ftype:write(function (self: character, ...: enumitem_character_parameter_variant) : ...value<number>
        const result: {value<number>} = {}
        const params = private.get_maybe(self)

        for _, v in {...} do
            table.insert(result, params:enactment(v, Value))
        end

        return unpack(result)
    end, ftype:var(Value.type), private.type, ftype:var(EnumItem.type)),

    has_parameter = ftype:write(function (self: character, ...: enumitem_character_parameter_variant) : boolean
        const params = private.get_maybe(self)

        for _, v in {...} do
            if not params:exist(v) then
                return false
            end
        end

        return true
    end, types.boolean, private.type, ftype:var(EnumItem.type)),

    get_abilities = ftype:write(function (self: character) : ...ability
        return error "TODO"
    end, ftype:var(Ability.type), private.type),

    get_inventory = ftype:write(function (self: character) : inventory
        return private.maybe_inventory:extract(self, function ()
            return Inventory:new({ max = self:get_info().inventory_max })
        end)
    end, Inventory.type, private.type),

    get_equipped = ftype:write(function (self: character) : iteminstance?
        return self:get <<iteminstance?>> (private.equipped_key)
    end, ftype:opt(ItemInstance.type), private.type),

    set_equipped = ftype:write(function (self: character, to: iteminstance?) : ()
        const current = self:get_equipped()

        if current == to then return end
        if to and not std:check(self:get_inventory():find(to), "cannot equip an item that isn't in the inventory") then return end

        self:set(private.equipped_key, to)

        if current then private.invoke(self, current, ItemNotification.Unequip, ItemContextVariant.Primary) end
        if to then private.invoke(self, to, ItemNotification.Equip, ItemContextVariant.Primary) end
    end, mtypes.never, private.type, ftype:opt(ItemInstance.type)),

    take_item = ftype:write(function (self: character, ...: iteminstance) : ()
        const inventory = self:get_inventory()

        for k, v in { ... } do
            const stack = self:that <<itemstack>> (v, ItemStack.type)
            const before = if stack then stack:count() else 0

            inventory:insert(v)

            if inventory:find(v) or (stack and stack:count() < before) then
                private.invoke(self, v, ItemNotification.Take, ItemContextVariant.Primary)
            end
        end
    end, mtypes.never, private.type, ftype:var(ItemInstance.type)),

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
            private.invoke(self, v, ItemNotification.Drop, ItemContextVariant.Primary)
        end
    end, mtypes.never, private.type, ftype:var(ItemInstance.type)),

    use_item = ftype:write(function (self: character, context: enumitem_item_context, delta: number) : ()
        const equipped = self:get_equipped()

        if equipped then
            private.invoke(self, equipped, ItemNotification.Action, context, delta)
        end
    end, mtypes.never, private.type, EnumItem.type, types.number),

    get_model_reference = ftype:write(function (self: character) : reference<Model>
        return private.maybe_model:enactment(self, Reference) 
    end, Reference.type, private.type),

    get_humanoid_reference = ftype:write(function (self: character) : reference<Humanoid>
        return private.maybe_hum:enactment(self, Reference) 
    end, Reference.type, private.type),

    get_info = ftype:write(function (self: character) : characterinfo
        return self:get <<characterinfo>> (private.info_key)
    end, CharacterInfo.type, private.type),

    set_info = ftype:write(function (self: character, new: characterinfo) : ()
        self:set(private.info_key, new)

        if private.maybe_inventory:exist(self) then
            self:get_inventory().max = new.inventory_max
        end
    end, mtypes.never, private.type, CharacterInfo.type)
}

do
    private.default_character_info = CharacterInfo:new()
    private.info_key = newproxy()
    private.maybe_key = newproxy()
    private.token_key = newproxy()
    private.equipped_key = newproxy()
    private.maybe_inventory = Maybe:new() :: maybe<inventory, character>
    private.maybe_hum = Maybe:new() :: maybe<reference<Humanoid>, character>
    private.maybe_model = Maybe:new() :: maybe<reference<Model>, character>

    private.new = function (new: luaobject)
        const new = new:as <<character>> (class.type)

        new:set_info(private.default_character_info)
        new:set_token(DefaultVariant.Unknown)
        new:set(private.maybe_key, Maybe:new())
    end

    --#if ALL_CLASS_USEABLE
    private.new(class)
    --#endif

    private.invoke = function (
        self: character,
        instance: iteminstance,
        notification: enumitem_item_notification,
        context: enumitem_item_context,
        delta: number?
    )
        const item = instance:get_item():get_value()

        if not item then
            return
        end

        const behavior = instance:get_behavior() or item.behavior
        const payload = ItemContext:new({
            related = instance,
            user = self,
            context = context,
            delta = delta or 0,
        })

        const succ, err = pcall(behavior.invoke, behavior, notification, behavior, payload)

        --#if DEBUG
        if not succ then
            std:outw(`item {item.name} {notification.name} failed: {err}`)
        end
        --#endif
    end

    private.get_maybe = function (self: character)
        return self:get <<maybe<value<number>, enumitem>>>(private.maybe_key)
    end
end

class:host(private.new)

return class
