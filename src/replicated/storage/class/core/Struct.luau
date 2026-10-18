--!strict

const object = require("@game/ReplicatedStorage/object")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

type indexed = struct & {[unknown]: unknown}

const private = {}
const class: struct = object:new({
    type = "struct",

    clone = ftype:write(function (self: struct, change: {[unknown]: unknown}?) : any
        const base = self:base <<struct>>("struct")
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
            project.console_out_error "cannot take base, return self"
            return self
        end
    end, "struct", "struct"),

    each = ftype:write(function (self: struct, type: string, f: (value: any) -> any) : {[unknown]: any}
        return private.for_each_element_with_type_do(self, type, f) :: any
    end, declare.table, "struct", declare.string, declare["function"])
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
            result[ class:that(class.base(i), "struct") and class.clone(i) or
                type(i) == "table" and private.recursive_convertion(i :: {[unknown]: unknown} or
                i) ] = class:that(class.base(v), "struct") and class.clone(v) or
                type(v) == "table" and private.recursive_convertion(v :: {[unknown]: unknown} or
                v)
        end

        return result
    end
end

ctype:read(class):write_tag(ctags.struct, ctags.core)

return class