--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_tick_notification = EnumObject:new({
	name = script.Name,

	Started = EnumItem:new() :: enumitem<any>,
	Stepped = EnumItem:new() :: enumitem<any>,
	Paused = EnumItem:new() :: enumitem<any>,
	Resumed = EnumItem:new() :: enumitem<any>,
	Finished = EnumItem:new() :: enumitem<any>,
})

return class
