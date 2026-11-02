--!strict
const IKR6Limb = require("@class/game/character/ik/r6/IKR6Limb")
const IKR6LegInfo = require("@class/struct/game/ik/IKR6LegInfo")

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
end

return class