const Struct = require("@class/core/Struct")
const class: characterinfo = Struct:new({
    type = "characterinfo",
	has_health = false,
	has_stamina = false,
	has_stamina_use = false,
	has_stamina_regen = false,
	has_health_regen = false,
	has_stamina_runspeed_related_mod = false,
	has_health_runspeed_related_mod = false,
	has_jump_cooldown = false,
	has_run_cooldown = false,

	can_run = false,
	can_jump = false,
	can_move = false,
	can_die = false,
	can_revived = false,

	health = 0,
	stamina = 0,
	speed = 0,
	runspeed = 0,
	run_cooldown = 0,
	jump_cooldown = 0,
	revives = 0,
})

return class