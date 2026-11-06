--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_list_notification = EnumObject:new({
	name = script.Name,

	AddedElement = EnumObject.build_enumitem_mark,
	RemovedElement = EnumObject.build_enumitem_mark,
	ListFull = EnumObject.build_enumitem_mark,
	ListEmpty = EnumObject.build_enumitem_mark,
	ListHalf = EnumObject.build_enumitem_mark,
})

return class
