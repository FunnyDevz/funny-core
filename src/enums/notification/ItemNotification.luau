--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_item_notification = EnumObject:new({
	name = script.Name,

	Equip = EnumObject.build_enumitem_mark,
	Unequip = EnumObject.build_enumitem_mark,
	Take = EnumObject.build_enumitem_mark,
	Drop = EnumObject.build_enumitem_mark,
	Action = EnumObject.build_enumitem_mark,
})

return class
