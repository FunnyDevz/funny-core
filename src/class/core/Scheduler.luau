--!strict
const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const stderr = require("@extension/stderr")
const stdout = require("@extension/stdout")
const ttable = require("@extension/ttable")
const ftype = require("@static/ftype")
--#include <project.gpp>

const private = { type = "scheduler" }
const class: scheduler = LuaObject:new {
    type = private.type,

	plan = ftype:write(function<T...>(self: scheduler, t: scheduler_teta<T...>, ...: T...): thread
		const new = private.new_tar(t, ...)
		table.insert(private.get_local(self).planned, new)
		return new.run
	end, types.thread, private.type, ftype:uor(types.table, types["function"]), ftype:var_opt(mtypes.anyt)),

	whose = ftype:write(function (self: scheduler, c: thread?): scheduler?
		c = type(c) == types.thread and c or coroutine.running()

		for scheduler, loc in private.loc do
			if c == loc.current then return scheduler end
			for _, tar in loc.planned do
				if tar.run == c and not tar.foreign then return scheduler end
			end
		end

		for _, fn in private.external_sources do
			local ok, s = pcall(fn, c)
			if ok and s ~= nil then return s end
		end

		return nil
	end, ftype:opt(private.type), private.type, types.thread),

	cancel = ftype:write(function(self: scheduler, c: thread): ()
		const loc = private.get_local(self)
		table.remove(loc.planned, table.find(loc.planned, private.find(loc, c)) or 0)
	end, mtypes.never, private.type, types.thread),

	is_planned = ftype:write(function(self: scheduler, a: thread?): boolean
		if a ~= nil then
			stderr:assert(type(a) == "thread", "this is not a coroutine thread")
			return private.find(private.get_local(self), a) ~= nil
		end

		return private.valid(self)
	end, types.boolean, private.type, ftype:opt(types.thread)),

	is_waiting = ftype:write(function(self: scheduler, c: thread?): boolean
		if c == nil then
			return self:is_waiting(coroutine.running())
		else
			const tar = private.find(private.get_local(self), c)
			if not tar then
				return false
			end
			if private.valid(self) then
				return false
			end

			return tar.fwait or false
		end
	end, types.boolean, private.type, ftype:opt(types.thread)),

	hold = ftype:write(function(self: scheduler, time: number?): ()
		const run = coroutine.running()
		const loc = private.get_local(self)
		time = time or 0

		--#if DEBUG
		stderr:assert(run == loc.current, "cannot hold unplanned coroutine")
		--#endif

		if loc.current_tar then
			loc.current_tar.fwait = true
			loc.current_tar.wait = (loc.current_tar.wait and loc.current_tar.wait + time) or (os.clock() + time)
			loc.current_tar.yielded_by_us = true 
			return
		end

		--#if DEBUG
		stdout:oute(`something going wrong with {self.type}, current_tar does not exists`)
		--#endif
	end, mtypes.never, private.type, ftype:opt(types.number)),

	wait = ftype:write(function(self: scheduler, time: number?): ()
		self:hold(time)
		coroutine.yield()
	end, mtypes.never, private.type, ftype:opt(types.number)),

	last = ftype:write(function(self: scheduler, t: any, ...: any): ()
		table.insert(private.get_local(self).planned, 1, private.new_tar(t, ...))
	end, mtypes.never, private.type, ftype:var_or(types.thread, types["function"], ftype:var(mtypes.anyt))),

	next = ftype:write(function(self: scheduler, t: any, ...: any): ()
		--#if DEBUG
		stderr:assert(private.valid(self), "cannot plan next schedule, because this thread actually isn't planned thread")
		--#endif

		const loc = private.get_local(self)
		const tar = stderr:assert(loc.current_tar, "current planned coroutine has a troubles")
		const index = stderr:assert(table.find(loc.planned, tar), "cannot find this coroutine in plan list")
		const new = private.new_tar(t, ...)

		table.insert(loc.planned, index > 1 and index - 1 or 1, new)
	end, mtypes.never, private.type, ftype:var_or(types.thread, types["function"], ftype:var(mtypes.anyt))),

	process = ftype:write(function(self: scheduler): ()
		const loc = private.get_local(self)
		const c = #loc.planned

		for i = c, 1, -1 do
			const tar = loc.planned[i]
			if not tar then
				continue
			end

			if coroutine.status(tar.run) == "dead" then
				table.remove(loc.planned, i)
				continue
			end

			if tar.foreign then
				continue
			end

			if tar.fwait then
				if os.clock() > (tar.wait or 0) then
					tar.wait = nil
					tar.fwait = nil
				else
					continue
				end
			end

			loc.current = tar.run
			loc.current_tar = tar
			tar.yielded_by_us = false

			const state, _ = coroutine.resume(tar.run, table.unpack(tar.call))
			table.clear(tar.call)
			loc.current = nil
			loc.current_tar = nil

			if not state then
				table.remove(loc.planned, i)
				continue
			end

			const status = coroutine.status(tar.run)

			if status == "suspended" then
				if not tar.yielded_by_us then
					tar.foreign = true
				end
			elseif status == "dead" then
				table.remove(loc.planned, i)
			end
		end
	end, mtypes.never, private.type),

	external_source = ftype:write(function (fn: (thread) -> scheduler?) : ()
		ttable.toggle(private.external_sources, fn)
	end, types.boolean, types["function"]),
}

class:host(function(new: luaobject)
    const new = new:as <<scheduler>>(class.type)
	const prev = private.get_local(new)
	const loc_new = { planned = prev and table.clone(prev.planned) or {} }
	private.loc[new] = loc_new
end)

do
	--[==[
    Метаинформация о запланированной коррутине
]==]
	type tar = {
		--[==[
        Запланированная на запуск коррутина
    ]==]
		read run: thread,
		--[==[
        Передаваемые между вызовами аргументы
    ]==]
		read call: { unknown },

		--[==[
        Флаг, указывающий на то что ожидание коррутины вызвано вызовом функции планировщика,
        а не через прямой `coroutine.yield()`

        Этот флаг может быть установлен и в моменте когда коррутина запрашивает hold: она сама выберет
        в какой конкретный момент ей остановиться. Это не влияет на поведение, так как асинхронности в
        языке не существует в параллельном смысле.
    ]==]
		fwait: boolean?,

		--[==[
        Время, которое планировщик ждет для этой коррутины для запуска. В коде проверяется в основном оно,
        потому что ожидается прохождение факта
    ]==]
		wait: number?,

		--[==[
			Yield коррутины был выполнен через этот scheduler
		]==]
		yielded_by_us: boolean?,

		--[==[
			Коррутина перехвачена чужим планировщиком или кодом
		]==]
		foreign: boolean?,
	}

	--[==[
    Приватное состояние каждого объекта планировщика
]==]
	type loc = {
		--[==[
        Цель, которая сейчас выполняется. Кэш.
    ]==]
		current_tar: tar?,
		--[==[
        Коррутина цели, которая сейчас выполняется. Кэш.
    ]==]
		current: thread?,
		--[==[
        Лист запланированных к выполнению целей.
    ]==]
		read planned: { tar? },
	}

	private.mt = tables.__mode_ks
	private.external_sources = setmetatable({} :: {(thread) -> scheduler?}, private.mt)
	private.obj_mt = table.freeze({ __index = class })
	private.loc = setmetatable(
		{
			[class] = { planned = {} },
		} :: { [scheduler]: loc },
		private.mt
	)

	private.convert = function<T...>(t: scheduler_teta<T...>): thread
		const T = type(t)
		
		if T == types.thread then
			return t :: thread
		elseif T == types["function"] then
			return coroutine.create(t :: (...any) -> ...any)
		elseif T == types["nil"] then
			return coroutine.running()
		else
			return stdout:oute(`cannot create plan for this, expected function or coroutine thread, but got {typeof(t)}`)
		end
	end

	private.get_local = function(of: scheduler)
		return private.loc[of]
	end

	private.valid = function(of: scheduler): boolean
		return coroutine.running() == private.get_local(of).current
	end

	private.new_tar = function<T...>(c: scheduler_teta<T...>, ...): tar
		return {
			run = private.convert(c),
			call = { ... },
			wait = nil,
		}
	end

	private.find = function(loc: loc, cor: thread): tar?
		const c = #loc.planned
		for i = c, 1, -1 do
			const tar = loc.planned[i]
			if not tar then
				continue
			end

			if tar.run == cor then
				return tar
			end
		end

		return nil
	end
end

return class
