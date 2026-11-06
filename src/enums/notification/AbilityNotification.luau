--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_ability_notification = EnumObject:new({
	name = script.Name,

	CastAbility = EnumObject.build_enumitem_mark,
	WaitingDataAbility = EnumObject.build_enumitem_mark,
	ActiveAbility = EnumObject.build_enumitem_mark,
	CancelAbility = EnumObject.build_enumitem_mark,
	EndingAbility = EnumObject.build_enumitem_mark,
	CooldownAbility = EnumObject.build_enumitem_mark,
})

return class
