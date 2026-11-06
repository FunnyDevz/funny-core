--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Maybe = require("@class/common/gc/Maybe")
const IKR6Arm = require("@class/game/character/ik/r6/IKR6Arm")
const IKR6Solver = require("@class/game/character/ik/r6/IKR6Solver")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const private = {type = "ikr6arms"}
const class : ikr6arms = IKR6Solver:new {
    type = private.type,

    get_left_arm = ftype:write(function (self: ikr6arms) : ikr6arm
        if not private.maybe_left_arms:exist(self) then
            const arm = private.maybe_left_arms:enactment(self, IKR6Arm)
            self:finally(arm)
            return arm
        else
    		return private.maybe_left_arms:enactment(self, IKR6Arm)
        end
    end, IKR6Arm.type, private.type),

    get_right_arm = ftype:write(function (self: ikr6arms) : ikr6arm
        if not private.maybe_right_arms:exist(self) then
            const arm = private.maybe_right_arms:enactment(self, IKR6Arm)
            self:finally(arm)
            return arm
        else
            return private.maybe_right_arms:enactment(self, IKR6Arm)
        end
    end, IKR6Arm.type, private.type),

    is_initiated = ftype:write(function (self: ikr6arms) : boolean
        return private.maybe_left_arms:exist(self) and private.maybe_right_arms:exist(self)
    end, types.boolean, private.type),
}

do
    private.maybe_left_arms = Maybe:new() :: maybe<ikr6arm, ikr6arms>
    private.maybe_right_arms = Maybe:new() :: maybe<ikr6arm, ikr6arms>

end

return class
