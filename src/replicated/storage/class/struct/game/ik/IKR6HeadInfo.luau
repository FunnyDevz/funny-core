--!strict
const IKR6LimbInfo = require("@game/ReplicatedStorage/class/struct/game/ik/IKR6LimbInfo")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")

const class: ikr6headinfo = IKR6LimbInfo:new({
	type = "ikr6headinfo",

})

ctype:read(class):write_tag(ctags.game, ctags.immersiveness, ctags.inverse_kinematic, ctags.struct)

return class
