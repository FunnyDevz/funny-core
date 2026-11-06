--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_shared_net_variant = EnumObject:new({
	name = script.Name,

	Unsafe = EnumObject.build_enumitem_mark,
	Safe = EnumObject.build_enumitem_mark,
	Internal = EnumObject.build_enumitem_mark,

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
