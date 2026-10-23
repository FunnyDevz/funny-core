--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_binder_notification = EnumObject:new({
	name = script.Name,

	Bound = EnumItem:new() :: enumitem<any>,
	Unbound = EnumItem:new() :: enumitem<any>,
})

return class
