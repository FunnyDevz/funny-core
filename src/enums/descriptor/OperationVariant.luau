--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_operation_variant = EnumObject:new({
	name = script.Name,

	Remove = EnumObject.build_enumitem_mark,
	New = EnumObject.build_enumitem_mark,
	Change = EnumObject.build_enumitem_mark,
})

return class
