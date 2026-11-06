--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_default_variant = EnumObject:new({
	name = script.Name,

	Unknown = EnumObject.build_enumitem_mark,
	Any = EnumObject.build_enumitem_mark,
})

return class
