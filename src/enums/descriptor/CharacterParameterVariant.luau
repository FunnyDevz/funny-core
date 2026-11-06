--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_character_parameter_variant = EnumObject:new({
	name = script.Name,

	Health = EnumObject.build_enumitem_mark,
	Speed = EnumObject.build_enumitem_mark,
	Stamina = EnumObject.build_enumitem_mark,
	RunSpeed = EnumObject.build_enumitem_mark,
	JumpCooldown = EnumObject.build_enumitem_mark,
	RunCooldown = EnumObject.build_enumitem_mark,
	Revives = EnumObject.build_enumitem_mark,
})

return class
