--!strict
--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const std = require("@extension/std")
const ttable = require("@extension/ttable")
const ftype = require("@static/ftype")
const dummies = require("@declare/dummies")

const private = { type = "scheduler" }
const class: scheduler = LuaObject:new {
    type = private.type,

	plan = ftype:write(function<T...>(self: scheduler, t: scheduler_teta<T...>, ...: T...): thread
		const new = private.new_tar(t, ...)
		const loc = private.get_local(self)
		const existing, location = private.find(loc, private.convert(t))

		if existing then
			-- clean up if we have foreign tar (pos 2, check scheduler:process())
			table.remove(loc.planned, location)
		end

		table.insert(loc.planned, new)
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

	cancel = ftype:write(function(self: scheduler, c: thread?): ()
		const loc = private.get_local(self)
		local is_my_thread = false
		local is_foreign = false
		c = c or coroutine.running()

		for i = #loc.planned, 1, -1 do
			const tar = loc.planned[i]

			if tar == nil then
				table.remove(loc.planned, i)
				continue
			end

			if tar.run == c then
				table.remove(loc.planned, i)
				is_my_thread = true
				is_foreign = is_foreign ~= true and tar.foreign or false
				continue
			end
		end

		if is_my_thread then
			--#if CORE_SCHEDULER_CANCEL_KILL_THREAD
			if not is_foreign then
				if coroutine.running() ~= c then
					coroutine.close(c)
				else
					self:plan(coroutine.close :: any, c)
					if (coroutine.isyieldable()) then
						coroutine.yield()
					else
						return
					end
				end
			end
			--#endif
		--#if DEBUG
		else
			std:outw("you're trying to cancel unknown thread")
		--#endif
		end
	end, mtypes.never, private.type, ftype:opt(types.thread)),

	is_planned = ftype:write(function(self: scheduler, a: thread?): boolean
		if a ~= nil then
			std:assert(type(a) == "thread", "this is not a coroutine thread")
			return private.find(private.get_local(self), a) ~= nil
		end

		return private.valid(self)
	end, types.boolean, private.type, ftype:opt(types.thread)),

	is_waiting = ftype:write(function(self: scheduler, c: thread?): boolean
		if c == nil then
			if private.valid(self) then	return false end
			c = coroutine.running()
		end

		const tar = private.find(private.get_local(self), c :: thread)
		return tar and tar.fwait or false
	end, types.boolean, private.type, ftype:opt(types.thread)),

	is_foreign = ftype:write(function (self: scheduler, c: thread?): boolean
		if not c then return false end

		const tar = private.find(private.get_local(self), c)
		if not tar then return false end
		
		return tar.foreign or false
	end, types.boolean, private.type, ftype:opt(types.thread)),

	hold = ftype:write(function(self: scheduler, time: number?): ()
		const run = coroutine.running()
		const loc = private.get_local(self)
		time = time or 0

		if run ~= loc.current then
			--#if DEBUG
			std:oute "cannot hold"
			--#endif
			return
		end

		if loc.current_tar then
			loc.current_tar.fwait = true
			loc.current_tar.wait = (loc.current_tar.wait and loc.current_tar.wait + time) or (os.clock() + time)
			loc.current_tar.yielded_by_us = true

			-- aka
			--[===[
				```luau
					scheduler:hold(634)
					-- ...some code
					coroutine.yield()
					-- ...after some time our coroutine start working
				```
			]===]

			return
		end

		--#if DEBUG
		std:oute(`something going wrong with {self.type}, current_tar does not exists`)
		--#endif
	end, mtypes.never, private.type, ftype:opt(types.number)),

	wait = ftype:write(function(self: scheduler, time: number?): ()
		self:hold(time)
		const loc = private.get_local(self)
		const current_tar = loc.current_tar

		if not current_tar then
			--#if DEBUG
			std:oute "tar is nil"
			--#endif
			return
		end

		current_tar.yielded_by_us = true
		coroutine.yield()
	end, mtypes.never, private.type, ftype:opt(types.number)),

	last = ftype:write(function(self: scheduler, t: any, ...: any): ()
		const loc = private.get_local(self)
		const existing, location = private.find(loc, private.convert(t))
		
		if existing then
			-- clean up if we have foreign tar (pos 2, check scheduler:process())
			table.remove(loc.planned, location)
		end

		table.insert(loc.planned, 1, private.new_tar(t, ...))
	end, mtypes.never, private.type, ftype:var_or(types.thread, types["function"], ftype:var(mtypes.anyt))),

	next = ftype:write(function(self: scheduler, t: any, ...: any): ()
		--#if DEBUG
		std:assert(private.valid(self), "cannot plan next schedule, because this thread actually isn't planned thread")
		--#endif

		const loc = private.get_local(self)
		const tar = std:assert(loc.current_tar, "current planned coroutine has a troubles")
		const index = std:assert(table.find(loc.planned, tar), "cannot find this coroutine in plan list")
		const new = private.new_tar(t, ...)
		const existing, location = private.find(loc, private.convert(t))
		
		if existing then
			-- clean up if we have foreign tar (pos 2, check scheduler:process())
			table.remove(loc.planned, location)
		end

		table.insert(loc.planned, index > 1 and index - 1 or 1, new)
	end, mtypes.never, private.type, ftype:var_or(types.thread, types["function"], ftype:var(mtypes.anyt))),

	process = ftype:write(function(self: scheduler): ()
		const loc = private.get_local(self)
		if coroutine.running() == loc.current then
			--#if DEBUG
			std:oute "you're trying to call scheduler:process() inside a planned coroutine"
			--#endif
			return
		end
		
		const c = #loc.planned
		const plan = table.clone(loc.planned)



		for i = c, 1, -1 do
			const tar = plan[i]
			if not tar then continue end
			if not tar.run then tar.run = dummies.thread_dead end

			if coroutine.status(tar.run) == "dead" then
				table.remove(loc.planned, table.find(loc.planned, tar) or 0)
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
				table.remove(loc.planned, table.find(loc.planned, tar) or 0)
				continue
			end

			const status = coroutine.status(tar.run)

			if status == "suspended" then
				if not tar.yielded_by_us then
					tar.foreign = true
					
					
					-- for scheduler:whose() and another, we should never delete
					-- this element, ever if he isn't controlled by us.
					-- Code that controls our coroutine can return control to us
					-- by scheduler:plan or something
					
					--#if CORE_SCHEDULER_REMOVE_FOREIGN_THREAD
					table.remove(loc.planned, table.find(loc.planned, tar) or 0)
					--#endif
				end
			elseif status == "dead" then
				table.remove(loc.planned, table.find(loc.planned, tar) or 0)
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
	type tar = {
		read run: thread,
		read call: { unknown },

		fwait: boolean?,
		wait: number?,
		yielded_by_us: boolean?,
		foreign: boolean?,
	}

	type loc = {
		current_tar: tar?,
		current: thread?,
		read planned: { tar? },
	}

	private.mt = tables.__mode_ks
	private.external_sources = setmetatable({} :: {(thread) -> scheduler?}, private.mt)
	private.loc = setmetatable({} :: { [scheduler]: loc }, private.mt)



	private.convert = function<T...>(t: scheduler_teta<T...>): thread
		const T = type(t)
		
		if T == types.thread then
			return t :: thread
		elseif T == types["function"] then
			return coroutine.create(t :: (...any) -> ...any)
		elseif T == types["nil"] then
			return coroutine.running()
		else
			return std:oute(`cannot create plan for this, expected function or coroutine thread, but got {typeof(t)}`)
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

	private.find = function(loc: loc, cor: thread): (tar?, number)
		const c = #loc.planned
		for i = c, 1, -1 do
			const tar = loc.planned[i]
			if not tar then
				continue
			end

			if tar.run == cor then
				return tar, i
			end
		end

		return nil, 0
	end

	--#if CORE_CLASS_USEABLE
	private.loc[class] = {planned = {}}
	--#endif
end

return class
