--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_connection_variant = EnumObject:new({
	name = script.Name,
	Ever = EnumItem:new() :: enumitem<any>,
	Once = EnumItem:new() :: enumitem<any>,
	Never = EnumItem:new() :: enumitem<any>,
	Skip = EnumItem:new() :: enumitem<any>,
	Hold = EnumItem:new() :: enumitem<any>,
	Next = EnumItem:new() :: enumitem<any>,
})

return class
