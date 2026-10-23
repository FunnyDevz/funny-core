--!strict

const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_direction_variant = EnumObject:new({
	name = script.Name,

	Up = EnumItem:new() :: enumitem<any>,
	Bottom = EnumItem:new() :: enumitem<any>,
	Left = EnumItem:new() :: enumitem<any>,
	Right = EnumItem:new() :: enumitem<any>,
	Front = EnumItem:new() :: enumitem<any>,
	Back = EnumItem:new() :: enumitem<any>,
})

return class
