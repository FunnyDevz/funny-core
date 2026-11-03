--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_list_notification = EnumObject:new({
	name = script.Name,

	AddedElement = EnumItem:new() :: enumitem<any>,
	RemovedElement = EnumItem:new() :: enumitem<any>,
	ListFull = EnumItem:new() :: enumitem<any>,
	ListEmpty = EnumItem:new() :: enumitem<any>,
	ListHalf = EnumItem:new() :: enumitem<any>,
})

return class
