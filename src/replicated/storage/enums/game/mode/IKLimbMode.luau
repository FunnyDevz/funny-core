--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_iklimb_mode = EnumObject:new({
	name = script.Name,

	FakeIK = EnumItem:new() :: enumitem<any>,
	RealFK = EnumItem:new() :: enumitem<any>,
})

return class
