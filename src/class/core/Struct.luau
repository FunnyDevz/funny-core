--!strict
const LuaObject = require("@class/core/LuaObject")
const types = require("@declare/types")
const stdout = require("@extension/stdout")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

type indexed = struct & {[unknown]: unknown}

const private = {}
const class: struct = LuaObject:new({
    type = "struct",

    clone = ftype:write(function (self: struct, change: {[unknown]: unknown}?) : any
        const base = self:base():as <<struct>> ("struct")
        const reconv = table.clone(self) :: indexed

        if change then

            -- Keep an eye on what you send here, the local code changes the structure before it freezes

            for i,v in change do
                reconv[i] = v
            end
        end
        
        if base then
            const new = base:new(reconv)
            return new
        else
            stdout:oute "cannot take base, return self"
            return self
        end
    end, "struct", "struct"),

    each = ftype:write(function (self: struct, type: string, f: (value: any) -> any) : {[unknown]: any}
        return private.for_each_element_with_type_do(self, type, f) :: any
    end, types.table, "struct", types.string, types["function"])
})

do
    function private.for_each_element_with_type_do(that: struct, type: string, f: (value: unknown) -> unknown)
        const out = {}
        
        for i, v in that :: { [unknown]: unknown } do
            if typeof(v) == type then
                out[i] = f(v)
            end
        end

        return out
    end

    function private.recursive_convertion(self: {[unknown]: unknown}|{}): { [unknown]: unknown }
        const result: {[unknown]: unknown} = {}

        for i, v in self :: {[any]: any} do
            result[ class:that(class.base(i :: any), "struct") and class.clone(i) or
                type(i) == "table" and private.recursive_convertion(i :: {[unknown]: unknown} or
                i) ] = class:that(class.base(v :: any), "struct") and class.clone(v) or
                type(v) == "table" and private.recursive_convertion(v :: {[unknown]: unknown} or
                v)
        end

        return result
    end

    class:finally(function(self: luaobject, base)
        table.freeze(self)
    end)
end

ctype:read(class):write_tag(ctags.struct, ctags.core)

return class