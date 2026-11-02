--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const KinematicController = require("@class/common/physics/KinematicController")

const private = { type = "pidcontroller" }
const class: pidcontroller = (KinematicController :: kinematiccontroller):new({
	type = private.type,
	integral = 0,
	integral_limit = math.huge,
	derivative = 0,
})

return class
