--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_faction_notification = EnumObject:new({
	name = script.Name,

	MemberJoined = EnumObject.build_enumitem_mark,
	MemberRemoved = EnumObject.build_enumitem_mark,
})

return class
