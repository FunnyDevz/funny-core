--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_action_map_variant = EnumObject:new({
	name = script.Name,

	MoveForward = EnumObject.build_enumitem_mark,
	MoveBackward = EnumObject.build_enumitem_mark,
	MoveLeft = EnumObject.build_enumitem_mark,
	MoveRight = EnumObject.build_enumitem_mark,
	MoveJump = EnumObject.build_enumitem_mark,
	MoveCrounch = EnumObject.build_enumitem_mark,
	MoveLying = EnumObject.build_enumitem_mark,
	MoveRun = EnumObject.build_enumitem_mark,
	MoveSlow = EnumObject.build_enumitem_mark,
})

return class
