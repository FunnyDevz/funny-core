--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_physx_mode_variant = EnumObject:new({
	name = script.Name,

	Local = EnumObject.build_enumitem_mark,
	Global = EnumObject.build_enumitem_mark,
})

return class
