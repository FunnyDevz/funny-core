const CollectionService = game:GetService("CollectionService")

const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const declare = require("@game/ReplicatedStorage/static/declare")
const project = require("@game/ReplicatedStorage/static/project")
const datamodel = {
    get_nodes = function (of: object): {Instance}
        return CollectionService:GetTagged(tostring(of:iden()))
    end,

    has_nodes = function (of: object) : boolean
        return #CollectionService:GetTagged(tostring(of:iden())) > 0
    end,

    add_nodes = function (of: object, ...: Instance) : ()
        const identity = tostring(of:iden())

        for i,v in {...} do
    		CollectionService:AddTag(v, identity)
        end
    end,

    rem_nodes = function (of: object, ...: Instance) : ()
        const identity = tostring(of:iden())

        for i, v in { ... } do
            CollectionService:RemoveTag(v, identity)
        end
    end,

    virtual = function (of: object) : Configuration?
        const identity = tostring(of:iden())
        const node = Instance.new("Configuration")
        node.Name = of.type .. identity
        
        const metadata = ctype:read(of)

        --#if DEBUG
        if (not metadata.guaranteed) then
            project.console_out_error("cannot create virtual node of this instance")
            return nil
        end
        --#endif

        for i,v in metadata:get_all() do
            if (v.type == declare["function"]) then continue end


        end
    end
}

return datamodel