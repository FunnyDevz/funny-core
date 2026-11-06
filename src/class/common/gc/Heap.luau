--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const engine = require("@platform/roblox/engine")
const ftype = require("@static/ftype")
const LuaObject = require("@class/core/LuaObject")

const private = { type = "heap" }
const class: heap = LuaObject:new({
	type = private.type,

	register = ftype:write(function(self: heap, ...: luaobject | { [any]: any }): userdata
		const pointer = newproxy()
		const tokens: { userdata } = {}

		local n = select("#", ...)
		for i = 1, n do
			const v = select(i, ...)
			if type(v) == types.table and (v :: any).type == nil then
				for _, obj in next, v do
					tokens[#tokens + 1] = private.track(pointer, obj :: luaobject)
				end
			else
				tokens[#tokens + 1] = private.track(pointer, v :: luaobject)
			end
		end

		private.groups[pointer] = {
			active = true,
			finalizers = {},
			tokens = tokens,
		}

		return pointer
	end, mtypes.anyt, private.type, ftype:var(ftype:uor(private.type, types.table))),

	unregister = ftype:write(function(self: heap, ...: userdata): ()
		local n = select("#", ...)
		for i = 1, n do
			const p = select(i, ...)
			if p ~= nil then
				const group = private.groups[p]
				if group ~= nil then
					group.active = false
					private.groups[p] = nil
				end
			end
		end
	end, mtypes.never, private.type, ftype:var(mtypes.anyt)),

	finally = ftype:write(function(self: heap, pointer: userdata, ...: (string) -> ()): ()
		if pointer == nil then
			return
		end
		const group = private.groups[pointer]
		if group == nil or not group.active then
			return
		end

		const finalizers = group.finalizers
		local len = #finalizers
		local n = select("#", ...)
		for i = 1, n do
			const fn = select(i, ...)
			if type(fn) == types["function"] then
				len = len + 1
				finalizers[len] = fn
			end
		end
	end, mtypes.never, private.type, mtypes.anyt, ftype:var(types["function"])),
})

do
	type group = {
		active: boolean,
		finalizers: { (string) -> () },
		tokens: { userdata },
	}

	private.groups = setmetatable({}, tables.__mode_ks) :: { [userdata]: group }
	private.gcheap = {} :: { userdata }
	private.gcclean = {} :: { number }
	private.gckill = {} :: { [number]: boolean }
	private.watched = setmetatable({}, tables.__mode_vs) :: { [userdata]: luaobject }

	private.ids = {} :: { [userdata]: string }
	private.owner_of = {} :: { [userdata]: userdata }

	private.cursor_idx = 0 :: number
	private.pass_size = 0 :: number

	const FRAME_BUDGET = --[[#GCCYCLE_FRAME_BUDGET]] --[[#ifdef GCCYCLE_FRAME_BUDGET]] --[[#lua_OR]] --[[#endif]] 0.0025
	const TIME_CHECK_INTERVAL = --[[#GCCYCLE_TIME_CHECK_INTERVAL]] --[[#ifdef GCCYCLE_TIME_CHECK_INTERVAL]] --[[#lua_OR]] --[[#endif]] 8
	const MAX_ITEMS_PER_FRAME = --[[#GCCYCLE_MAX_ITEMS_PER_FRAME]] --[[#ifdef GCCYCLE_MAX_ITEMS_PER_FRAME]] --[[#lua_OR]] --[[#endif]] 512
	

	private.track = function(pointer: userdata, obj: luaobject): userdata
		const token = newproxy()

		private.watched[token] = obj
		private.owner_of[token] = pointer

		local id = ""
		if LuaObject:that(obj, LuaObject.type) then
			id = (obj :: any):iden() or ""
		end
		private.ids[token] = id

		private.gcheap[#private.gcheap + 1] = token
		return token
	end

	private.gccall = function(i: number)
		const token = private.gcheap[i]

		if private.watched[token] ~= nil then
			return
		end

		const owner = private.owner_of[token]
		const group = owner and private.groups[owner]

		if group and group.active then
			const finalizers = group.finalizers
			const id = private.ids[token] or ""
			for j = 1, #finalizers do
				pcall(finalizers[j], id)
			end
		end

		private.watched[token] = nil
		private.ids[token] = nil
		private.owner_of[token] = nil
		private.gcclean[#private.gcclean + 1] = i
	end

	private.step = function(): boolean
		const heap = private.gcheap
		const gccall = private.gccall

		if private.cursor_idx == 0 then
			private.cursor_idx = 1
			private.pass_size = #heap
		end

		const deadline = os.clock() + FRAME_BUDGET
		local budget_items = MAX_ITEMS_PER_FRAME
		local steps_since_clock = 0

		while private.cursor_idx <= private.pass_size and budget_items > 0 do
			gccall(private.cursor_idx)
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
		const clean = private.gcclean

		for k = 1, #clean do
			kill[clean[k]] = true
		end

		const n = #heap
		local write = 1
		for read = 1, n do
			const token = heap[read]
			if not kill[read] then
				heap[write] = token
				write = write + 1
			end
		end
		for k = n, write, -1 do
			heap[k] = nil
		end

		table.clear(clean)
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
end

return class
