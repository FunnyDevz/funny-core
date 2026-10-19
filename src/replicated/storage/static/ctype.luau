--!strict
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const args = require("./mtargument")
const outs = require("./mtout")

type argument = args.argument
type tval = args.tval
type out = outs.out

--[==[
	args single field member of a runtime type.

	`type` is a full `argument` descriptor (see the `argument` module),
	so it can express optional, variadic, union, and nested types —
	not just a bare runtime type name.

	For a field the `var` flag is not meaningful and should be ignored;
	`opt` and `uor` are the useful modifiers.
]==]
export type field_member = {
	read kind: "field",
	read name: string,
	read readonly: boolean,
	read static: boolean,
	read type: argument,
}

--[==[
	args single function member of a runtime type.

	`type` is a full function signature (`out` from the `ftype` stack),
	covering both the result type and all argument descriptors.
	An unregistered signature is represented by `outs.unknown()`
	(`signature.guaranteed == false`).
]==]
export type func_member = {
	read kind: "func",
	read name: string,
	read readonly: boolean,
	read static: boolean,
	read type: out,
}

--[==[
	args single member of a runtime type.

	Use `kind` to discriminate: `"field"` narrows to `field_member`,
	`"func"` narrows to `func_member`.
]==]
export type member = field_member | func_member

--[==[
	Contains runtime type metadata associated with a registered value.

	`classname` identifies the runtime class name.
	`tag` contains arbitrary type tags.
	`fields` and `funcs` describe the members of the type.
	`attributes` stores additional user-defined metadata.
	`guaranteed` indicates whether the metadata is considered complete
	and reliable.
]==]
export type metainfo = {

	--[==[
		Indicates whether the stored metadata is guaranteed to be complete
		and reliable.
	]==]
	read guaranteed: boolean,

	--[==[
		Gets the runtime class name represented by this metadata.
	]==]
	read classname: string,

	--[==[
		Gets the tags associated with this runtime type.
	]==]
	read tag: { string },

	--[==[
		Gets all field members described by this metadata.
	]==]
	read fields: { field_member },

	--[==[
		Gets all function members described by this metadata.
	]==]
	read funcs: { func_member },

	--[==[
		Gets additional user-defined attributes associated with this metadata.
	]==]
	read attributes: { [string]: unknown },

	--[==[
		Adds a function member to this metadata.

		`name` is the function member name.
		`signature` is the function's full signature. When omitted, the
		member's `type` becomes `outs.unknown()` (`guaranteed == false`),
		matching "function exists, signature not registered".
		`readonly` indicates whether the member is read-only.
		`static` indicates whether the member belongs to the type itself
		rather than to its instances.
	]==]
	read write_func: (
		self: metainfo,
		name: string,
		signature: out?,
		readonly: boolean?,
		static: boolean?
	) -> (),

	--[==[
		Adds a field member to this metadata.

		`name` is the field name.
		`type` is the field's runtime type, expressed as a `tval`
		(a type name string or a prepared `argument`). Strings are packed
		into a plain `argument` automatically; pass `args.opt(...)`,
		`args.var_or(...)` etc. to express optional / union / nested types.
		`readonly` indicates whether the field is read-only.
		`static` indicates whether the field belongs to the type itself
		rather than to its instances.
	]==]
	read write_field: (
		self: metainfo,
		name: string,
		type: tval?,
		readonly: boolean?,
		static: boolean?
	) -> (),

	--[==[
		Writes a user-defined attribute.

		`name` is the attribute name.
		`value` is the value associated with the attribute.
	]==]
	read write_attribute: (self: metainfo, name: string, value: unknown) -> (),

	read write_tag: (self: metainfo, ...string) -> (),

	--[==[
		Reads a user-defined attribute.

		Returns the stored value when the attribute exists,
		or `nil` when no attribute with the specified name is present.
	]==]
	read read_attribute: (self: metainfo, name: string) -> unknown,

	--[==[
		Finds a function member by name.
	]==]
	read read_func: (self: metainfo, name: string) -> func_member?,

	--[==[
		Finds a field member by name.
	]==]
	read read_field: (self: metainfo, name: string) -> field_member?,

	--[==[
		Checks whether a field with the specified name exists.
	]==]
	read has_field: (self: metainfo, name: string) -> boolean,

	--[==[
		Checks whether a function with the specified name exists.
	]==]
	read has_func: (self: metainfo, name: string) -> boolean,

	--[==[
		Checks whether the metadata contains at least one of the specified tags.
	]==]
	read has_tag: (self: metainfo, ...string) -> boolean,

	--[==[
		Checks whether the metadata contains all of the specified tags.
	]==]
	read has_tags: (self: metainfo, ...string) -> boolean,

	--[==[
		Gets all fields and functions described by this metadata.

		The returned sequence contains both kinds of members; discriminate
		via the `kind` field (`"field"` / `"func"`).
	]==]
	read get_all: (self: metainfo) -> { member },
}

type tbl = any

--[==[
	Provides storage and querying operations for runtime type metadata.

	`ctype` associates runtime values with `metainfo` records and provides
	helpers for generating, locating, filtering, and enumerating those
	records.

	Type metadata is stored independently of the values it describes,
	allowing runtime code to inspect class names, tags, fields, functions,
	and additional attributes without relying on Luau's compile-time type
	system.
]==]
export type ctype = {
	read write: <T>(self: ctype, of: T, info: metainfo) -> T,
	read read: (self: ctype, of: tbl) -> metainfo,
	read named: (self: ctype, name: string) -> ...metainfo,
	read tagged: (self: ctype, ...string) -> ...metainfo,
	read generate_empty_metainfo: (self: ctype, guaranteed: boolean?) -> metainfo,
	read generate_metainfo: (self: ctype, of: tbl, tags: { string }, classname: string) -> metainfo,
	read is_registered: (self: ctype, of: tbl) -> boolean,
	read all: (self: ctype) -> { metainfo },
}

const private = {}

const metainfo: metainfo = table.freeze({
	classname = "",
	guaranteed = false,

	tag = declare.tables.__null,
	fields = declare.tables.__null,
	funcs = declare.tables.__null,
	attributes = declare.tables.__null,

	write_func = function(self: metainfo, name: string, signature: out?, readonly: boolean?, static: boolean?): ()
		table.insert(self.funcs, private.make_func_member(name, signature or outs.unknown, readonly, static))
	end,

	write_field = function(self: metainfo, name: string, type: tval?, readonly: boolean?, static: boolean?): ()
		table.insert(self.fields, private.make_field_member(name, args.pack(type or declare.anyt), readonly, static))
	end,

	write_attribute = function(self: metainfo, name: string, value: unknown): ()
		self.attributes[name] = value
	end,

	read_attribute = function(self: metainfo, name: string): unknown
		return self.attributes[name]
	end,

	read_func = function(self: metainfo, name: string): func_member?
		for _, v in self.funcs do
			if v.name == name then
				return v
			end
		end

		return nil
	end,

	read_field = function(self: metainfo, name: string): field_member?
		for _, v in self.fields do
			if v.name == name then
				return v
			end
		end

		return nil
	end,

	write_tag = function(self: metainfo, ...: string): ()
		for _, tag in { ... } do
			if not table.find(self.tag, tag) then
				table.insert(self.tag, tag)
			end
		end
	end,

	has_field = function(self: metainfo, name: string): boolean
		return self:read_field(name) ~= nil
	end,

	has_func = function(self: metainfo, name: string): boolean
		return self:read_func(name) ~= nil
	end,

	has_tag = function(self: metainfo, ...: string): boolean
		for _, v in { ... } do
			if table.find(self.tag, v) then
				return true
			end
		end

		return false
	end,

	has_tags = function(self: metainfo, ...: string): boolean
		for _, v in { ... } do
			if not table.find(self.tag, v) then
				return false
			end
		end

		return true
	end,

	get_all = function(self: metainfo): { member }
		const result: { any } = {}
		table.move(self.fields, 1, #self.fields, 1, result)
		table.move(self.funcs, 1, #self.funcs, #result + 1, result)
		return result
	end,
})

const ctype: ctype = table.freeze({
	write = function(self: ctype, of: tbl, info: metainfo): any
		private.mkinfo_list[of] = info
		return of
	end,

	read = function(self: ctype, of: tbl): metainfo
		return private.mkinfo_list[of] or self:generate_empty_metainfo()
	end,

	named = function(self: ctype, ...: string): ...metainfo
		const names: { string } = { ... }
		const result: { metainfo } = {}

		for _, v in self:all() do
			for _, t in names do
				if v.classname == t then
					table.insert(result, v)
				end
			end
		end

		return unpack(result)
	end,

	tagged = function(self: ctype, ...: string): ...metainfo
		const tags: { string } = { ... }
		const result: { metainfo } = {}

		for _, v in self:all() do
			for _, t in tags do
				if table.find(v.tag, t) then
					table.insert(result, v)
				end
			end
		end

		return unpack(result)
	end,

	generate_empty_metainfo = function(self: ctype, guaranteed: boolean?): metainfo
		return private.make_minfo({}, metainfo.classname, guaranteed)
	end,

	generate_metainfo = function(self: ctype, of: tbl, tags: { string }, classname: string): metainfo
		const new = private.make_minfo(tags, classname, true)

		for i, v in of do
			if typeof(i) ~= declare.string then
				project.console_out_error(`index {i} unsupported, skip`)
				continue
			end

			const T = typeof(v)
			const name = tostring(i)

			if T == declare["function"] then
				new:write_func(name, ftype:read(v), true, true)
			elseif T == declare.table then
				if
					type(v.that) == declare["function"]
					and type(v.type) == declare.string
					and type(v.is) == declare["function"]
				then
					const var = v :: luaobject
					new:write_field(name, var.type, true, false)
				else
					new:write_field(name, declare.table, false, false)
				end
			else
				new:write_field(tostring(i), T, false, false)
			end
		end

		return new
	end,

	is_registered = function(self: ctype, of: tbl): boolean
		return private.mkinfo_list[of] ~= nil
	end,

	all = function(self: ctype): { metainfo }
		const result = {}
		for _, v in private.mkinfo_list do
			table.insert(result, v)
		end
		return result
	end,
})

do
	private.mkinfo_list = setmetatable({} :: { [tbl]: metainfo? }, declare.tables.__mode_ks)

	private.__metainfo = table.freeze({ __index = metainfo })

	private.make_minfo = function(tags: { string }, classname: string, guaranteed: boolean?): metainfo
		return setmetatable({
			classname = classname,
			tag = tags,
			fields = {},
			funcs = {},
			attributes = {},
			guaranteed = guaranteed or false,
		}, private.__metainfo)
	end

	private.make_field_member = function(
		name: string,
		type: argument,
		readonly: boolean?,
		static: boolean?
	): field_member
		return table.freeze({
			kind = "field" :: "field",
			name = name,
			type = type,
			readonly = readonly == true,
			static = static == true,
		})
	end

	private.make_func_member = function(name: string, signature: out, readonly: boolean?, static: boolean?): func_member
		return table.freeze({
			kind = "func" :: "func",
			name = name,
			type = signature,
			readonly = readonly == true,
			static = static == true,
		})
	end
end

return ctype
