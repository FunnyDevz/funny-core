--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_input_notification = EnumObject:new({
	name = script.Name,

	CodeAdded = EnumObject.build_enumitem_mark,
	CodeRemoved = EnumObject.build_enumitem_mark,
	Pressed = EnumObject.build_enumitem_mark,
	Clamped = EnumObject.build_enumitem_mark,
	Stopped = EnumObject.build_enumitem_mark,
	RelatedChanged = EnumObject.build_enumitem_mark,
	RelatedNullified = EnumObject.build_enumitem_mark,
	NetworkEnabled = EnumObject.build_enumitem_mark,
	NetworkDisabled = EnumObject.build_enumitem_mark,
})

return class
