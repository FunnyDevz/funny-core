--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_attribute_notification = EnumObject:new({
	name = script.Name,
	Added = EnumItem:new() :: enumitem<any>,
	Changed = EnumItem:new() :: enumitem<any>,
	Removed = EnumItem:new() :: enumitem<any>,
})

return class
