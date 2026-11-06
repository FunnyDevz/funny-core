--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Reference = require("@class/common/Reference")
const Maybe = require("@class/common/gc/Maybe")
const Disposable = require("@class/core/Disposable")
const IKR6Info = require("@class/struct/game/IKR6Info")
const mtypes = require("@declare/mtypes")
const ftype = require("@static/ftype")
const ReferenceBasePart = require("@templates/class/reference/ReferenceBasePart")
const ReferenceHumanoid = require("@templates/class/reference/ReferenceHumanoid")

const private = {type = "ikr6solver"}
const class : ikr6solver = Disposable:new {
    type = private.type,

    enabled = false,
    current_idle_time = 0,
    last_work_time = 0,

    get_humanoid = ftype:write(function (self: ikr6solver) : reference<Humanoid?>
	    return private.maybe_humanoid:enactment(self, ReferenceHumanoid)
    end, Reference.type, private.type),

    get_torso = ftype:write(function (self: ikr6solver) : reference<BasePart?>
	    return private.maybe_torso:enactment(self, ReferenceBasePart)
    end, Reference.type, private.type),

    get_info = ftype:write(function (self: ikr6solver) : ikr6info
        return self:get <<ikr6info>> (private.info_key)
    end, IKR6Info.type, private.type),

    set_info = ftype:write(function (self: ikr6solver, new: ikr6info): ()
        self:set(private.info_key, new)
    end, mtypes.never, private.type, IKR6Info.type),
}

do
	private.maybe_humanoid = Maybe:new() :: maybe<reference<Humanoid?>, ikr6solver>
	private.maybe_torso = Maybe:new() :: maybe<reference<BasePart?>, ikr6solver>
    private.info_key = newproxy()
end

return class