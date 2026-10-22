--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const EnumObject = require("@game/ReplicatedStorage/class/core/EnumObject")

const class: enum_net_notification = EnumObject:new({
	name = script.Name,

	Received = EnumItem:new() :: enumitem<any>,
})

return class
