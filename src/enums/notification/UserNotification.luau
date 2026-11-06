--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_user_notification = EnumObject:new({
	name = script.Name,

	ServerJoin = EnumObject.build_enumitem_mark,
	ServerExit = EnumObject.build_enumitem_mark,
	ServerDataRequest = EnumObject.build_enumitem_mark,
	ServerDataChanged = EnumObject.build_enumitem_mark,
})

return class
