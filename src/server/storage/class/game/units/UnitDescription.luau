--!strict
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const declare = require("@game/ReplicatedStorage/static/declare")

const class: declare.unitdescription = LuaObject:new({
	type = "unitdescription",

	max_health = 0,
	regeneration = 0,

	default_speed = 0,
	run_speed = 0,
	max_speed = 0,

	jump_height = 0,
	max_jump_height = 0,

	height = 0,
})

return class
