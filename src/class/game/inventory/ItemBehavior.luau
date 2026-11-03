--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Struct = require("@class/core/Struct")

const class: itembehavior = Struct:new({
	type = "itembehavior",
})

return class
