--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_user_machine_variant = EnumObject:new({
	name = script.Name,

	Computer = EnumItem:new() :: enumitem<any>,
	Mobile = EnumItem:new() :: enumitem<any>,
	Console = EnumItem:new() :: enumitem<any>,
	AnotherDevice = EnumItem:new() :: enumitem<any>,
})

return class
