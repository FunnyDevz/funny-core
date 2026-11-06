--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_connection_variant = EnumObject:new({
	name = script.Name,

	Ever = EnumObject.build_enumitem_mark,
	Once = EnumObject.build_enumitem_mark,
	Skip = EnumObject.build_enumitem_mark,
	Hold = EnumObject.build_enumitem_mark,
	Next = EnumObject.build_enumitem_mark,
})

return class
