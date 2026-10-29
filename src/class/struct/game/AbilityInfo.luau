--!strict

const Struct = require("@class/core/Struct")

const class: abilityinfo = Struct:new({
	type = "abilityinfo",
	has_cooldown = false,
	has_stun = false,
	has_kickback = false,
	has_recoil = false,
	has_slow = false,
	has_self_slow = false,

	cooldown = 0,
	stun = 0,
	recoil = 0,
	kickback = 0,
	slow = 0,

	can_move_on_prepare_time = false,
	can_move_on_action_time = false,
	can_move_on_post_action_time = false,

	prepare_action_time = 0,
	work_action_time = 0,
	post_action_time = 0,
})


return class