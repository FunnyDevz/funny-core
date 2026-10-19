--!strict

const Cryptography = require("@game/ReplicatedStorage/dependency/Cryptography")
const LuaObject = require("@game/ReplicatedStorage/class/core/LuaObject")
const declare = require("@game/ReplicatedStorage/static/declare")
const project = require("@game/ReplicatedStorage/static/project")
const EnumItem = require("@game/ReplicatedStorage/class/core/EnumItem")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const ftype = require("@game/ReplicatedStorage/static/ftype")

type indexed = enumobject & { [unknown]: unknown }

const private = {}
const class: enumobject = LuaObject:new({
	type = "enumobject",
	name = script.Name,

	get_enums_list = ftype:write(function<T>(self: enumobject): { [unknown]: enumitem }
		const result: { [unknown]: enumitem } = {}
		for i, v in self :: { [string]: unknown } do
			if self:that(v, EnumItem.type) then
				result[i] = v :: enumitem
			end
		end

		return result
	end, declare.table, "enumobject"),

	get_enums_count = ftype:write(function(self: enumobject): number
		local count = 0

		for _, _ in self:get_enums_list() do
			count += 1
		end

		return count
	end, declare.number, "enumobject"),

	get_enums_name = ftype:write(function(self: enumobject, ...: enumitem): ...string
		const result: { string } = {}

		for i, v in { ... } do
			if self:is_my_enumitem(v) then
				table.insert(result, v.name)
			end
		end

		return unpack(result)
	end, ftype:var(declare.string), "enumobject", ftype:var(EnumItem.type)),

	get_hashlink_list = ftype:write(function(self: enumobject): { string }
		const result = {}

		for _, v in self:get_enums_list() do
			table.insert(result, v.hashlink)
		end

		return result
	end, declare.table, "enumobject"),

	get_enum_by_name = ftype:write(function(self: enumobject, name: string): enumitem?
		const var: unknown = (self :: indexed)[name]

		if self:that(var, EnumItem.type) then
			return var :: enumitem
		end

		return nil
	end, ftype:opt(EnumItem.type), "enumobject", declare.string),

	get_enum_by_hashlink = ftype:write(function(self: enumobject, hashlink: string): enumitem?
		for _, v in self:get_enums_list() do
			if v.hashlink == hashlink then
				return v
			end
		end

		return nil
	end, EnumItem.type, "enumobject", declare.string),

	is_my_enumitem = ftype:write(function(self: enumobject, that: enumitem | string): boolean
		if self:that(that, EnumItem.type) then
			const var = that :: enumitem

			return (self :: indexed)[var.name] ~= nil and var.enum == self
		elseif type(that) == declare.string then
			const var = that :: string
			const item: unknown = (self :: indexed)[var]

			if item == nil then
				return false
			end
			if self:that(item, EnumItem.type) then
				return true
			end
		else
			project.console_out_error("unexpected that for enumitem")
		end

		return false
	end, declare.boolean, "enumobject", EnumItem.type),
})

class:host(function(new: luaobject)
	const new = new:as <<enumobject>> (class.type)

	for i, v in new:get_enums_list() do
		const name = tostring(i)
		local item_var = v :: any

		if project.enums.enumitem_freeze then
			item_var = EnumItem:new({
				name = name,
				enum = new,
			})
		else
			item_var.enum = new
			item_var.name = name
			item_var.hashlink = Cryptography.Hashing.Blake3.Digest(buffer.fromstring(name))
		end

		if project.debug then
			const collision: any = private.item_builded[v.hashlink]

			if collision then
				project.console_out_error(
					string.format(
						"enumitem hashlink collision with: \n\n %s (%s) \n %s (%s) \n\n parents: \n\n %s \n %s  ",
						item_var.name,
						item_var.hashlink,
						collision.name,
						collision.hashlink,
						item_var.enum and item_var.enum.name or "null",
						collision.enum and collision.enum.name or "null"
					)
				)
			end
		end

		(new :: indexed)[name] = item_var
		private.item_builded[v.hashlink] = v

		if project.enums.enumobject_freeze then
			table.freeze(v)
		end
	end
end)

do
	private.item_builded = setmetatable({} :: { [string]: enumitem }, table.freeze({ __mode = "vs" }))

	if project.debug then
		_G.fg_debug.enumobject_require = function(hashlink: any)
			return private.item_builded[hashlink]
		end
	end
end

ctype:read(class):write_tag(ctags.core)

return class
