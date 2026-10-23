--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_statemachine_notification = EnumObject:new({
	name = script.Name,

	ChangedState = EnumItem:new() :: enumitem<any>,
	NewState = EnumItem:new() :: enumitem<any>,
	BlacklistAdded = EnumItem:new() :: enumitem<any>,
	BlacklistRemoved = EnumItem:new() :: enumitem<any>,
})

return class
