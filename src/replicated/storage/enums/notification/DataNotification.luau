--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const EnumObject = require("@game/ReplicatedStorage/class/core/EnumObject")

const class: enum_data_notification = EnumObject:new({
	name = script.Name,

	DataStateChanged = EnumItem:new() :: enumitem<any>,
	DataLoaded = EnumItem:new() :: enumitem<any>,
	DataReleased = EnumItem:new() :: enumitem<any>,
	DataChanged = EnumItem:new() :: enumitem<any>,
	DataMessage = EnumItem:new() :: enumitem<any>,
})

return class
