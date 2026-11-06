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
const engine = require("@platform/roblox/engine")
const ftype = require("@static/ftype")

const private = { type = "disposable" }
const class: disposable = LuaObject:new({
	type = private.type,

	free = ftype:write(function(self: disposable): ()
		const identity = self:iden()

		if private.gcstrong[identity] == nil then return end
		private.gcstrong[identity] = nil

		const pointer = private.gclink[self]
		if pointer ~= nil then
			private.gcheap[#private.gcheap + 1] = pointer
		end
	end, mtypes.never, private.type),

	is_releasing = ftype:write(function(self: disposable): boolean
		return private.gcstrong[self:iden()] == nil
	end, types.boolean, private.type),

	finally = ftype:write(function(self: disposable, ...: ((luaobject_identity: string) -> ())|disposable): ()
		const point = private.gclink[self]
		const dest = point and private.gcfinally[point]
		if not dest then
			--#if DEBUG
			if not self:is(private.type) then
				std:outw(`you're trying to set finally function to {self.type} object that isn't a disposable or his child.`)
			else
				std:outw(`object {self.type} with {self:iden()} isn't exist in our gc-lists`)
			end
			--#endif

			return
		end

		const n = select("#", ...)
		const len = #dest
		for i = 1, n do
			const val = select(i, ...)

			if self.is(val, private.type) then
				const v_disp = val :: disposable
				const iden = v_disp:iden()
				dest[len + 1] = function (id: string)
					const object = LuaObject:fetch(iden)
					if LuaObject:that(object, private.type) then
						const disposable_object = object :: disposable
						disposable_object:free()
					end
				end
			elseif type(val) == types["function"] then
				dest[len + i] = val
			--#if DEBUG
			else
				std:outw("received unknown type")
			--#endif
			end
		end
	end, mtypes.never, private.type, types["function"]),

	get = function<Y>(self: disposable, label: unknown): Y
		return private.shadow_space[self][label]
	end,

	set = function<Y>(self: disposable, label: unknown, to: Y): ()
		private.shadow_space[self][label] = to
	end,
})

do
	private.shadow_space = setmetatable({} :: { [disposable]: { [any]: any } }, tables.__mode_ks)
	private.gclink = setmetatable({} :: { [disposable]: userdata }, tables.__mode_ks)
	private.gcfinally = setmetatable({} :: { [userdata]: { (string) -> () } }, tables.__mode_ks)
	private.gcidentity = setmetatable({} :: { [userdata]: string }, tables.__mode_ks)
	private.gcheap = {} :: { userdata }
	private.gcstrong = {} :: { [string]: disposable }
	private.gcclean = {} :: { number }
	private.gckill = {} :: { [number]: boolean }

	const FRAME_BUDGET = --[[#GCCYCLE_FRAME_BUDGET]] --[[#ifdef GCCYCLE_FRAME_BUDGET]] --[[#lua_OR]] --[[#endif]] 0.0025
	const TIME_CHECK_INTERVAL = --[[#GCCYCLE_TIME_CHECK_INTERVAL]] --[[#ifdef GCCYCLE_TIME_CHECK_INTERVAL]] --[[#lua_OR]] --[[#endif]] 8
	const MAX_ITEMS_PER_FRAME = --[[#GCCYCLE_MAX_ITEMS_PER_FRAME]] --[[#ifdef GCCYCLE_MAX_ITEMS_PER_FRAME]] --[[#lua_OR]] --[[#endif]] 512
	
	private.new = function(new: luaobject)
		const new = new:as<<disposable>>(class.type)
		const pointer = newproxy()
		const identity = new:iden()

		private.shadow_space[new] = {}
		private.gclink[new] = pointer
		private.gcfinally[pointer] = {}
		private.gcstrong[identity] = new
		private.gcidentity[pointer] = identity
	end

	private.gccall = function(i: number)
		const pointer = private.gcheap[i]
		const finally = private.gcfinally[pointer]

		if finally then
			for j = #finally, 1, -1 do
				const state, out = pcall(finally[j], private.gcidentity[pointer])

				--#if DEBUG
				if not state then
					std:outw(`finally part of {private.gcidentity[pointer]} return error, nothing happened but something can be broken. Error is {out}`)
				end
				--#endif
			end
		end

		private.gcclean[#private.gcclean + 1] = i
	end

	private.cursor_idx = 0 :: number
	private.pass_size = 0 :: number

	private.step = function(): boolean
		const heap = private.gcheap

		if private.cursor_idx == 0 then
			private.cursor_idx = 1
			private.pass_size = #heap
		end

		const deadline = os.clock() + FRAME_BUDGET
		local budget_items = MAX_ITEMS_PER_FRAME
		local steps_since_clock = 0

		while private.cursor_idx <= private.pass_size and budget_items > 0 do
			private.gccall(private.cursor_idx)

			private.cursor_idx = private.cursor_idx + 1
			budget_items = budget_items - 1
			steps_since_clock = steps_since_clock + 1

			if steps_since_clock >= TIME_CHECK_INTERVAL then
				steps_since_clock = 0

				if os.clock() >= deadline then
					return true
				end
			end
		end

		return false
	end

	private.finish_pass = function()
		const kill = private.gckill
		const heap = private.gcheap
		const finally_tbl = private.gcfinally
		const gcclean = private.gcclean
		const identity = private.gcidentity

		for k = 1, #gcclean do
			kill[gcclean[k]] = true
		end

		const n = #heap
		local write = 1
		for read = 1, n do
			const ptr = heap[read]
			if kill[read] then
				finally_tbl[ptr] = nil
			else
				heap[write] = ptr
				write = write + 1
			end
		end

		for k = n, write, -1 do
			const pointer = heap[k]
			heap[k] = nil
			identity[pointer] = nil
		end

		table.clear(gcclean)
		table.clear(kill)
		private.cursor_idx = 0
		private.pass_size = 0
	end

	engine.frame:Connect(function()
		if #private.gcheap == 0 then
			return
		end

		if private.step() == false then
			private.finish_pass()
		end
	end)


	--#if CORE_CLASS_USEABLE
	private.new(class)
	--#endif
end

class:host(private.new)

return class