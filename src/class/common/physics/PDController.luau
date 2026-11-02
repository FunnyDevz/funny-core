--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const KinematicController = require("@class/common/physics/KinematicController")

const private = { type = "pdcontroller" }
const class: pdcontroller = (KinematicController :: kinematiccontroller):new({
	type = private.type,
	derivative = 0,
})

return class
