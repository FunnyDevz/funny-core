--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")
const engine = require("@platform/roblox/engine")
const players = require("@platform/roblox/players")

const class: enum_net_source = EnumObject:new({
	name = script.Name,

	UnknownSource = EnumItem:new() :: enumitem<any>,
	FromServer = EnumItem:new() :: enumitem<any>,
	FromMe = EnumItem:new() :: enumitem<any>,
	FromClient = EnumItem:new() :: enumitem<any>,

	get_enum_by_current_machine = function(self: enum_net_source): enumitem_net_source
		if engine.is_server or players.get_local() then
			return self.FromMe
		end

		return self.UnknownSource
	end,
})

return class
