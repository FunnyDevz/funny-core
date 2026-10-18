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
        private.call_host(self)
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
        const host = private.get_host(self) or private.new_host(self:base())

	end, declare["nil"], "object", declare["function"], ftype:opt(declare.boolean)),

	as = ftype:write(function <T> (self: unknown, as: string) : T
		const cast, _ = project.assert((self :: object):is(as), "cannot convert this object to required type", true)
		
        if (not cast) then
            return declare.tables.__null :: any
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

    private.host_list = setmetatable({} :: {[object]: host?}, declare.tables.__mode_ks)
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

    private.get_host = function (of: object?) : host?
        return of and private.host_list[of] or nil
    end

    private.get_host_chain_list = function (of: object) : {host}
        const list: {host} = {}
        local current: object? = of

        while (current ~= nil) do
            const host = private.get_host(current)

            if (host ~= nil) then
				table.insert(list, host)
            end
        end

        return list
    end

    private.call_host = function (of: setmetatable<object, object>|object) : ()
        const chains = private.get_host_chain_list(of)
        
        for i = #chains, 1, -1 do
            const host = chains[i]

            for i, v in host do
                const state, err = pcall(v, of)

                if (not state) then
                    project.console_out_error(of.type, ttable.find(private.host_list, host) or "*missed-object*", err)
                end
            end
        end
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