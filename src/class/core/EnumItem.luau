--!strict
const LuaObject = require("@class/core/LuaObject")
const Cryptography = require("@import/Cryptography")

const class: enumitem = LuaObject:new({
	type = "enumitem",
	hashlink = "",
	name = "",
	enum = nil :: never,
})

class:host(function(new)
	const new = new:as <<enumitem>> (class.type);
	const tnew: any = new

	tnew.hashlink = Cryptography.Hashing.Blake3.Digest(buffer.fromstring(new.name))

	--#if ENUMITEM_FREEZE_NEW
	if not table.isfrozen(new) then
		table.freeze(new)
	end
	--#endif
end)

return class
