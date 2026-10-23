--!strict

const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_asset_type_variant = EnumObject:new({
	name = script.Name,
	Model = EnumItem:new() :: enumitem<any>,
	Sound = EnumItem:new() :: enumitem<any>,
	Image = EnumItem:new() :: enumitem<any>,
})

return class
