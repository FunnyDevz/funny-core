--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_default_variant = EnumObject:new({
	name = script.Name,
	Unknown = EnumItem:new() :: enumitem<any>,
	Any = EnumItem:new() :: enumitem<any>,
})

return class
