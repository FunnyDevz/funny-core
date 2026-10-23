--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_reference_notification = EnumObject:new({
	name = script.Name,

	NewInstance = EnumItem:new() :: enumitem<any>,
	ChangedInstance = EnumItem:new() :: enumitem<any>,
	DestroyedInstance = EnumItem:new() :: enumitem<any>,
	NullifiedInstance = EnumItem:new() :: enumitem<any>,
})

return class
