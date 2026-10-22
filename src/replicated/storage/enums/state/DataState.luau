--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const EnumObject = require("@game/ReplicatedStorage/class/core/EnumObject")

const class: enum_data_state = EnumObject:new({
	name = script.Name,

	ProfileLoading = EnumItem:new() :: enumitem<any>,
	ProfileLoaded = EnumItem:new() :: enumitem<any>,
	ProfileReleased = EnumItem:new() :: enumitem<any>,
})

return class
