--!strict
const LuaObject = require("@class/core/LuaObject")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

const class: service = LuaObject:new({
	type = "service",
	name = "*no name*",
	enabled = false,
})

ctype:read(class):write_tag(ctags.core)

return class
