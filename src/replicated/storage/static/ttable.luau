const declare = require("@game/ReplicatedStorage/static/declare")

--[==[
    Расширение стандартной библиотеки `table`
]==]
export type ttable = {
    --[==[
        Соединяет две независимые таблицы. Левое - основание, правое перезапишет данные из левой части на свои,
        если у него есть конфликтующие поля.

        Возвращает независимую таблицу.
    ]==]
    read combine: <T,U> (t0: T, t1: U) -> T & U,

    --[==[
        Проверяет именно наличие ключей из правой части в левом основании. Наличие ключа - потенциальный конфликт.
        Факт нормального соединения проверяется через метод `equals(t0, ...)`.
    ]==]
    read conflictable: <T, U...> (t0: T, U...) -> boolean,

    --[==[
        Проверяет совпадение типов в правой части с данными левого основания. Если они отличаются, то
        эквивалент будет отрицательным. Отсутствие данных из основания в правой части не считается поводом для
        отказа в эквиваленте.
    ]==]
    read equals: <T,U...> (t0: T, U...) -> boolean,

    --[==[
        Рекурсивная копия.
    ]==]
    read copy: <T> (t0: T) -> T,
}

local FCALL_COPY : (t0: any) -> any
--[==[
    Метка для очистки кэша, если return попадает на нее
]==]
local FCALL_COPY_TAR : unknown?
--[==[
    Кэш для сопрокидываний рекурсивных ссылок и циклов
]==]
const FCALL_COPY_CACHE = {}


const ttable: ttable = {
    combine = function (t0: any, t1: any): any
        assert(type(t0) == declare.table, "t0 not a table")
        assert(type(t1) == declare.table, "t1 not a table")

        const r0: any = table.clone(t0)
        for i, v in t1 do
            r0[i] = v
        end
        
        return r0
    end,

    conflictable = function (t0: any, ...: any) : boolean
        assert(type(t0) == declare.table, "t0 is not a table")

        for _, v in {...} do
            assert(type(v) == declare.table, "received non-table type")
            
            for i, _ in v do
                if (t0[i] ~= nil) then
                    return true
                end
            end
        end

        return false
    end,

    copy = function (t0: any): any
        assert(type(t0) == declare.table, "t0 is not a table")

        const cached = FCALL_COPY_CACHE[t0]
        if cached ~= nil then return cached end

        const clone = table.clone(t0)
        FCALL_COPY_CACHE[t0] = clone
        if FCALL_COPY_TAR == nil then
            FCALL_COPY_TAR = clone
        end

        for i,v in clone do
            if type(v) == declare.table then
			    clone[i] = FCALL_COPY(v)
            end
        end

        if FCALL_COPY_TAR == clone then
            table.clear(FCALL_COPY_CACHE)
            FCALL_COPY_TAR = nil
        end

        return clone
    end,

    equals = function (t0: any, ...: any): boolean
        assert(type(t0) == declare.table, "t0 is not a table")
        
        for i, v in {...} do
            assert(type(v) == declare.table, "received non-table type")

            for j, d in t0 do
                const T = typeof(v[j])

                if (T ~= typeof(d) and T ~= declare["nil"]) then
                    return false
                end
            end
        end

        return true
    end
}

FCALL_COPY = ttable.copy
table.freeze(ttable)

return ttable