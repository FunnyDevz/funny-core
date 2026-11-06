--!strict

const EnumObject = require("@class/core/EnumObject")

const class: enum_asset_type_variant = EnumObject:new({
	name = script.Name,

	Model = EnumObject.build_enumitem_mark,
	Sound = EnumObject.build_enumitem_mark,
	Image = EnumObject.build_enumitem_mark,
})

return class
