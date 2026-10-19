--!strict
--#include <project.gpp>

const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const project = require("@game/ReplicatedStorage/static/project")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const ttable = require("@game/ReplicatedStorage/static/ttable")

const private = {}
const class: luaobject = {
	type = "luaobject",

	new = ftype:write(function <T,U> (self: T, that: U?): any
        if (not project.assert(type(self) == declare.table, "unexpected self argument", true)) then
            return declare.tables.__null
        end

        if (that ~= nil) then
            if (not project.assert(type(that) == declare.table, "unexpected that argument, ingoring", true)) then
                that = nil
            end
        end

        const raw: any = that and ttable.combine(self, that) or table.clone(self)
		const child: luaobject = setmetatable(raw, getmetatable(self)) :: any
        const finally = private.get_finally(child)

        if (that == nil) then
            ctype:write(child, ctype:read(self))
        else
            if (not ttable.same(self, that)) then
                ctype:write(child, ctype:generate_metainfo(child, ctype:read(self).tag, child.type))
            else
                ctype:write(child, ctype:read(self))
            end
        end

        private.call_host(child)

        if (finally) then
            finally(child, private.get_finally(self))
        end

        return child
	end, "luaobject", ftype:uor(declare.table, "luaobject"), ftype:opt(declare.table)),

	is = ftype:write(function(self: luaobject, that: string): boolean
		if (that == declare.anyt) then return true end

		local base = self

		while base do
			if (base:it(that)) then return true end
            base = base:base()
		end

		return false
	end, declare.boolean, "luaobject", declare.string),

	it = ftype:write(function(self: luaobject, that: string): boolean
		return self.type == that
	end, declare.boolean, "luaobject", declare.string),

    same = ftype:write(function(self: luaobject, ...: luaobject) : boolean
        for _, that in {...} do
            if not (self == that or self.is(that, self.type)) then
                return false
            end
        end

        return true
    end, declare.boolean, "luaobject", ftype:var("luaobject")),

	eq = ftype:write(function(self: luaobject, ...: luaobject) : ...boolean
        const equality: {boolean} = {}

        for _, that in {...} do
            table.insert(equality, self == that or self.is(that, self.type))
        end

		return table.unpack(equality)
	end, ftype:var(declare.boolean), "luaobject", ftype:var("luaobject")),

	base = ftype:write(function <T> (self: T & luaobject) : any
		const metainfo = getmetatable(self :: T) :: unknown?

        if (type(metainfo) == declare.table) then
            return metainfo :: luaobject
        end

        return nil -- silenced variant
	end, ftype:opt("luaobject"), "luaobject", ftype:opt(declare.string)),

	host = ftype:write(function (self: luaobject, f: (any) -> ()) : ()
        ttable.toggle(private.get_host_or_create(self) :: any, f)
	end, declare["nil"], "luaobject", declare["function"]),

	as = ftype:write(function <T> (self: unknown, as: string) : T
		const cast, _ = project.assert((self :: luaobject):is(as), "cannot convert this luaobject to required type", true)
		
        if (not cast) then
            return declare.tables.__null :: any
        else
            return self :: T
        end
	end, "luaobject", declare.string),

	that = ftype:write(function<T>(self: luaobject, that: unknown, otype: string): any?
        if type(that) ~= declare.table or type((that :: any).is) ~= declare["function"] then
            return nil
        end

        return (that :: luaobject):is(otype) and (that :: any) or nil 
    end, ftype:opt("luaobject"), "luaobject", declare.anyt),

	iden = ftype:write(function(self: luaobject) : number
		return tonumber(tostring(self)) or -1
	end, declare.number, "luaobject"),

    finally = ftype:write(function(self: luaobject, f: object_finally_type?) : ()
        private.finally[self] = f
    end, declare["nil"], "luaobject", declare["function"]),

    tget = ftype:write(function (self: luaobject, name: string) : any?
        const meta = ctype:read(self)

        if (not meta.guaranteed) then
            return nil
        end

        if (meta:has_field(name)) then
            return (self :: any)[name]
        else
            return nil
        end
    end, ftype:opt(declare.anyt), "luaobject", declare.string),

    tset = ftype:write(function (self: luaobject, name: string, value: any?) : ()
        const meta = ctype:read(self)
        if (not meta.guaranteed) then
            return
        end

        if const field = meta:read_field(name) then
            if value == nil and field.type.opt or table.find(field.type.tval, declare.utypeof(value)) then
                (self::any)[name] = value
            end
        end
        
        return
    end, declare["nil"], "luaobject", declare.string, ftype:opt(declare.anyt)),

    tcall = ftype:write(function (self: luaobject, name: string, ...: any?) : ...any?
        const meta = ctype:read(self)
        const func = meta:read_func(name)

        if func == nil then
            --#if DEBUG
            if project.debug.state then
                project.console_out_error(`tcall: function "{name}" not registered on "{self.type}"`)
            end
            --#endif
            return
        end

        local ffunc_self: ((...any) -> ...any)? = (self::any)[name]

        if ffunc_self == nil then
            --#if DEBUG
            if project.debug.state then
                project.console_out_error([[
                    (!*) The difference of meta information at the class level.

                    Apparently, the function is unexpectedly nil, although it is expected to exist.
                    In this case, there will be an attempt to find her through the base.]])
            end
            --#endif

            local base = self:base() :: luaobject?

            while base ~= nil do
                const bmeta = ctype:read(base)

                if bmeta:has_func(name) then
                    ffunc_self = (base :: any)[name]
                    if ffunc_self ~= nil then
                        break
                    end
                else
                    --#if DEBUG
                    if project.debug.state then
                        project.console_out([[
                            (!*) tcall couldn't reach the function because it's not in the base or in the object itself.
                            This probably indicates that there is misinformation in the class metadata.]])
                    end
                    --#endif
                    return
                end

                base = base:base() :: luaobject?
            end
        end

        if ffunc_self == nil then
            return
        end

        const args = table.pack(...)
        const sigs = func.type.arguments_types
        local si = 1

        for ai = 1, args.n do
            if si > #sigs then
                --#if DEBUG
                if project.debug.state then
                    project.console_out_error(`tcall: too many arguments for "{name}" (got {args.n}, expected {#sigs})`)
                end
                --#endif
                return
            end

            const sig = sigs[si]

            if not private.matches_argument(args[ai], sig) then
                --#if DEBUG
                if project.debug.state then
                    project.console_out_error(`tcall: argument #{ai} doesn't match signature of "{name}"`)
                end
                --#endif
                return
            end

            if not sig.var then
                si += 1
            end
        end

        while si <= #sigs do
            const sig = sigs[si]
            if not (sig.opt or sig.var) then
                --#if DEBUG
                if project.debug.state then
                    project.console_out_error(`tcall: missing required argument #{si} for "{name}"`)
                end
                --#endif
                return
            end
            si += 1
        end

        return (ffunc_self :: any)(...)
    end, ftype:var_opt(declare.anyt), "luaobject", declare.string, ftype:var_opt(declare.anyt)),

    ttype = ftype:write(function (self: luaobject | unknown): string?
        if (type(self) == declare.table) then
            if (type((self :: any).type) == declare.string) then
                return (self :: any).type
            end
        end

        return nil
    end, ftype:opt(declare.string), ftype:uor(declare.anyt, "luaobject"))
}

do
    type host <T = luaobject> = {
        [number]: (T) -> ()
    }

    private.host_list = setmetatable({} :: {[luaobject]: host?}, declare.tables.__mode_ks)
    private.finally = setmetatable({} :: {[luaobject]: object_finally_type?}, declare.tables.__mode_ks)

    private.get_finally = function (of: luaobject) : object_finally_type?
        local current: luaobject? = of

        while (current ~= nil) do
            const finally = private.finally[current]

            if (finally ~= nil) then
                return finally
            end

            current = current:base()
        end

        return nil
    end

    private.new_host = function (parent: luaobject?) : host
        const new: host = {

        }
        
        return new
    end

    private.get_host = function (of: luaobject?) : host?
        return of and private.host_list[of] or nil
    end

    private.get_host_or_create = function (of: luaobject?): host?
        if (of ~= nil) then
            const host: host = private.host_list[of] or private.new_host(of:base())
            private.host_list[of] = host
            return host
        end

        return nil
    end

    private.get_host_chain_list = function (of: luaobject) : {host}
        const list: {host} = {}
        local current: luaobject? = of

        while (current ~= nil) do
            const host = private.get_host(current)

            if (host ~= nil) then
				table.insert(list, host)
            end

            current = current:base()
        end

        return list
    end

    private.call_host = function (of: setmetatable<luaobject, luaobject>|luaobject) : ()
        const chains = private.get_host_chain_list(of)
        
        for i = #chains, 1, -1 do
            const host = chains[i]

            for i, v in host do
                const state, err = pcall(v, of)

                if (not state) then
                    project.console_out_error(of.type, ttable.find(private.host_list, host) or "*missed-luaobject*", err)
                end
            end
        end
    end

        private.matches_argument = function (value: any, sig): boolean
        if value == nil and (sig.opt or sig.var) then
            return true
        end

        const utype = declare.utypeof(value)

        for _, tv in sig.tval do
            if type(tv) == declare.string then
                if tv == declare.anyt or tv == utype then
                    return true
                end

                if value ~= nil and type((value :: any).is) == declare["function"] then
                    local ok, res = pcall((value :: any).is, value, tv)
                    if ok and res == true then
                        return true
                    end
                end
            else
                if private.matches_argument(value, tv) then
                    return true
                end
            end
        end

        return false
    end

	--#if DEBUG
	if project.debug then
		if project.debug.show_created_objects then
			class:host(function(new: luaobject)
				project.console_out(string.format("new %s", new.type))
			end)

            class:host(function(new)
                
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