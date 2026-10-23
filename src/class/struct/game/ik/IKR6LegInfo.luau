--!strict
const IKR6LimbInfo = require("@class/struct/game/ik/IKR6LimbInfo")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

-- TODO
-- planted_speed min/max

const class: ikr6leginfo = IKR6LimbInfo:new({
	type = "ikr6leginfo",

    leg_raycast_up = 2,
    leg_raycast_down = 3,
	leg_step_max_height = 0.65,
	leg_step_obstacle_height = 0.12,
	leg_step_forward = 0.1,
	leg_stand_forward = 0.1,
	leg_idle_step_forward = 0.01,
})

ctype:read(class):write_tag(ctags.game, ctags.immersiveness, ctags.inverse_kinematic, ctags.struct)

return class