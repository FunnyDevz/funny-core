--!strict
--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>



const LuaObject = require("@class/core/LuaObject")


const class: service = LuaObject:new({
	type = "service",
	name = "*service-missed-name*",
	enabled = false,
})

return class
