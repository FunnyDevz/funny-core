--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_user_machine_variant = EnumObject:new({
	name = script.Name,

	Computer = EnumObject.build_enumitem_mark,
	Mobile = EnumObject.build_enumitem_mark,
	Console = EnumObject.build_enumitem_mark,
	AnotherDevice = EnumObject.build_enumitem_mark,
})

return class
