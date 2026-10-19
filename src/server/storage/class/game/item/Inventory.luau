--!strict
const PickUp = require("@game/ReplicatedStorage/class/PickUp")
const ConnectionVariant = require("@game/ReplicatedStorage/enums/descriptor/ConnectionVariant")
const declare = require("@game/ReplicatedStorage/static/declare")
const dgame = require("@game/ReplicatedStorage/static/dgame")

const project = require("@game/ReplicatedStorage/static/project")
const InventoryNotification = require("@game/ServerStorage/enums/notification/InventoryNotification")

const private = {}
const class : dgame.inventory = (PickUp :: declare.pickup<dgame.enumitem_inventory_notification>):new {
    type = "inventory",
    owner = nil :: unknown,
    can_insert_items = true,
    can_remove_items = true,

    get_items_with_type = function <T> (self: dgame.inventory, type: string) : {T}
        const result = {}

        for _, v in private.items[self] do
            if v:is(type) then
                table.insert(result, v)
            end
        end

        return result    
    end,
    
    get_items = function (self: dgame.inventory<any>) : {dgame.item}
        const result = {}
        
        for _, v in private.items[self] do
            table.insert(result, v)
        end

        return result
    end,
    
    insert_item = function (self: dgame.inventory, that: dgame.item) : ()
        const is_existed = self:is_in_inventory(that)
        if is_existed then return end

        private.items[self][that.identity] = that
    	self:notificate(InventoryNotification.ItemAdded)
    end, 

    remove_item = function (self: dgame.inventory, that: dgame.item) : ()
        const is_existed = self:is_in_inventory(that)

        private.items[self][that.identity] = nil

        if is_existed then
            self:notificate(InventoryNotification.ItemRemoved) 
        end
    end,

    is_in_inventory = function (self: dgame.inventory, that: dgame.item) : boolean
        return private.items[self][that.identity] ~= nil
    end,

    get_last_added = function (self: dgame.inventory) : dgame.item?
        return private.last[self]
    end,

    get_owner = function (self: dgame.inventory) : dgame.unit|nil
        if not self.owner then return nil end

        const LuaObject = self.require <<dgame.LuaObject?>>(self.owner)
        if LuaObject then
            if self.is(LuaObject, "unit") then
                return LuaObject :: dgame.unit
            else
                project.console_out_error "owner of the item is being used incorrectly because the resulting LuaObject is not an authorized LuaObject, and the result has been reset"
            end
        end

        return nil
    end
}

class:host(function(new: dgame.inventory)
    new:subscribe(InventoryNotification.ItemAdded, ConnectionVariant.Ever, function ()
        
    end)
end)

do
    private.meta = table.freeze {__mode = "ks"}
    private.items = setmetatable({} :: {[dgame.inventory]: {[unknown]: dgame.item?}}, private.meta)
    private.last = setmetatable({} :: {[dgame.inventory]: dgame.item?}, private.meta)
end

return class