--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const IKR6Limb = require("@class/game/character/ik/r6/IKR6Limb")
const IKR6HeadInfo = require("@class/struct/game/IKR6HeadInfo")

const private = {type = "ikr6head"}
const class : ikr6head = IKR6Limb:new {
    type = private.type
}



do
    private.default_info = IKR6HeadInfo:new()

    private.new = function (new: luaobject)
		const new = new:as<<ikr6head>>(class.type)
		new:set_info(private.default_info)
    end

    --#if ALL_CLASS_USEABLE
    private.new(class)
    --#endif
end

class:host(private.new)

return class
