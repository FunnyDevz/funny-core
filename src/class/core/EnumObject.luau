--!strict
const EnumItem = require("@class/core/EnumItem")
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const stdout = require("@extension/stdout")
const Cryptography = require("@import/Cryptography")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

type indexed = enumobject & { [unknown]: unknown }

const private = {type = "enumobject"}
const class: enumobject = LuaObject:new({
	type = private.type,
	name = private.type,

	get_enums_list = ftype:write(function<T>(self: enumobject): { [unknown]: enumitem }
		const result: { [unknown]: enumitem } = {}
		for i, v in self :: { [string]: unknown } do
			if self:that(v, EnumItem.type) then
				result[i] = v :: enumitem
			end
		end

		return result
	end, types.table, private.type),

	get_enums_count = ftype:write(function(self: enumobject): number
		local count = 0

		for _, _ in self:get_enums_list() do
			count += 1
		end

		return count
	end, types.number, private.type),

	get_enums_name = ftype:write(function(self: enumobject, ...: enumitem): ...string
		const result: { string } = {}

		for i, v in { ... } do
			if self:is_my_enumitem(v) then
				table.insert(result, v.name)
			end
		end

		return unpack(result)
	end, ftype:var(types.string), private.type, ftype:var(EnumItem.type)),

	get_hashlink_list = ftype:write(function(self: enumobject): { string }
		const result = {}

		for _, v in self:get_enums_list() do
			table.insert(result, v.hashlink)
		end

		return result
	end, types.table, private.type),

	get_enum_by_name = ftype:write(function(self: enumobject, name: string): enumitem?
		const var: unknown = (self :: indexed)[name]

		if self:that(var, EnumItem.type) then
			return var :: enumitem
		end

		return nil
	end, ftype:opt(EnumItem.type), private.type, types.string),

	get_enum_by_hashlink = ftype:write(function(self: enumobject, hashlink: string): enumitem?
		for _, v in self:get_enums_list() do
			if v.hashlink == hashlink then
				return v
			end
		end

		return nil
	end, EnumItem.type, private.type, types.string),

	is_my_enumitem = ftype:write(function(self: enumobject, that: enumitem | string): boolean
		if self:that(that, EnumItem.type) then
			const var = that :: enumitem

			return (self :: indexed)[var.name] ~= nil and var.enum == self
		elseif type(that) == types.string then
			const var = that :: string
			const item: unknown = (self :: indexed)[var]

			if item == nil then return false end
			if self:that(item, EnumItem.type) then return true end

		--#if !DEBUG
        else
			stdout:oute("unexpected that for enumitem")
		--#endif
        end

		return false
	end, types.boolean, private.type, EnumItem.type),
})

class:host(function(new)
	const new = new:as <<enumobject>> (class.type)
    const tnew = new :: any

	for i, v: enumitem in new:get_enums_list() do
		const name = tostring(i)
		local item_var: any = v


        --#if ENUMOBJECT_FREEZE_NEW

        item_var = EnumItem:new({
            name = name,
            enum = new,
        })

		if (not table.isfrozen(item_var)) then
			table.freeze(item_var)
		end

        --#else

        item_var.enum = new
        item_var.name = name
        item_var.hashlink = Cryptography.Hashing.Blake3.Digest(buffer.fromstring(name))

        --#endif


        --#if DEBUG
        const collision: enumitem? = private.item_builded[v.hashlink]
        if collision then
            --#if ENUMBOJECT_PRINT_ACT
            stdout:outm(
                string.format(
                    "enumitem hashlink collision with: \n\n %s (%s) \n %s (%s) \n\n parents: \n\n %s \n %s  ",
                    item_var.name,
                    item_var.hashlink,
                    collision.name :: any,
                    collision.hashlink :: any,
                    item_var.enum and item_var.enum.name or mtypes.never,
                    collision.enum and collision.enum.name or mtypes.never :: any
                )
            )
            --#endif
        end
        --#endif

		tnew[name] = item_var
		private.item_builded[v.hashlink] = v
	end
end)

do
	private.item_builded = setmetatable({} :: { [string]: enumitem }, table.freeze({ __mode = "vs" }))
end


ctype:read(class):write_tag(ctags.core)

return class
