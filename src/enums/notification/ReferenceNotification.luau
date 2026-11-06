--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_reference_notification = EnumObject:new({
	name = script.Name,

	NewInstance = EnumObject.build_enumitem_mark,
	ChangedInstance = EnumObject.build_enumitem_mark,
	DestroyedInstance = EnumObject.build_enumitem_mark,
	NullifiedInstance = EnumObject.build_enumitem_mark,
})

return class
