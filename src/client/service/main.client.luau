const Players = game:GetService("Players")

const IKR6Legs = require("@game/ReplicatedStorage/class/game/play/characters/ik/r6/IKR6Legs")
const IKR6LegInfo = require("@game/ReplicatedStorage/class/struct/game/ik/IKR6LegInfo")
const DataClient = require("@game/ReplicatedStorage/class/service/DataClient")

DataClient:start()




const function character_added (model: Model)
	const ik = IKR6Legs:new()

	const ref_humanoid = ik:get_humanoid()
	const ref_torso = ik:get_torso()

	ref_humanoid:set_instance(model:WaitForChild("Humanoid") :: Humanoid)
	ref_torso:set_instance(model:WaitForChild("Torso") :: BasePart)

	const left_leg = ik:get_left_leg()
	const right_leg = ik:get_right_leg()

	const left_leg_info = IKR6LegInfo:new({
		limb_diff = -IKR6LegInfo.limb_diff,
	})

	const right_leg_info = IKR6LegInfo:new()

	left_leg:set_info(left_leg_info)
	right_leg:set_info(right_leg_info)
	left_leg:set_visible(true)
	right_leg:set_visible(true)

	left_leg.enabled = true
	right_leg.enabled = true
	ik.enabled = true
end

const function player_added (player: Player)
    if player.Character then
        character_added(player.Character)
    end

    player.CharacterAdded:Connect(character_added)
end

for _, v in Players:GetPlayers() do
    player_added(v)
end

Players.PlayerAdded:Connect(player_added)