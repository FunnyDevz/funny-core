--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const KinematicController = require("@class/common/physics/KinematicController")

const private = { type = "picontroller" }
const class: picontroller = (KinematicController :: kinematiccontroller):new({
	type = private.type,
	integral = 0,
	integral_limit = math.huge,
})

return class
