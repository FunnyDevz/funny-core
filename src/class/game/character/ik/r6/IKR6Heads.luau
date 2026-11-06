--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Maybe = require("@class/common/gc/Maybe")
const IKR6Head = require("@class/game/character/ik/r6/IKR6Head")
const IKR6Solver = require("@class/game/character/ik/r6/IKR6Solver")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const private = {type = "ikr6heads"}
const class : ikr6heads = IKR6Solver:new {
    type = private.type,

    get_head = ftype:write(function (self: ikr6heads) : ikr6head
        return private.maybe_head:enactment(self, IKR6Head)
    end, IKR6Head.type, private.type),

    is_initiated = ftype:write(function (self: ikr6heads) : boolean
        return private.maybe_head:exist(self)
    end, types.boolean, private.type),
}

do
    private.maybe_head = Maybe:new() :: maybe<ikr6head, ikr6heads>
end

return class
