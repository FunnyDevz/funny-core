--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_tick_notification = EnumObject:new({
	name = script.Name,

	Started = EnumObject.build_enumitem_mark,
	Stepped = EnumObject.build_enumitem_mark,
	Paused = EnumObject.build_enumitem_mark,
	Resumed = EnumObject.build_enumitem_mark,
	Finished = EnumObject.build_enumitem_mark,
})

return class
