--!strict
const IKR6Limb = require("@game/ReplicatedStorage/class/game/play/characters/ik/r6/IKR6Limb")
const IKR6LegInfo = require("@game/ReplicatedStorage/class/struct/game/ik/IKR6LegInfo")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")

const private = {}
const class : ikr6foot = (IKR6Limb :: ikr6limb<enumitem_iklegs_state, ikr6leginfo>):new {
    type = "ikr6foot"
}

class:host(function(new)
    const new = new:as <<ikr6foot>> (class.type)
    new:set_info(private.default_info)
end)

do
    private.default_info = IKR6LegInfo:new()

    class:set_info(private.default_info)
    ctype:read(class):write_tag(ctags.immersiveness, ctags.inverse_kinematic, ctags.class, ctags.game)
end

return class