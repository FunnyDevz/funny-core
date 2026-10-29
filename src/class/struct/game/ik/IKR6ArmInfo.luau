--!strict
const IKR6LimbInfo = require("@class/struct/game/ik/IKR6LimbInfo")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

const class: ikr6arminfo = IKR6LimbInfo:new({
	type = "ikr6arminfo",

})

ctype:read(class):write_tag(ctags.game, ctags.immersiveness, ctags.inverse_kinematic, ctags.struct)

return class
