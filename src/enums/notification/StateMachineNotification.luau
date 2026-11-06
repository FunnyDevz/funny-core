--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_statemachine_notification = EnumObject:new({
	name = script.Name,

	ChangedState = EnumObject.build_enumitem_mark,
	NewState = EnumObject.build_enumitem_mark,
	BlacklistAdded = EnumObject.build_enumitem_mark,
	BlacklistRemoved = EnumObject.build_enumitem_mark,
})

return class
