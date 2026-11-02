--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_user_notification = EnumObject:new({
	name = script.Name,

	ServerJoin = EnumItem:new() :: enumitem<any>,
	ServerExit = EnumItem:new() :: enumitem<any>,

	ServerDataRequest = EnumItem:new() :: enumitem<any>,
	ServerDataChanged = EnumItem:new() :: enumitem<any>,
})

return class
