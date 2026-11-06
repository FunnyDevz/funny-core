--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_attribute_notification = EnumObject:new({
	name = script.Name,

	Added = EnumObject.build_enumitem_mark,
	Changed = EnumObject.build_enumitem_mark,
	Removed = EnumObject.build_enumitem_mark,
})

return class
