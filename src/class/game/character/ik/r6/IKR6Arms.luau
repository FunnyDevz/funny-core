--!strict
const Maybe = require("@class/common/gc/Maybe")
const IKR6Arm = require("@class/game/character/ik/r6/IKR6Arm")
const IKR6Solver = require("@class/game/character/ik/r6/IKR6Solver")
const types = require("@declare/types")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const private = {}
const class : ikr6arms = IKR6Solver:new {
    type = "ikr6arms",

    get_left_arm = ftype:write(function (self: ikr6arms) : ikr6arm
        return private.maybe_left_arms:extract(self, private.create_arm)
    end, IKR6Arm.type, "ikr6arms"),

    get_right_arm = ftype:write(function (self: ikr6arms) : ikr6arm
        return private.maybe_right_arms:extract(self, private.create_arm)
    end, IKR6Arm.type, "ikr6arms"),

    is_initiated = ftype:write(function (self: ikr6arms) : boolean
        return private.maybe_left_arms:exist(self) and private.maybe_right_arms:exist(self)
    end, types.boolean, "ikr6arms"),
}

do
    private.maybe_left_arms = Maybe:new() :: maybe<ikr6arm, ikr6arms>
    private.maybe_right_arms = Maybe:new() :: maybe<ikr6arm, ikr6arms>

    private.create_arm = function ()
        return IKR6Arm:new()
    end

    ctype:read(class):write_tag(ctags.immersiveness, ctags.inverse_kinematic, ctags.solver, ctags.class, ctags.game)
end

return class
