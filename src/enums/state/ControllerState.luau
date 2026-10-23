--!strict

const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_controller_state = EnumObject:new({
	name = script.Name,
	Continue = EnumItem:new() :: enumitem<any>,
	Pause = EnumItem:new() :: enumitem<any>,
	Reset = EnumItem:new() :: enumitem<any>,
})

return class
