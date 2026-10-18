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

    get_tagged = function (tag: string) : {Instance}
        return CollectionService:GetTagged(tag)
    end,

    on_tag_added = function (tag: string, f: (instance: Instance) -> ()) : RBXScriptConnection
        return CollectionService:GetInstanceAddedSignal(tag):Connect(f)
    end,

    on_tag_removed = function (tag: string, f: (instance: Instance) -> ()) : RBXScriptConnection
        return CollectionService:GetInstanceRemovedSignal(tag):Connect(f)
    end,

    on_ancestry_changed = function (of: Instance, f: () -> ()) : RBXScriptConnection
        return of.AncestryChanged:Connect(function()
            f()
        end)
    end,

    is_inside = function (of: Instance, ancestors: {Instance}?) : boolean
        if (not of:IsDescendantOf(game)) then
            return false
        end

        for k, v in ancestors or {workspace} do
            if (of:IsDescendantOf(v)) then
                return true
            end
        end

        return false
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