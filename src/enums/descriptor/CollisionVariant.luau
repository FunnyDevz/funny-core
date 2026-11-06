--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_collision_variant = EnumObject:new({
	name = script.Name,

	DefaultGroup = EnumObject.build_enumitem_mark,
	ItemGroup = EnumObject.build_enumitem_mark,
	CharacterGroup = EnumObject.build_enumitem_mark,
	DebrisGroup = EnumObject.build_enumitem_mark,
})

return class
