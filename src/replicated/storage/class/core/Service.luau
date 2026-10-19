--!strict

const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")

const class: service = LuaObject:new({
	type = "service",
	name = "*no name*",
	enabled = false,
})

ctype:read(class):write_tag(ctags.core)

return class
