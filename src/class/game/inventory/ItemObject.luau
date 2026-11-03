--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const ItemInstance = require("@class/game/inventory/ItemInstance")

const class: itemobject = (ItemInstance :: iteminstance):new({
	type = "itemobject",
})

return class
