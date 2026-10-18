const declare = require("@game/ReplicatedStorage/static/declare")

type t = {[any]: any}
type function negation_of_nil () return types.negationof(types.singleton(nil)) end

--[==[
    Расширение стандартной библиотеки `table`

    Для всех массивов считается, что их каноническая форма это `i >= abs(1) ... +inf` ,
    все что не подходит под эту форму не будет учитываться в функциях
]==]
export type ttable = {
    --[==[
        Соединяет две независимые таблицы. Левое - основание, правое перезапишет данные из левой части на свои,
        если у него есть конфликтующие поля.

        Возвращает независимую таблицу.
    ]==]
    read combine: <T,U> (t0: T, t1: U) -> T & U,

    --[==[
        Проходится по массиву и убирает любую дыру в нем, тем самым делая его однородным.

        Это модифицирует оригинальный массив
    ]==]
    read fix: <T> (t0: {T?}) -> {T & negation_of_nil<>},

    --[==[
        Проходится по массиву и убирает любую дыру в нем, тем самым делая его однородным.

        Это вернет копию
    ]==]
    read fixed: <T> (t0: {T?}) -> {T & negation_of_nil<>},

    --[==[
        Вручную считает все поля полным обходом через цикл. Это гораздо медленней чем использование `#table`,
        но гарантирует количество именно что существующих внутри таблицы объектов.

        В рантайме у оператора длинны есть множество способов определить границы: он может использовать подсказки,
        смотреть ближайшие элементы за и после подсказки на +1 или -1, либо искать бинарным поиском. В общем случае,
        возврат границы оператором точно не гарантирован при дырах.
    ]==]
    read count: (t0: t) -> number,

    --[==[
        При помощи цикла проходит по всей таблице и считает именно что длинну всей таблицы, даже если элементов внутри
        по факту меньше из-за дыр. Вернется самый большой индекс массива.

        Медленней чем оператор `#`, но гарантированно вернет длинну.
    ]==]
    read lenght: (t0: t) -> number,

    --[==[
        Вернет точное количество дырок в таблице. По скорости наравне с `ttable.count()` и `ttable.lenght()`
    ]==]
    read holes: (t0: t) -> number,

    --[==[
        Вернет точные места где в массиве находятся дыры.
    ]==]
    read dump: (t0: t) -> {number},

    read find: (t0: t, ...any) -> ...boolean,

    --[==[
        Проверяет именно наличие ключей из правой части в левом основании. Наличие ключа - потенциальный конфликт.
        Факт нормального соединения проверяется через метод `equals(t0, ...)`.
    ]==]
    read conflictable: (t0: t, ...any) -> boolean,

    --[==[
        Проверяет совпадение типов в правой части с данными левого основания. Если они отличаются, то
        эквивалент будет отрицательным. Отсутствие данных из основания в правой части не считается поводом для
        отказа в эквиваленте.
    ]==]
    read equals: (t0: t, ...any) -> boolean,

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
const ASSERT_TABLE = function (t) assert(type(t) == declare.table, "t0 not a table") end

const ttable: ttable = {
    combine = function (t0: any, t1: any): any
        ASSERT_TABLE(t0)
        ASSERT_TABLE(t1)

        const r0: any = table.clone(t0)
        for i, v in t1 do
            r0[i] = v
        end
        
        return r0
    end,

    fix = function (t0)
    	ASSERT_TABLE(t0)
        local j = 0
        
        for i, _ in t0 do
            if (type(i) == declare.number) then
                j = i

                while (t0[j] == nil) do
                    table.remove(t0, j)
    				j += 1
                end
            end
        end
        
        return t0 :: {any & negation_of_nil<>}
    end,

    fixed = function (t0: t)
    	ASSERT_TABLE(t0)
        const clone = {}

        --[[
            Обобщенный итератор это по сути `pairs()`, но он всегда первым проходит array-part, и лишь при дыре или
            при при выходе в hash часть начинает выдавать случайные позиции

            Он также пропускает nil, поэтому мы просто вручную перетащим все что не nil и упакуем это
        ]]
        for i,v in t0 do
            if (type(i) == declare.number) then
                table.insert(clone, v)
            else
                clone[i] = v
            end
        end

        return clone
    end,

    dump = function (t0: t)
    	ASSERT_TABLE(t0)
        const list: {number} = {}
        local j = 0

        for i, _ in t0 do
            if type(i) == declare.number then
                j = i - 1

                while (t0[j] == nil) do
                    table.insert(list, j)
                    j -= 1

                    if (j <= 0) then
                        break
                    end
                end
            end
        end

        return list
    end,

    holes = function (t0)
    	ASSERT_TABLE(t0)

        local max = 0
        local count = 0

        for i, _ in t0 do
            if (type(i) == declare.number) then
                max = i
                count += 1
            end
        end

        return max - count
    end,
    
    lenght = function (t0)
    	ASSERT_TABLE(t0)

        local max = 0

        for i, _ in t0 do
            if (type(i) == declare.number) then
                max = i
            end
        end

        return max
    end,

    count = function (t0: t) : number
    	ASSERT_TABLE(t0)

        local count = 0

        for i, _ in t0 do 
            if (type(i) == declare.number) then
			    count += 1
            end
        end

        return count
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

    find = function (t0, ...)
    	ASSERT_TABLE(t0)

        const list: {boolean} = {}

        for _, v in {...} do
            local mark = false

            for i, d in t0 do
                if (d == v) then
                    mark = true                    
                    break
                end
            end

            table.insert(list, mark)
        end

        return unpack(list)
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