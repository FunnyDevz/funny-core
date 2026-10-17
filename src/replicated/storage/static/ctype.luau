--!strict
const declare = require("@game/ReplicatedStorage/static/declare")
const project = require("@game/ReplicatedStorage/static/project")

--[==[
	Describes a single member of a runtime type.

	`name` is the member name, `type` is its runtime type name,
	`readonly` indicates whether the member is intended to be read-only,
	and `static` indicates whether the member belongs to the type itself
	rather than to its instances.
]==]
export type member = {
	read name: string,
	read readonly: boolean,
	read static: boolean,
	read type: string,
}

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
	read fields: { member },

	--[==[
		Gets all function members described by this metadata.
	]==]
	read funcs: { member },

	--[==[
		Gets additional user-defined attributes associated with this metadata.
	]==]
	read attributes: { [string]: unknown },

	--[==[
		Adds a function member to this metadata.

		`name` is the function member name.
		`readonly` indicates whether the member is read-only.
		`static` indicates whether the member belongs to the type itself
		rather than to its instances.
	]==]
	read write_func: (self: metainfo, name: string, readonly: boolean?, static: boolean?) -> (),

	--[==[
		Adds a field member to this metadata.

		`name` is the field name.
		`type` is the runtime type name associated with the field.
		`readonly` indicates whether the field is read-only.
		`static` indicates whether the field belongs to the type itself
		rather than to its instances.
	]==]
	read write_field: (
		self: metainfo,
		name: string,
		type: string?,
		readonly: boolean?,
		static: boolean?
	) -> (),

    	--[==[
		Writes a user-defined attribute.

		`name` is the attribute name.
		`value` is the value associated with the attribute.
	]==]
	read write_attribute: (
		self: metainfo,
		name: string,
		value: unknown
	) -> (),

    read write_tag: (
		self: metainfo,
		...string
	) -> (),

	--[==[
		Reads a user-defined attribute.

		Returns the stored value when the attribute exists,
		or `nil` when no attribute with the specified name is present.
	]==]
	read read_attribute: (
		self: metainfo,
		name: string
	) -> unknown,

	--[==[
		Finds a function member by name.

		Returns the corresponding function metadata when the member exists,
		or `nil` when no function with the specified name is present.
	]==]
	read read_func: (self: metainfo, name: string) -> member?,

	--[==[
		Finds a field member by name.

		Returns the corresponding field metadata when the member exists,
		or `nil` when no field with the specified name is present.
	]==]
	read read_field: (self: metainfo, name: string) -> member?,

	--[==[
		Checks whether a field with the specified name exists.
	]==]
	read has_field: (self: metainfo, name: string) -> boolean,

	--[==[
		Checks whether a function with the specified name exists.
	]==]
	read has_func: (self: metainfo, name: string) -> boolean,

	--[==[
		Checks whether the metadata contains all of the specified tags.
	]==]
	read has_tag: (self: metainfo, ...string) -> boolean,

	--[==[
		Checks whether the metadata matches the specified tag set.

		This operation is intended for querying multiple tags as a group.
	]==]
	read has_tags: (self: metainfo, ...string) -> boolean,

	--[==[
		Gets all fields and functions described by this metadata.

		The returned sequence contains both field and function members.
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

	--[==[
		Registers runtime type metadata for a value.

		`of` is the value associated with the metadata.
		`info` contains the runtime type description to register.

		Returns `of` unchanged, allowing registration to be used inline.
	]==]
	read write: <T>(self: ctype, of: T, info: metainfo) -> T,

	--[==[
		Reads the metadata registered for a value.

		When the value has no registered metadata, an empty metadata record
		is generated and returned.
	]==]
	read read: (self: ctype, of: tbl) -> metainfo,

	--[==[
		Finds all registered metadata records whose class name matches `name`.

		Returns all matching metadata records as multiple return values.
	]==]
	read named: (self: ctype, name: string) -> ...metainfo,

	--[==[
		Finds all registered metadata records matching the specified tags.

		Returns all matching metadata records as multiple return values.
	]==]
	read tagged: (self: ctype, ...string) -> ...metainfo,

	--[==[
		Creates an empty runtime metadata record.

		`guaranteed` specifies whether the generated metadata should be
		considered complete and reliable. When omitted, the implementation's
		default value is used.
	]==]
	read generate_empty_metainfo: (self: ctype, guaranteed: boolean?) -> metainfo,

	--[==[
		Generates runtime metadata by inspecting a table.

		`of` is the table whose members are inspected.
		`tags` specifies the tags assigned to the generated metadata.
		`classname` specifies the runtime class name.

		Members are classified from their runtime values and represented as
		fields or function members in the resulting metadata.
	]==]
	read generate_metainfo: (self: ctype, of: tbl, tags: { string }, classname: string) -> metainfo,

	--[==[
		Checks whether runtime metadata has been registered for a value.
	]==]
	read is_registered: (self: ctype, of: tbl) -> boolean,

	--[==[
		Gets all currently registered runtime metadata records.
	]==]
	read all: (self: ctype) -> { metainfo },
}

const private = {}

const member: member = table.freeze {
    name = "",
    type = declare.anyt,
    readonly = false,
    static = false
}

const metainfo: metainfo = table.freeze {
    classname = "",
    guaranteed = false,
    
    tag = declare.tables.__null,
    fields = declare.tables.__null,
    funcs = declare.tables.__null,
    attributes = declare.tables.__null,

    write_func = function (self: metainfo, name: string, readonly: boolean?, static: boolean?) : ()
        table.insert(self.funcs, private.make_member(name, declare["function"], readonly, static))
    end,
    
    write_field = function (self: metainfo, name: string, type: string?, readonly: boolean?, static: boolean?) : ()
        table.insert(self.fields, private.make_member(name, type, readonly, static))
    end,

    write_attribute = function (self: metainfo, name: string, value: unknown) : ()
        self.attributes[name] = value
    end,

    read_attribute = function (self: metainfo, name: string) : unknown
        return self.attributes[name]
    end,

    read_func = function (self: metainfo, name: string) : member?
        for _, v in self.funcs do
            if v.name == name then
                return v
            end
        end

        return nil
    end,

    read_field = function (self: metainfo, name: string) : member?
        for _, v in self.fields do
            if v.name == name then
                return v
            end
        end

        return nil
    end,

	write_tag = function (self: metainfo, ...:string) : ()
        for _, tag in {...} do
            if not table.find(self.tag, tag) then
                table.insert(self.tag, tag)
            end
        end
	end,

    has_field = function (self: metainfo, name: string) : boolean
        return self:read_field(name) ~= nil
    end,

    has_func = function (self: metainfo, name: string) : boolean
        return self:read_func(name) ~= nil
    end,

    has_tag = function (self: metainfo, ...: string) : boolean
        for _, v in {...} do
            if table.find(self.tag, v) then
                return true
            end
        end

        return false
    end,

    has_tags = function (self: metainfo, ...: string) : boolean
        for _, v in {...} do
            if not table.find(self.tag, v) then
                return false
            end
        end

        return true
    end,

    get_all = function (self: metainfo) : {member}
        const result = {}
        table.move(self.fields, 1, #self.fields, 1, result)
        table.move(self.funcs, 1, #self.funcs, #result + 1, result)
        return result
    end
}

const ctype: ctype = table.freeze {
    write = function (self: ctype, of: tbl, info: metainfo) : any
        private.mkinfo_list[of] = info
        return of
    end,

    read = function (self: ctype, of: tbl) : metainfo
        return private.mkinfo_list[of] or self:generate_empty_metainfo()
    end,

    named = function (self: ctype, ...: string) : ...metainfo
        const names: {string} = {...}
        const result: {metainfo} = {}

        for _, v in self:all() do
            for _, t in names do
                if v.classname == t then
                    table.insert(result, v)
                end
            end
        end

        return unpack(result)
    end,

    tagged = function (self: ctype, ...: string) : ...metainfo
        const tags: {string} = {...}
        const result: {metainfo} = {}

        for _, v in self:all() do
            for _, t in tags do
                if table.find(v.tag, t) then
                    table.insert(result, v)
                end
            end
        end

        return unpack(result)
    end,

    generate_empty_metainfo = function (self: ctype, guaranteed: boolean?) : metainfo
        return private.make_minfo({}, metainfo.classname, guaranteed)
    end,

    generate_metainfo = function (self: ctype, of: tbl, tags: {string}, classname: string) : metainfo
        const new = private.make_minfo(tags, classname, true)

        for i, v in of do

            if typeof(i) ~= declare.string then
                project.console_out_error(`index {i} unsupported, skip`)
                continue
            end

    		const T = typeof(v)
            const name = tostring(i)


            if T == declare["function"] then
                new:write_func(name, true, true)
            elseif T == declare.table then
                

                if type(v.that) == declare["function"] and type(v.type) == declare.string and type(v.is) == declare["function"] then
                    const var = v :: object
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

    is_registered = function (self: ctype, of: tbl) : boolean
        return private.mkinfo_list[of] ~= nil
    end,

    all = function (self: ctype) : {metainfo}
        const result = {}
        for _, v in private.mkinfo_list do
            table.insert(result, v)
        end
        return result
    end,
}

do
    private.__member = table.freeze {__index = member}
    private.__metainfo = table.freeze {__index = metainfo}
    private.mkinfo_list = setmetatable({} :: {[tbl]: metainfo?}, declare.tables.__mode_ks)
    
    private.make_minfo = function (tags: {string}, classname: string, guaranteed: boolean?) : metainfo
        const new = setmetatable({
            classname = classname,
            tag = tags,
            fields = {},
            funcs = {},
            attributes = {},
            guaranteed = guaranteed or false
        }, private.__metainfo)

        return new
    end

    private.make_member = function (name: string, type: string?, readonly: boolean?, static: boolean?) : member
        const new = setmetatable({
            name = name,
            type = type or member.type,
            readonly = readonly or member.readonly,
            static = static or member.static
        }, private.__member)

        return new
    end
end

return ctype