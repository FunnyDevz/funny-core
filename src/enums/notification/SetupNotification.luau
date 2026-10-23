--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_setup_notification = EnumObject:new({
	name = script.Name,
	Install = EnumItem:new() :: enumitem<any>,
	Require = EnumItem:new() :: enumitem<any>,
	Installed = EnumItem:new() :: enumitem<any>,
	Disconnected = EnumItem:new() :: enumitem<any>,
})

return class
