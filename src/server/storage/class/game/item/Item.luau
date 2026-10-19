--!strict
const PickUp = require("@game/ReplicatedStorage/class/PickUp")
const StateMachine = require("@game/ReplicatedStorage/class/StateMachine")
const Maybe = require("@game/ReplicatedStorage/class/common/gc/Maybe")
const declare = require("@game/ReplicatedStorage/static/declare")
const dgame = require("@game/ReplicatedStorage/static/dgame")
const project = require("@game/ReplicatedStorage/static/project")
const ItemNotification = require("@game/ServerStorage/enums/notification/ItemNotification")

const private = {}
const class: dgame.item = (PickUp :: declare.pickup<dgame.enumitem_item_notification>):new({
	type = "item",
    owner = nil :: unknown,
	equipable = false,

    equip = function(self: dgame.item) : ()
        if self.equipable and not self:is_equipped() then
            private.equipped[self] = true
            self:notificate(ItemNotification.Equipped)
        end
    end,

    unequip = function (self: dgame.item) : ()
        if self.equipable and self:is_equipped() then
            private.equipped[self] = false
            self:notificate(ItemNotification.Unequipped)
        end
    end,

    is_equipped = function (self: dgame.item) : boolean
        return private.equipped[self] or false
    end,
	
    show_item = function(self: dgame.item, set: boolean?): ()
        project.console_out_error "TODO"
    end,

	get_main_grip = function(self: dgame.item): declare.reference<PVInstance?>?
        return private.grip[self]
    end,

    set_main_grip = function (self: dgame.item, to: declare.reference<PVInstance?>?) : ()
        private.grip[self] = to
    end,

	get_secondary_grip = function(self: dgame.item): declare.reference<PVInstance?>?
        const limit = #private.grips[self]

        if limit > 0 then
            const rand = Random.new():NextInteger(1, limit)
            return private.grips[self][rand]
        end
        
        return nil
    end,

	insert_secondary_grip = function(self: dgame.item, of: declare.reference<PVInstance?>): ()
        const grips = private.grips[self]
        const pos = table.find(grips, of)

        if not pos then
            table.insert(grips, of)
        end
    end,

	remove_secondary_grip = function(self: dgame.item, of: declare.reference<PVInstance?>): ()
        const grips = private.grips[self]
        const pos = table.find(grips, of)

        if pos then
            table.remove(grips, pos)
        end
    end,

	get_state_machine = function(self: dgame.item): declare.statemachine<declare.enumitem>
        return private.sfm:extract(self, function()
            return StateMachine:new() :: declare.statemachine<declare.enumitem>
        end)
    end,

    get_owner = function (self: dgame.item)
        if not self.owner then return nil end

        const LuaObject = self.require <<declare.LuaObject?>>(self.owner)
        if LuaObject then
            if self.is(LuaObject, "unit") or self.is(LuaObject, "inventory") then
                return LuaObject
            else
                project.console_out_error "owner of the item is being used incorrectly because the resulting LuaObject is not an authorized LuaObject, and the result has been reset"
            end
        end

        return nil
    end
})

class:host(function(new: dgame.item)
    private.grips[new] = {}
end)

do
    private.meta = table.freeze {__mode = "ks"}
    private.sfm = Maybe:new()
    private.grips = setmetatable({} :: {[dgame.item]: {declare.reference<PVInstance?>}}, private.meta)
    private.grip = setmetatable({} :: {[dgame.item]: declare.reference<PVInstance?>?}, private.meta)
    private.equipped = setmetatable({} :: {[dgame.item]: boolean?}, private.meta)
end

return class
