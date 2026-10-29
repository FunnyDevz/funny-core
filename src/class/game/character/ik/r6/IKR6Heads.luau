--!strict
const Maybe = require("@class/common/gc/Maybe")
const IKR6Head = require("@class/game/character/ik/r6/IKR6Head")
const IKR6Solver = require("@class/game/character/ik/r6/IKR6Solver")
const types = require("@declare/types")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const private = {}
const class : ikr6heads = IKR6Solver:new {
    type = "ikr6heads",

    get_head = ftype:write(function (self: ikr6heads) : ikr6head
        return private.maybe_head:extract(self, private.create_head)
    end, IKR6Head.type, "ikr6heads"),

    is_initiated = ftype:write(function (self: ikr6heads) : boolean
        return private.maybe_head:exist(self)
    end, types.boolean, "ikr6heads"),
}

do
    private.maybe_head = Maybe:new() :: maybe<ikr6head, ikr6heads>

    private.create_head = function ()
        return IKR6Head:new()
    end

    ctype:read(class):write_tag(ctags.immersiveness, ctags.inverse_kinematic, ctags.solver, ctags.class, ctags.game)
end

return class
