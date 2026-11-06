--!strict

const EnumObject = require("@class/core/EnumObject")

const class: enum_data_state = EnumObject:new({
	name = script.Name,

	ProfileLoading = EnumObject.build_enumitem_mark,
	ProfileLoaded = EnumObject.build_enumitem_mark,
	ProfileReleased = EnumObject.build_enumitem_mark,
})

return class
