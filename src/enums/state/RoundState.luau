--!strict

const EnumObject = require("@class/core/EnumObject")

const class: enum_round_state = EnumObject:new({
	name = script.Name,
	Preparing = EnumObject.build_enumitem_mark,
	Begining = EnumObject.build_enumitem_mark,
	AtWork = EnumObject.build_enumitem_mark,
	Ending = EnumObject.build_enumitem_mark,
	Ended = EnumObject.build_enumitem_mark,
})

return class
