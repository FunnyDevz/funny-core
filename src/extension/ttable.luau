const types = require("@declare/types")
const dummies = require("@declare/dummies")
const std = require("@extension/std")

type t = { [any]: any }

const d_type = type
const d_next = next
const d_create = table.create
const d_sort = table.sort
const d_unpack = table.unpack
const types_table = types.table
const types_number = types.number

export type tstats = {
	length: number,
	count: number,
	holes: number,
	max: number,
	contiguous: boolean,
}

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
		Анализирует таблицу на количество, качество и размерность. Заменяет собой 3 вызова `count + length + holes`
	]==]
	read analyze: (tbl: t) -> tstats,

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

	read merge: <T, U>(t0: T, t1: U) -> T & U,

	read cursor: (tbl: {any}?, f: (i: number) -> (), batch: number?, i: number?, m: number?, step: number?) -> (() -> boolean?)
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
		if not std:assert(type(t0) == types.table, "t0 is not a table") then
			return dummies.nullf()
		end

		if not std:assert(type(t1) == types.table, "t1 is not a table") then
			return dummies.nullf()
		end

		const r0: any = table.clone(t0)
		for i, v in t1 do
			r0[i] = v
		end

		return r0
	end,

	analyze = function(t0: t): tstats
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return { length = 0, count = 0, holes = 0, max = 0, contiguous = true }
		end

		local max = 0
		local count = 0

		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
				count += 1
			end
		end

		const holes = max - count
		return {
			length = max,
			count = count,
			holes = holes,
			max = max,
			contiguous = holes == 0,
		}
	end,

	cursor = function (tbl, f, b, i, m, s)
		local i = (i or 1) :: number
		const s = ((s == nil or s == 0) and 1 or s) :: number
		local m_val: number

		if m ~= nil then
			m_val = m
		elseif tbl ~= nil then
			local mx = 0
			for k, _ in d_next, tbl do
				if d_type(k) == types_number and k >= 1 and k % 1 == 0 and k > mx then
					mx = k
				end
			end
			m_val = mx
		else
			m_val = 0
		end

		const m_final = m_val
		const b_final = b or (tbl ~= nil and m_final or 0)

		return function(): boolean?
			local bi = 0
			if (s > 0 and i > m_final) or (s < 0 and i < m_final) then
				return true
			end

			for j = i, m_final, s do
				i = j + s

				if f(j) == false then
					return false
				end

				bi += 1
				if bi >= b_final then
					return nil
				end
			end

			return nil
		end
	end,

	fix = function(t0: t): any
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return t0
		end

		local max = 0
		local count = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
				count += 1
			end
		end

		if max == count then
			return t0
		end

		const keys = d_create(count)
		local k = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				k += 1
				keys[k] = i
			end
		end

		local write = 1

		if max <= count * 2 then
			for i = 1, max do
				const v = t0[i]
				if v ~= nil then
					if write ~= i then
						t0[write] = v
						t0[i] = nil
					end
					write += 1
				end
			end
		else
			d_sort(keys)
			for j = 1, count do
				const i = keys[j]
				if write ~= i then
					t0[write] = t0[i]
					t0[i] = nil
				end
				write += 1
			end
		end

		return t0
	end,

	toggle = function(t0: t, that): ()
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return
		end

		local max = 0
		local hit: number? = nil

		for i, v in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
				-- не break, чтобы до-посчитать max; но фиксируем только первое совпадение
				if hit == nil and v == that then
					hit = i
				end
			end
		end

		if hit ~= nil then
			t0[hit] = nil
		elseif that ~= nil then
			t0[max + 1] = that
		end
	end,

	fixed = function(t0: t)
		if not std:assert(type(t0) == types.table, "t0 is not a table") then
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
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return {} :: { number }
		end

		local max = 0
		local count = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
				count += 1
			end
		end

		const holes = max - count
		if holes <= 0 then
			return {} :: { number }
		end

		if max <= count * 4 then
			const list = d_create<<number>>(holes)
			local w = 0
			for i = 1, max do
				if t0[i] == nil then
					w += 1
					list[w] = i
				end
			end
			return list
		end

		const keys = d_create<<number>>(count)
		local k = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				k += 1
				keys[k] = i
			end
		end
		d_sort(keys)

		const list = d_create<<number>>(holes)
		local w = 0
		local prev = 0
		for j = 1, count do
			const key = keys[j]
			for gap = prev + 1, key - 1 do
				w += 1
				list[w] = gap
			end
			prev = key
		end
		
		return list
	end,

	count = function(t0: t): number
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return 0
		end
		local c = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				c += 1
			end
		end
		return c
	end,

	length = function(t0: t): number
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return 0
		end
		local max = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
			end
		end
		return max
	end,

	holes = function(t0: t): number
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return 0
		end
		local max = 0
		local c = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
				c += 1
			end
		end
		return max - c
	end,

	conflictable = function(t0: any, ...: any): boolean
		if not std:assert(type(t0) == types.table, "t0 is not a table") then
			return false
		end

		for _, v in { ... } do
			if not std:assert(type(v) == types.table, "value is not a table") then
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
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			const n0 = select("#", ...)
			return d_unpack(d_create(n0, false))
		end

		const n = select("#", ...)
		const list = d_create(n, false)
		if n == 0 then
			return d_unpack(list)
		end

		const targets: { [any]: { number } } = {}
		for k = 1, n do
			const v = select(k, ...)
			const entry = targets[v]
			if entry then
				entry[#entry + 1] = k
			else
				targets[v] = { k }
			end
		end

		local remaining = n

		for _, d in d_next, t0 do
			const entry = targets[d]
			if entry then
				for j = 1, #entry do
					list[entry[j]] = true
				end
				remaining -= #entry
				targets[d] = nil
				if remaining == 0 then
					break
				end
			end
		end

		return d_unpack(list)
	end,

	copy = function(t0: t, root: t?): any
		if not std:assert(type(t0) == types.table, "t0 is not a table") then
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
		if not std:assert(type(t0) == types.table, "t0 is not a table") then
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

	frem = function(t0: any, ...: any): ...boolean
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return
		end

		const n = select("#", ...)
		if n == 0 then
			return
		end

		const args = d_create(n)
		for k = 1, n do
			args[k] = select(k, ...)
		end

		local max = 0
		for i, _ in d_next, t0 do
			if d_type(i) == types_number and i >= 1 and i % 1 == 0 then
				if i > max then
					max = i
				end
			end
		end

		const found = d_create(n, false)

		for k = 1, n do
			const v = args[k]
			for i = 1, max do
				if t0[i] == v then
					t0[i] = nil
					found[k] = true
					break
				end
			end
		end

		local write = 1
		for i = 1, max do
			const v = t0[i]
			if v ~= nil then
				if write ~= i then
					t0[write] = v
					t0[i] = nil
				end
				write += 1
			end
		end

		return d_unpack(found)
	end,

	equals = function(t0: any, ...: any): boolean
		if not std:assert(d_type(t0) == types_table, "t0 is not a table") then
			return false
		end

		for _, v in { ... } do
			if not std:assert(d_type(v) == types_table, "value is not a table") then
				return false
			end

			for j, d in d_next, t0 do
				const vv = v[j]
				if vv ~= nil then
					const td = typeof(d)
					const tv = typeof(vv)
					if td ~= tv then
						return false
					end
				end
			end
		end

		return true
	end,

	same = function(t0: t, ...: t): boolean
		if not std:assert(type(t0) == types.table, "t0 is not a table") then
			return false
		end

		for _, v in { ... } do
			if not std:assert(type(v) == types.table, "value is not a table") then
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

	merge = function(t0: any, t1: any): any
		if not std:assert(type(t0) == types.table and type(t1) == types.table, "t0 or t1 is not a table") then
			return t0
		end

		const result = table.clone(t0)

		for k, v in t1 do
			const current = result[k]

			if type(current) == types.table and type(v) == types.table and getmetatable(current) == nil and getmetatable(v) == nil then
				result[k] = FTTABLE.merge(current, v)
			else
				result[k] = v
			end
		end

		if table.isfrozen(t0) then
			table.freeze(result)
		end

		return result
	end,
}

FTTABLE = ttable
table.freeze(ttable)

return ttable
