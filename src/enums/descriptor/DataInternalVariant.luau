--!strict
const EnumObject = require("@class/core/EnumObject")

const class: enum_data_internal_variant = EnumObject:new({
	name = script.Name,

	DataSnapshot = EnumObject.build_enumitem_mark,
	DataSet = EnumObject.build_enumitem_mark,
	DataReady = EnumObject.build_enumitem_mark,
	DataRequest = EnumObject.build_enumitem_mark,
	DataExit = EnumObject.build_enumitem_mark,
})

return class
