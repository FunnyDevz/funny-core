--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_setup_notification = EnumObject:new({
	name = script.Name,

	Install = EnumObject.build_enumitem_mark,
	Require = EnumObject.build_enumitem_mark,
	Installed = EnumObject.build_enumitem_mark,
	Disconnected = EnumObject.build_enumitem_mark,
})

return class
