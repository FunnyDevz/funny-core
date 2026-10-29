--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_operation_variant = EnumObject:new({
	name = script.Name,
	Remove = EnumItem:new() :: enumitem<any>,
	New = EnumItem:new() :: enumitem<any>,
	Change = EnumItem:new() :: enumitem<any>,
})

return class
