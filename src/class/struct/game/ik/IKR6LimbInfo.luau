--!strict
const Struct = require("@class/core/Struct")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

const class: ikr6limbinfo = Struct:new {
    type = "ikr6limbinfo",

    limb_diff = 0.64,
    limb_size = vector.create(1,2,1),
	limb_block_distance = 0.45,
    limb_fallback_speed = 50,
    limb_distance_trigger_at = 0.5,
	limb_movement_speed_min = 10,
	limb_movement_speed_max = 80,
	limb_movement_velocity_min = 0,
	limb_movement_velocity_max = 36,
	limb_orientation_speed_min = 10,
	limb_orientation_speed_max = 100,
	limb_planted_speed = 50,
	limb_rotation_inverse_coefficient = 0.5,
	limb_prediction_time_min = 0.001,
	limb_prediction_time_max = 0.1,
	limb_prediction_curve = 1,
	limb_orientation_mistake_angle = math.rad(2),
	limb_preffer_to_origin_clone = true,
	limb_torso_relative_alpha = 0.05
}

ctype:read(class):write_tag(ctags.game, ctags.immersiveness, ctags.inverse_kinematic, ctags.struct)

return class