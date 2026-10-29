--!strict
const IKR6Limb = require("@class/game/character/ik/r6/IKR6Limb")
const IKR6ArmInfo = require("@class/struct/game/ik/IKR6ArmInfo")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

const private = {}
const class : ikr6arm = IKR6Limb:new {
    type = "ikr6arm",
    absolute = false,
}

class:host(function(new)
    const new = new:as <<ikr6arm>> (class.type)
    new:set_info(private.default_info)
end)

do
    private.default_info = IKR6ArmInfo:new()

    class:set_info(private.default_info)
    ctype:read(class):write_tag(ctags.immersiveness, ctags.inverse_kinematic, ctags.class, ctags.game)
end

return class
