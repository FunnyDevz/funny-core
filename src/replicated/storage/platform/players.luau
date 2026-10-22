--!strict
const Players = game:GetService("Players")

return table.freeze {
    get_by_user_id = function (user_id: number) : Player?
        return Players:GetPlayerByUserId(user_id)
    end,

    get_local = function () : Player?
        return Players.LocalPlayer
    end,

    get_all = function () : {Player}
        return Players:GetPlayers()
    end,

    is_in_game = function (player: Player) : boolean
        return player.Parent == Players
    end,

    on_added = function (f: (player: Player) -> ()) : RBXScriptConnection
        return Players.PlayerAdded:Connect(f)
    end,

    on_removing = function (f: (player: Player) -> ()) : RBXScriptConnection
        return Players.PlayerRemoving:Connect(function(player: Player)
            f(player)
        end)
    end,

    kick = function (player: Player, reason: string) : ()
        player:Kick(reason)
    end,
}
