--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const IKR6Limb = require("@class/game/character/ik/r6/IKR6Limb")
const IKR6LegInfo = require("@class/struct/game/IKR6LegInfo")

const private = {}
const class : ikr6foot = (IKR6Limb :: ikr6limb<enumitem_iklegs_state, ikr6leginfo>):new {
    type = "ikr6foot"
}

do
    private.default_info = IKR6LegInfo:new()

    private.new = function (new: luaobject)
		const new = new:as<<ikr6foot>>(class.type)
		new:set_info(private.default_info)
    end

    --#if ALL_CLASS_USEABLE
    private.new(class)
    --#endif
end

class:host(private.new)

return class