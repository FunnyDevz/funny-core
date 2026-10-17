--!strict


const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const project = require("@game/ReplicatedStorage/static/project")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const ttable = require("@game/ReplicatedStorage/static/ttable")

const private = {}
const class: object = {
	type = "object",

	new = ftype:write(function <T,U> (self: T, that: U?): any
		const child = ttable.combine(self, that)

		return child
	end, "object", ftype:uor(declare.table, "object"), ftype:opt(declare.table)),

	is = ftype:write(function(self: object, that: string): boolean
		if (that == declare.anyt) then return true end

		local base = self

		while base do
			if (base:it(that)) then return true end
            base = base:base()
		end

		return false
	end, declare.boolean, "object", declare.string),

	it = ftype:write(function(self: object, that: string): boolean
		return self.type == that
	end, declare.boolean, "object", declare.string),

	eq = ftype:write(function(self: object, that: object) : boolean
		return self == that or self.it(that, self.type)
	end, declare.boolean, "object", "object"),

	base = ftype:write(function <T> (self: T & object, expected: string|nil) : any
		const metainfo = getmetatable(self :: T) :: unknown?

        if (expected ~= nil) then
            const base: object = assert(metainfo, "metainfo does not exists for this object") :: any
            assert(type(base) == declare.table, "base isn't a canonical type bruh")
            assert(type(base.type) == declare.string, "base object doesn't have a properly installed type field")
            assert(base.type == expected, "base object have a unexpected type")
            
            return base
        end

        if (type(metainfo) == declare.table) then
            return metainfo :: object
        end

        return nil -- silenced variant
	end, ftype:opt("object"), "object", ftype:opt(declare.string)),

	host = ftype:write(function <T> (self: T & object, f: (any) -> (), last: boolean?) : ()
		const related = private.host[self] or private.new_host()
        private.host[self] = related

        for i = 1, -1 do
            
        end

	end, declare["nil"], "object", declare["function"], ftype:opt(declare.boolean)),

	as = ftype:write(function <T> (self: unknown, as: string) : T
		const cast, _ = project.assert((self :: object):is(as), "cannot convert this object to required type", true)
		
        if (not cast) then
            return declare.tables.__null
        else
            return self :: T
        end
	end, "object", declare.string),

	that = ftype:write(function<T>(self: object, that: any) : T?
		return self.is(that, "object") and that or nil
	end, ftype:opt("object"), "object", declare.anyt),

	iden = ftype:write(function(self: object) : any
		return tostring(self)
	end, ftype:or_opt(declare.number, declare.string), "object")
}

do
    type host <T = object> = {
        read last: (T) -> ()?,
        parent: host?,
        [number]: (T) -> ()
    }

    private.host = setmetatable({} :: {[object]: host?}, declare.tables.__mode_ks)
    private.new_host = function <T> (parent: object?) : host<T>
        const new: host = {
            last = nil,
            parent = nil
        }
        
        if (parent ~= nil) then
            new.parent = private.get_host(parent)
        end
        
        return new
    end

    private.get_host = function (of: object) : host?
        const related_host = private.host[of]
        
        if (not related_host) then
            const base = of:base()

            if (base ~= nil) then
                return private.get_host(base)
            else
                return nil
            end
        else
            return related_host
        end
    end

    private.call_host = function (of: setmetatable<object, object>|object) : ()
        local first = private.get_host(of)
        local last: host? = declare.tables.dummy :: host
        local prev: host? = first

        repeat
            last = last.parent
            prev = last
        until (last ~= nil)

        local current: host? = first

        while (current ~= nil) do
            
        end

        return
    end

	--#if DEBUG
	if project.debug then
		if project.debug.show_created_objects then
			class:host(function(new: object)
				project.console_out(string.format("new %s", new.type))
			end)
		end
	end
	--#endif

	ctype:write(class, ctype:generate_metainfo(class, {
		ctags.core,
		ctags.common
	}, class.type))
end



return class