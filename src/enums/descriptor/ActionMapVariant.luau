--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_action_map_variant = EnumObject:new({
	name = script.Name,

	MoveForward = EnumItem:new() :: enumitem<any>,
	MoveBackward = EnumItem:new() :: enumitem<any>,
	MoveLeft = EnumItem:new() :: enumitem<any>,
	MoveRight = EnumItem:new() :: enumitem<any>,
	MoveJump = EnumItem:new() :: enumitem<any>,
	MoveCrounch = EnumItem:new() :: enumitem<any>,
	MoveLying = EnumItem:new() :: enumitem<any>,
	MoveRun = EnumItem:new() :: enumitem<any>,
	MoveSlow = EnumItem:new() :: enumitem<any>,
})

return class
