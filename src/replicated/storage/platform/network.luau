--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const engine = require("@game/ReplicatedStorage/platform/engine")

return table.freeze {
    get_folder = function (name: string, timeout: number) : Instance?
        const existing = ReplicatedStorage:FindFirstChild(name)

        if (existing) then
            return existing
        end

        if (not engine.is_server) then
            return ReplicatedStorage:WaitForChild(name, timeout)
        end

        const folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = ReplicatedStorage
        return folder
    end,

    find_remote = function (folder: Instance?, name: string, timeout: number?) : Instance?
        if (not folder) then
            return nil
        end

        const existing = folder:FindFirstChild(name)

        if (existing or not timeout) then
            return existing
        end

        return folder:WaitForChild(name, timeout)
    end,

    create_remote = function (folder: Instance?, name: string, classname: string) : Instance
        const remote = Instance.new(classname)
        remote.Name = name
        remote.Parent = if engine.is_server then folder else nil
        return remote
    end,

    is_local = function (remote: Instance) : boolean
        return remote:IsA("BindableEvent")
    end,

    fire = function (remote: Instance, targets: {Player}, payload: unknown) : ()
        if (remote:IsA("BindableEvent")) then
            remote:Fire(payload)
        elseif (engine.is_server) then
            for k, v in targets do
                (remote :: any):FireClient(v, payload)
            end
        else
            (remote :: any):FireServer(payload)
        end
    end,

    listen = function (remote: Instance, f: (sender: Player?, payload: unknown) -> ()) : RBXScriptConnection
        if (remote:IsA("BindableEvent")) then
            return remote.Event:Connect(function(payload: unknown)
                f(nil, payload)
            end)
        elseif (engine.is_server) then
            return (remote :: any).OnServerEvent:Connect(function(sender: Player, payload: unknown)
                f(sender, payload)
            end)
        end

        return (remote :: any).OnClientEvent:Connect(function(payload: unknown)
            f(nil, payload)
        end)
    end,
}
