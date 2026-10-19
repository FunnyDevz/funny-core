--!strict
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const Cryptography = require("@game/ReplicatedStorage/dependency/Cryptography")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const project = require("@game/ReplicatedStorage/static/project")

const class: enumitem = LuaObject:new({
	type = "enumitem",
	hashlink = "",
	name = "",
	enum = nil :: never,
})

class:host(function(new: luaobject)
	const new = new:as <<enumitem>> (class.type);

	(new :: any).hashlink = Cryptography.Hashing.Blake3.Digest(buffer.fromstring(new.name))

	if project.enums.enumitem_freeze then
		table.freeze(new)
	end
end)

ctype:read(class):write_tag(ctags.core)

return class
