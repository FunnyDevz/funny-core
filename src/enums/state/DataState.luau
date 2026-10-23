--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_data_state = EnumObject:new({
	name = script.Name,

	ProfileLoading = EnumItem:new() :: enumitem<any>,
	ProfileLoaded = EnumItem:new() :: enumitem<any>,
	ProfileReleased = EnumItem:new() :: enumitem<any>,
})

return class
