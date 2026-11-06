const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const std = require("@extension/std")
const ftype = require("@static/ftype")

const private = {type = "template"}
const class : template = (Observer :: observer<enumitem_operation_variant>):new {
    type = private.type,

    get_template = ftype:write(function (self: template) : any
        return self:get(private.template_key)
    end, types.table, private.type),

    set_template = ftype:write(function (self: template, to: {[any]: any}) : ()
        --#if DEBUG
        if not std:check(type(to) == types.table, "received non-table type") then
            return
        end
        --#endif

        self:set(private.template_key, to)
        self:notificate(OperationVariant.Change, to)
    end, mtypes.never, private.type, types.table),

    free_for = ftype:write(function (self: template, key: any) : ()
    	const storage = self:get<<{ [unknown]: { [unknown]: unknown } }>>(private.storage_key)
        const stored = storage[key]

        if stored ~= nil then
            storage[key] = nil
            self:notificate(OperationVariant.Remove, key)
        end
    end, mtypes.never, private.type, ftype:uor(table.unpack(types.link_types))),

    allocate_for = ftype:write(function (self: template, key: any) : {[unknown]: unknown}
    	const storage = self:get <<{[unknown]: {[unknown]: unknown}}>>(private.storage_key)
        const stored = storage[key]
        if stored ~= nil then
            return stored
        end

        const value_to_clone = self:get <<any>>(private.template_key)
        local to_store

        if type(value_to_clone) == types.table then
            const metatable = getmetatable(value_to_clone)

            to_store = table.clone(value_to_clone)
            if (type(metatable) == types.table) then
                setmetatable(to_store, metatable)
            end
        else
            --#if DEBUG
            std:outw(`{self.type} received non-table {type(value_to_clone)}, return empty table`)
            --#endif

            to_store = {}
        end

        storage[key] = to_store :: any
        self:notificate(OperationVariant.New, key)

        return to_store :: any
    end, types.table, private.type, ftype:uor(table.unpack(types.link_types))),

    exist_for = ftype:write(function (self: template, key: any) : boolean
    	const storage = self:get<<{ [unknown]: { [unknown]: unknown } }>>(private.storage_key)
        return storage[key] ~= nil
    end, types.boolean, private.type, ftype:uor(table.unpack(types.link_types)))
}

do
    private.template_key = newproxy()
    private.storage_key = newproxy()
    private.new = function (new: luaobject) : ()
        const new = new:as <<template>> (class.type)
        new:set(private.template_key, {})
        new:set(private.storage_key, setmetatable({}, tables.__mode_ks))
    end
end

return class