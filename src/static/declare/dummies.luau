const stdout = require("@extension/stdout")
const global = require("@project/global")

--[==[
    Это реализация паттерна Null Object на Luau: специальный userdata, созданный через newproxy(true) и 
    обвешанный метатаблицей так, чтобы любая операция над ним не падала. 
    
    Идея — заменить nil на «умную пустоту».

    Null не является `falsy`, он не тоже самое что и false или nil, при сравнении в if он всегда будет true.

    В продакшн появление Null сулит взрывом багов.
]==]
export type null = setmetatable<
	{[any]: null},
	{
		read __index: (...any) -> null,
		read __newindex: (...any) -> (),
		read __metatable: null,
		read __eq: (...any) -> false,
		read __call: (...any) -> null,
		read __tostring: (...any) -> string,
		read __len: (...any) -> number,
		read __concat: (...any) -> "null",
		read __add: (...any) -> null,
		read __sub: (...any) -> null,
		read __mul: (...any) -> null,
		read __div: (...any) -> null,
		read __mod: (...any) -> null,
		read __pow: (...any) -> null,
		read __idiv: (...any) -> null,
		read __unm: (...any) -> null,
		read __lt: (...any) -> false,
		read __le: (...any) -> false,
		read __band: (...any) -> null,
		read __bor: (...any) -> null,
		read __bxor: (...any) -> null,
		read __bnot: (...any) -> null,
		read __shl: (...any) -> null,
		read __shr: (...any) -> null,
		read __iter: (...any) -> (() -> (), any),
	}
>

--[==[
    Это пустышки. Они просто есть, и ничего не делают. Либо затеняют все что за ними есть.
]==]
export type dummies = {
    read func: (...any) -> ...any,

    --[==[
        Это абсолютная пустота. Она принимает все что угодно, ест все что угодно, и возвращает все что угодно.
        Но только на саму себя.
    ]==]
    read nullf: () -> null,

    --[==[
        Аналогичен `nullf`, но `null` спрятан в типах.
    ]==]
    read voidf: () -> any,
    read thread: thread,
    read thread_dead: thread,
    read table: {},
    read userdata: any
}

const null: null = newproxy(true)
const null_mt = getmetatable(null) :: any

const func_dummy = function () end
const return_null = function (self): null self()
return null end
const return_false = function (self): false self()
return false end
const return_zero = function (self): number self()
return 0 end

const closed_coroutine = coroutine.create(func_dummy)

null_mt.__index = return_null
null_mt.__newindex = function (self)
    self()
end
null_mt.__metatable = null
null_mt.__eq = function (self, that)
    if tostring(that) == "null" then
        return true
    end

    return false
end

null_mt.__call = function (self)
    if (not global.debug or not global.nullable) then
        stdout:oute("NullObject")
    end

    if (global.debug) then
        stdout:outw("NullObject used")
    end

    return null
end
null_mt.__tostring = function(self): string self()
return "null" end
null_mt.__len = return_zero
null_mt.__concat = null_mt.__tostring
null_mt.__add = return_null
null_mt.__sub = return_null
null_mt.__mul = return_null
null_mt.__div = return_null
null_mt.__mod = return_null
null_mt.__pow = return_null
null_mt.__idiv = return_null
null_mt.__unm = return_null
null_mt.__lt = return_false
null_mt.__le = return_false
null_mt.__band = return_null
null_mt.__bor = return_null
null_mt.__bxor = return_null
null_mt.__bnot = return_null
null_mt.__shl = return_null
null_mt.__shr = return_null
null_mt.__iter = function(self): (() -> (), nil) self()
return func_dummy, nil end
table.freeze(null_mt)

coroutine.close(closed_coroutine)

const nullf = function () : null
    if (not global.debug or not global.nullable) then
        return stdout:oute "Null object isn't allowed to use"
    end

    return null
end

const dummies: dummies = {
    func = func_dummy,
    nullf = nullf,
    voidf = nullf,

    thread = coroutine.create(function(...)
        while true do
            coroutine.yield()
        end
    end),

    thread_dead = closed_coroutine,
    table = {},
    userdata = newproxy()
}

table.freeze(dummies)
return dummies