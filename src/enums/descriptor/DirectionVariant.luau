--!strict

const EnumObject = require("@class/core/EnumObject")

const class: enum_direction_variant = EnumObject:new({
	name = script.Name,

	Up = EnumObject.build_enumitem_mark,
	Bottom = EnumObject.build_enumitem_mark,
	Left = EnumObject.build_enumitem_mark,
	Right = EnumObject.build_enumitem_mark,
	Front = EnumObject.build_enumitem_mark,
	Back = EnumObject.build_enumitem_mark,
})

return class
