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
const ftype = require("@static/ftype")

type queue_state = {
	head: number,
	tail: number,
	items: { any },
}

const private = {type = "queue"}
const class: queue = LuaObject:new({
	type = private.type,
	max = 10000,

	pick = ftype:write(function<T>(self: queue): T?
		const state = private.get_state(self)

		if state.head > state.tail then
			return nil
		end

		const value = state.items[state.head]
		state.items[state.head] = nil
		state.head += 1

		private.normalize(state)

		return value
	end, ftype:opt(mtypes.anyt), private.type),

	put = ftype:write(function<T>(self: queue, value: T): ()
		const state = private.get_state(self)

		-- nil is not stored, otherwise the head/tail window counts a hole as an item
		if value == nil then
			return
		end

		if not std:check(state.tail - state.head + 1 < self.max, "queue limit capacity reached") then
			return
		end

		state.tail += 1
		state.items[state.tail] = value
	end, mtypes.never, private.type, mtypes.anyt),

	count = ftype:write(function(self: queue): number
		const state = private.get_state(self)

		return math.max(state.tail - state.head + 1, 0)
	end, types.number, private.type),
})

do
	private.states = setmetatable({} :: { [queue]: queue_state }, tables.__mode_ks)
	private.compact_threshold = 1024

	private.new_state = function(): queue_state
		return {
			head = 1,
			tail = 0,
			items = {},
		}
	end

	private.new = function (new: luaobject)
		const new = new:as<<queue>>(class.type)
		private.states[new] = private.new_state()
	end

	private.normalize = function(state: queue_state): ()
		if state.head > state.tail then
			state.head = 1
			state.tail = 0
			table.clear(state.items)
		elseif state.head > private.compact_threshold then
			const items: { any } = {}

			table.move(state.items, state.head, state.tail, 1, items)

			state.items = items
			state.tail = state.tail - state.head + 1
			state.head = 1
		end
	end

	private.get_state = function(of: queue): queue_state
		local state = private.states[of]

		if state == nil then
			state = private.new_state()
			private.states[of] = state
		end

		return state
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif
end

class:host(private.new)

return class
