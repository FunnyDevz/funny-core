--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_data_notification = EnumObject:new({
	name = script.Name,

	DataStateChanged = EnumObject.build_enumitem_mark,
	DataLoaded = EnumObject.build_enumitem_mark,
	DataReleased = EnumObject.build_enumitem_mark,
	DataChanged = EnumObject.build_enumitem_mark,
	DataMessage = EnumObject.build_enumitem_mark,
})

return class
