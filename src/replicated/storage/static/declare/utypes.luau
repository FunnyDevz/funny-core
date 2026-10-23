const mtypes = require("@declare/mtypes")

export type utypes = {

    --[==[
        Имя класса `luaobject` шарится еще и как тип для всех объектов.
    ]==]
    read luaobject: "luaobject",

    --[==[
        Читает `user type`, либо возвращает тип объекта через `typeof()`.
    ]==]
    read utype: (self: utypes, of: unknown) -> string,

    --[==[
        Это `user type`?
    ]==]
    read is_utype: (self: utypes, that: string) -> boolean,

    --[==[
        Это объект с `user type`?
    ]==]
    read has_utype: (self: utypes, that: unknown) -> boolean,

    [string]: unknown
}

--[==[
    Словарь всех зарегистрированных пользовательских типов и релевантных данных
]==]
const utypes: utypes = {

    --[==[
        Тип класса `luaobject` шарится еще и как тип для всех объектов, которые различает система.
    ]==]
    ["luaobject"] = "luaobject" :: "luaobject",

    --[==[
		Попытается вывести user type значения, если это доступно. Либо вернет `typeof()`
	]==]
	utype = function(self, of: any) : string
		const T = typeof(of)

		if T == "table" then
			const mt = getmetatable(of)
			if type(mt) == "table" then
				if type(mt.__utype) == "string" then
					return mt.__utype
				end
			end
		elseif T == "userdata" then
			const mt = getmetatable(of)

			if type(mt) == "table" then
				if type(mt.__utype) == "string" then
					return mt.__utype
				end
			end
		end

		return T
	end,

    has_utype = function (self, that) : boolean
        return self:is_utype(self:utype(that))
    end,

    is_utype = function (self, that) : boolean
        return self[that] ~= nil or that == mtypes.anyt
    end
}

table.freeze(utypes)
return utypes
