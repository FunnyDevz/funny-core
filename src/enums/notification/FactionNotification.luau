--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_faction_notification = EnumObject:new({
	name = script.Name,

	MemberJoined = EnumItem:new() :: enumitem<any>,
	MemberRemoved = EnumItem:new() :: enumitem<any>,
})

return class
