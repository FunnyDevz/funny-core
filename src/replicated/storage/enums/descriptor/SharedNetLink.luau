--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const EnumObject = require("@game/ReplicatedStorage/class/core/EnumObject")

const class: enum_shared_net_link = EnumObject:new({
	name = script.Name,

	Data = EnumItem:new() :: enumitem<any>,
})

return class
