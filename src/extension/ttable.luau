const types = require("@declare/types")
const dummies = require("@declare/dummies")
const stderr = require("@extension/stderr")

type t = { [any]: any }

--[==[
    Расширение стандартной библиотеки `table`

    Для всех массивов считается, что их каноническая форма это `i >= abs(1) ... +inf` ,
    все что не подходит под эту форму не будет учитываться в функциях.

    Все операции с дырами идут только для тех дыр, что считаются внутренними. Внешние и хвостовые дыры
    игнорируются.
]==]
export type ttable = {
	--[==[
        Соединяет две независимые таблицы. Левое - основание, правое перезапишет данные из левой части на свои,
        если у него есть конфликтующие поля.

        Возвращает независимую таблицу, которая является поверхностной копией.
    ]==]
	read combine: <T, U>(t0: T, t1: U) -> T & U,

	--[==[
        Проходится по массиву и убирает любую дыру в нем, тем самым делая его однородным.

        Это модифицирует оригинальный массив
    ]==]
	read fix: <T>(t0: { T? }) -> { T & exist },

	--[==[
        Проходится по всему массиву в поисках этого значения. Если оно есть, то удаляет его, иначе вставляет
    ]==]
	read toggle: <T>(t0: { T }, that: T?) -> (),

	--[==[
        Проходится по массиву и убирает любую дыру в нем, тем самым делая его однородным.

        Это вернет копию
    ]==]
	read fixed: <T>(t0: { T? }) -> { T & exist },

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
	read length: (t0: t) -> number,

	--[==[
        Вернет точное количество дырок в таблице. По скорости наравне с `ttable.count()` и `ttable.length()`.
    ]==]
	read holes: (t0: t) -> number,

	--[==[
        Вернет точные места где в массиве находятся дыры.
    ]==]
	read dump: (t0: t) -> { number },

	--[==[
        Более универсальный аналог `table.find(table, value)`, который ищет уже и среди словарей. 
    ]==]
	read find: (t0: t, ...t) -> ...boolean,

	--[==[
        Проверяет именно наличие ключей из правой части в левом основании. Наличие ключа - потенциальный конфликт.
        Факт нормального соединения проверяется через метод `equals(t0, ...)`.
    ]==]
	read conflictable: (t0: t, ...t) -> boolean,

	--[==[
        Проверяет совпадение типов в правой части с данными левого основания. Если они отличаются, то
        эквивалент будет отрицательным. Отсутствие данных из основания в правой части не считается поводом для
        отказа в эквиваленте.
    ]==]
	read equals: (t0: t, ...t) -> boolean,

	--[==[
        Все данные из правой части обязаны иметь только то, что есть в левом основании. Если отсутствует какой-то ключ,
        то это игнорируется и не считается ошибкой. Только лишние ключи являются поводом отклониться.
    ]==]
	read same: (t0: t, ...t) -> boolean,

	--[==[
        Рекурсивная копия. Без метатаблицы.
    ]==]
	read copy: <T>(t0: T, root: T?) -> T,

	--[==[
        Рекурсивная копия. С метатаблицой.
    ]==]
	read scan: <T>(t0: T, root: T?) -> T,

	--[==[
		Ищет и удаляет указанный элемент. Если успешно, то вернет true.
	]==]
	read frem: (t0: t, ...any) -> ...boolean,
}

type work = {
	root: t?,
	[t]: t?,
}

-- В моменте всегда существует только 1 экземпляр. Второй это упавшая версия. Это затирает table.clear() в конце
-- работы живой версии. Либо, если они все помрут, никто этим не займется. Но это нереально, либо просто кусок мыла
-- вместо нормального кода
--
-- Для этих списков никогда в моменте не может быть параллельных и асинхронных работ, это просто невозможно через
-- lua_stack, даже если оборвать его таймаутами и закидать асинками

const FCALL_COPY_WORK: work = {}
const FCALL_SCAN_WORK: work = {}

local FTTABLE: ttable

const ttable: ttable = {
	combine = function(t0: any, t1: any): any
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return dummies.nullf()
		end
		if not stderr:assert(type(t1) == types.table, "t1 is not a table") then
			return dummies.nullf()
		end

		const r0: any = table.clone(t0)
		for i, v in t1 do
			r0[i] = v
		end

		return r0
	end,

	fix = function(t0)
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return t0 :: { any }
		end

		local keys: { number } = {}
		for i, _ in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				table.insert(keys, i)
			end
		end

		if #keys == 0 then
			return t0 :: { any & exist<> }
		end

		table.sort(keys)

		local max_key = keys[#keys]
		local write = 1

		if max_key <= #keys * 2 then
			for i = 1, max_key do
				if t0[i] ~= nil then
					if write ~= i then
						t0[write] = t0[i]
						t0[i] = nil
					end
					write += 1
				end
			end
		else
			for _, i in keys do
				if write ~= i then
					t0[write] = t0[i]
					t0[i] = nil
				end
				write += 1
			end
		end

		return t0 :: { any & exist<> }
	end,

	toggle = function(t0: t, that): ()
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return
		end

		for i, v in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				if v == that then
					table.remove(t0, i)
					return
				end
			end
		end

		if that ~= nil then
			t0[FTTABLE.length(t0) + 1] = that
		end
	end,

	fixed = function(t0: t)
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return dummies.nullf()
		end

		const clone = {}

		--[[
            Обобщенный итератор это по сути `pairs()`, но он всегда первым проходит array-part, и лишь при дыре или
            при при выходе в hash часть начинает выдавать случайные позиции

            Он также пропускает nil, поэтому мы просто вручную перетащим все что не nil и упакуем это
        ]]
		for i, v in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				table.insert(clone, v)
			else
				clone[i] = v
			end
		end

		return clone
	end,

	dump = function(t0: t): { number }
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return dummies.nullf() :: { any }
		end

		const list: { number } = {}
		local j = 0

		for i, _ in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				j = i - 1

				while j >= 1 and t0[j] == nil do
					table.insert(list, j)
					j -= 1
				end
			end
		end

		table.sort(list)

		return list
	end,

	holes = function(t0: t): number
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return 0
		end

		local max = 0
		local count = 0

		for i, _ in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				max = math.max(max, i)
				count += 1
			end
		end

		return max - count
	end,

	length = function(t0: t): number
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return 0
		end
		local max = 0

		for i, _ in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				max = math.max(max, i)
			end
		end

		return max
	end,

	count = function(t0: t): number
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return 0
		end

		local count = 0

		for i, _ in t0 do
			if type(i) == types.number and i >= 1 and i % 1 == 0 then
				count += 1
			end
		end

		return count
	end,

	conflictable = function(t0: any, ...: any): boolean
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return false
		end

		for _, v in { ... } do
			if not stderr:assert(type(v) == types.table, "value is not a table") then
				return false
			end

			for i, _ in v do
				if t0[i] ~= nil then
					return true
				end
			end
		end

		return false
	end,

	find = function(t0: t, ...: any): ...boolean
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return table.unpack(table.create(select("#", ...), false))
		end

		const n = select("#", ...)
		const list: { boolean } = table.create(n, false)

		for k = 1, n do
			const v = select(k, ...)
			local mark = false

			for _, d in t0 do
				if d == v then
					mark = true
					break
				end
			end

			list[k] = mark
		end

		return table.unpack(list)
	end,

	copy = function(t0: t, root: t?): any
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return t0
		end

		const point: any = root or t0

		if t0 == point then
			table.clear(FCALL_COPY_WORK)
		end

		const work = FCALL_COPY_WORK[point] or { root = point }
		FCALL_COPY_WORK[point] = work

		const clone: t = work[t0] or table.clone(t0)
		work[t0] = clone

		for i, v in next, t0 do
			const i1 = if type(i) == types.table then FTTABLE.copy(i, point) else i
			const v1 = if type(v) == types.table then FTTABLE.copy(v, point) else v

			if i1 ~= i then
				clone[i] = nil
			end
			clone[i1] = v1
		end

		if t0 == point then
			table.clear(FCALL_COPY_WORK)
		end

		return clone
	end,

	scan = function(t0: t, root: t?): any
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return t0
		end

		const point: any = root or t0
		if point == t0 then
			table.clear(FCALL_SCAN_WORK)
		end

		const work = FCALL_SCAN_WORK[point] or { root = point }
		FCALL_SCAN_WORK[point] = work

		const clone: t = work[t0] or table.clone(t0)
		const mt = getmetatable(t0) :: unknown

		work[t0] = clone

		for i, v in next, t0 :: { [unknown]: unknown } do
			local i1: any = i
			local v1: any = v

			if type(i) == types.table then
				const mi: unknown = getmetatable(i :: t)
				i1 = FTTABLE.scan(i, point)

				if type(mi) == types.table then
					setmetatable(i1, FTTABLE.scan(mi, point))
				end
			end

			if type(v) == types.table then
				const mi: unknown = getmetatable(v :: t)
				v1 = FTTABLE.scan(v, point)

				if type(mi) == types.table then
					setmetatable(v1, FTTABLE.scan(mi, point))
				end
			end

			if i1 ~= i then
				clone[i] = nil
			end
			clone[i1] = v1
		end

		if type(mt) == types.table then
			setmetatable(clone, FTTABLE.scan(mt, point))
		end

		if t0 == point then
			table.clear(FCALL_SCAN_WORK)
		end

		return clone
	end,

	frem = function (t0: any, ...: any) : ...boolean
		const list: {boolean} = {}
		
		for _, v in {...} do
			const pos = table.find(t0, v)
			
			if pos ~= nil then
				table.remove(t0, pos)
				table.insert(list, true)
			else
				table.insert(list, false)
			end
		end

		return table.unpack(list)
	end,

	equals = function(t0: any, ...: any): boolean
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return false
		end

		for i, v in { ... } do
			if not stderr:assert(type(v) == types.table, "value is not a table") then
				return false
			end

			for j, d in t0 do
				const T = typeof(v[j])

				if T ~= typeof(d) and T ~= types["nil"] then
					return false
				end
			end
		end

		return true
	end,

	same = function(t0: t, ...: t): boolean
		if not stderr:assert(type(t0) == types.table, "t0 is not a table") then
			return false
		end

		for _, v in { ... } do
			if not stderr:assert(type(v) == types.table, "value is not a table") then
				return false
			end

			for i, _ in v do
				if t0[i] == nil then
					return false
				end
			end
		end

		return true
	end,
}

FTTABLE = ttable
table.freeze(ttable)

return ttable
