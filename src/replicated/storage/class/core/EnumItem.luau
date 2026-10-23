--!strict
const LuaObject = require("@class/core/LuaObject")
const Cryptography = require("@import/Cryptography")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")

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
	table.freeze(new)
	--#endif
end)

ctype:read(class):write_tag(ctags.core)

return class
