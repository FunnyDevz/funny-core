--!strict

const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_iklegs_state = EnumObject:new({
	name = script.Name,

    Planted = EnumItem:new() :: enumitem<any>,
    Stepping = EnumItem:new() :: enumitem<any>,
    Settling = EnumItem:new() :: enumitem<any>
})

return class
