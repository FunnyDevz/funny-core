--!strict
--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>


const LuaObject = require("@class/core/LuaObject")
const Cryptography = require("@import/Cryptography")

const class: enumitem = LuaObject:new({
	type = "enumitem",
	hashlink = "",
	name = "",
	enum = nil :: never,
})

class:host(function(new)
	const new = new:as <<enumitem>> (class.type)
	const tnew: any = new

	const enum = new.enum :: enumobject?
	tnew.hashlink = Cryptography.Hashing.Blake3.Digest(buffer.fromstring(if enum then `{enum.name}.{new.name}` else new.name))

	--#if CORE_ENUMITEM_FREEZE
	if not table.isfrozen(new) then
		table.freeze(new)
	end
	--#endif
end)

return class
