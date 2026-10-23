--!strict

const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")

const class: enum_round_state = EnumObject:new({
	name = script.Name,
	Preparing = EnumItem:new() :: enumitem<any>,
	Begining = EnumItem:new() :: enumitem<any>,
	AtWork = EnumItem:new() :: enumitem<any>,
    Ending = EnumItem:new() :: enumitem<any>,
    Ended = EnumItem:new() :: enumitem<any>,
})

return class