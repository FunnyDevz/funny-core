--!strict
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const EnumObject = require("@game/ReplicatedStorage/class/core/EnumObject")

const class: enum_shared_net_variant = EnumObject:new({
	name = script.Name,

	Unsafe = EnumItem:new() :: enumitem<any>,
	Safe = EnumItem:new() :: enumitem<any>,
	Internal = EnumItem:new() :: enumitem<any>,

	get_variant = function(self: enum_shared_net_variant, of: enumitem_shared_net_variant): string
		if of == self.Unsafe then
			return "UnreliableRemoteEvent"
		elseif of == self.Safe then
			return "RemoteEvent"
		end

		return "BindableEvent"
	end,
})

return class
