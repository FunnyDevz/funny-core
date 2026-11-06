--!strict

const EnumObject = require("@class/core/EnumObject")

const class: enum_state = EnumObject:new({
	name = script.Name,
	Failure = EnumObject.build_enumitem_mark,
	Loading = EnumObject.build_enumitem_mark,
	Successful = EnumObject.build_enumitem_mark,
	Nothing = EnumObject.build_enumitem_mark,
})

return class
