--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_state = EnumObject:new({
	name = script.Name,
	Failure = EnumItem:new() :: enumitem<any>,
	Loading = EnumItem:new() :: enumitem<any>,
	Successful = EnumItem:new() :: enumitem<any>,
	Nothing = EnumItem:new() :: enumitem<any>,
})

return class
