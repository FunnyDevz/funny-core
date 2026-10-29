--!strict
const IKR6Limb = require("@class/game/character/ik/r6/IKR6Limb")
const IKR6HeadInfo = require("@class/struct/game/ik/IKR6HeadInfo")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

const private = {}
const class : ikr6head = IKR6Limb:new {
    type = "ikr6head"
}

class:host(function(new)
    const new = new:as <<ikr6head>> (class.type)
    new:set_info(private.default_info)
end)

do
    private.default_info = IKR6HeadInfo:new()

    class:set_info(private.default_info)
    ctype:read(class):write_tag(ctags.immersiveness, ctags.inverse_kinematic, ctags.class, ctags.game)
end

return class
