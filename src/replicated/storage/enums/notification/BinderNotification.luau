--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const EnumObject = require("@game/ReplicatedStorage/class/core/EnumObject")

const class: enum_binder_notification = EnumObject:new({
	name = script.Name,

	Bound = EnumItem:new() :: enumitem<any>,
	Unbound = EnumItem:new() :: enumitem<any>,
})

return class
