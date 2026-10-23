--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_ability_notification = EnumObject:new({
	name = script.Name,

	CastAbility = EnumItem:new() :: enumitem<any>,
	WaitingDataAbility = EnumItem:new() :: enumitem<any>,
	ActiveAbility = EnumItem:new() :: enumitem<any>,
	CancelAbility = EnumItem:new() :: enumitem<any>,
	EndingAbility = EnumItem:new() :: enumitem<any>,
	CooldownAbility = EnumItem:new() :: enumitem<any>,
})

return class
