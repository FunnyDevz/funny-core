--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Struct = require("@class/core/Struct")
const ItemContextVariant = require("@enums/descriptor/ItemContext")

const class: itemcontext = Struct:new({
	type = "itemcontext",
	related = nil :: any,
	user = nil,
	context = ItemContextVariant.Primary,
})

return class
