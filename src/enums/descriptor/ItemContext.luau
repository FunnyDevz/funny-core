--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_item_context = EnumObject:new({
	name = script.Name,

	Primary = EnumItem:new() :: enumitem<any>,
	Secondary = EnumItem:new() :: enumitem<any>,
	Cycle = EnumItem:new() :: enumitem<any>,
	Special = EnumItem:new() :: enumitem<any>,
})

return class
