--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_physx_mode_variant = EnumObject:new({
	name = script.Name,
	Local = EnumItem:new() :: enumitem<any>,
	Global = EnumItem:new() :: enumitem<any>,
})

return class
