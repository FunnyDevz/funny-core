--!strict
const EnumObject = require("@class/core/EnumObject")
const engine = require("@platform/roblox/engine")
const players = require("@platform/roblox/players")

const class: enum_net_source = EnumObject:new({
	name = script.Name,

	UnknownSource = EnumObject.build_enumitem_mark,
	FromServer = EnumObject.build_enumitem_mark,
	FromMe = EnumObject.build_enumitem_mark,
	FromClient = EnumObject.build_enumitem_mark,

	get_enum_by_current_machine = function(self: enum_net_source): enumitem_net_source
		if engine.is_server or players.get_local() then
			return self.FromMe
		end

		return self.UnknownSource
	end,
})

return class
