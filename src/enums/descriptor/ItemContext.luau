--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_item_context = EnumObject:new({
	name = script.Name,

	Primary = EnumObject.build_enumitem_mark,
	Secondary = EnumObject.build_enumitem_mark,
	Cycle = EnumObject.build_enumitem_mark,
	Special = EnumObject.build_enumitem_mark,
})

return class
