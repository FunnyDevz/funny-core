--!strict

const EnumObject = require("@class/core/EnumObject")

const class: enum_controller_state = EnumObject:new({
	name = script.Name,
	Continue = EnumObject.build_enumitem_mark,
	Pause = EnumObject.build_enumitem_mark,
	Reset = EnumObject.build_enumitem_mark,
})

return class
