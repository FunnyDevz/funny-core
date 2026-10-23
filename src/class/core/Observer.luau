--!strict
const EnumItem = require("@class/core/EnumItem")
const EnumObject = require("@class/core/EnumObject")
const Pointer = require("@class/core/Pointer")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const LuaObject = require("@class/core/LuaObject")
const dummies = require("@declare/dummies")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const stderr = require("@extension/stderr")
const stdout = require("@extension/stdout")
const global = require("@project/global")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

type observer_on<T = enumitem> = T | { T } | enumobject | { enumobject } | { T | enumobject }
type observer_var<T = unknown> = ((...any) -> ()) | thread | observer<T>

const private = {}
const class: observer = LuaObject:new({
	type = "observer",
	deffered_call = true,
	deffered_mode = false,
	allow_new_connections = true,

	subscribe = ftype:write(
		function(self: observer, on: observer_on, mode: enumitem_connection_variant, ...: observer_var): ...pointer
			if not self.allow_new_connections then
				const empty_pointers: {pointer} = {}

				for i = 1, #{...} do
					empty_pointers[i] = Pointer:new()
				end

				return table.unpack(empty_pointers)
			end

			if (not stderr:check(private.relevant_actions[mode], `subscription option of {mode.name} does not exists`)) then return end

			const flat = private.create_flatted_on(on)
			const items = private.get_items(self)
			const result: { pointer } = {}
			const pointers = private.get_pointers(self)

			for _, v in flat do
				const internal_mode_layer = private.get_work_of(items, v)
				const target_mode = private.get_mode(internal_mode_layer, mode)

				for _, v in { ... } do
					table.insert(target_mode, v)

					const new_pointer = Pointer:new()
					new_pointer:set_point(v, true)

					pointers[new_pointer] = { work_list = target_mode, mode_list = internal_mode_layer }
					table.insert(result, new_pointer)
				end
			end

			return unpack(result)
		end,
		ftype:var("pointer"),
		"observer",
		ftype:uor("enumitem", "enumobject", types.table),
		"enumitem",
		ftype:var_or("observer", types["function"], types.thread)
	),

	unsubscribe = ftype:write(function(self: observer, ...: pointer): ()
		const pointers = private.get_pointers(self)

		for _, v in { ... } do
			const pointer = pointers[v]

			if pointer and v:is_pointed_exists() then
				const pos = table.find(pointer.work_list :: any, v:get_pointed())
				if pos then
					table.remove(pointer.work_list, pos)
				end
			end

			pointers[v] = nil
		end
	end, mtypes.never, "observer", ftype:var("pointer")),

	notificate = ftype:write(function(self: observer, on: observer_on, ...: unknown): ()
		const items = private.get_items(self)

		if self.deffered_mode and coroutine.isyieldable() then
			task.defer(coroutine.running())
			coroutine.yield()
		end

		for _, enumitem in private.create_flatted_on(on) do
			if const dispatch_layer = items[enumitem] then
				for i, observer_connections_list in table.clone(dispatch_layer) do
					const delta_list = observer_connections_list
					const related = private.generate_related(self, enumitem, delta_list)
					const result = private.relevant_actions[i](related, ...)

					if #result == #delta_list then
						table.clear(delta_list)
					else
						for _, v in result do
							table.remove(delta_list, table.find(delta_list, v) or 0)
						end
					end
				end
			end
		end
	end, mtypes.never, "observer", ftype:uor("enumitem", "enumobject", types.table), ftype:var(mtypes.anyt)),

	subscription_set_mode = ftype:write(function(self: observer, operation: enumitem_connection_variant, ...: pointer): ()
		const pointers = private.get_pointers(self)

		for _, v in { ... } do
			const pointer = pointers[v]

			if pointer then
				private.relevant_pointer_setting[operation](pointer, v)
			end
		end
	end, mtypes.never, "observer", "enumitem", ftype:var("pointer")),

	subscription_get_mode = ftype:write(function(self: observer, ...: pointer): ...enumitem_connection_variant
		const pointers = private.get_pointers(self)
		const packed: { enumitem_connection_variant } = {}

		for _, v in { ... } do
			const pointer = pointers[v]

			if pointer then
				for i, j in pointer.mode_list do
					if j == pointer.work_list then
						table.insert(packed, i)
					end
				end
			end
		end

		return unpack(packed)
	end, ftype:var("enumitem"), "observer", ftype:var("pointer")),

    get = function <Y> (self: observer, label: unknown) : Y
        return private.shadow_space[self][label]
    end,

    set = function <Y> (self: observer, label: unknown, to: Y) : ()
        private.shadow_space[self][label] = to
    end 
})

class:host(function(new)
	const new = new:as <<observer>> (class.type)

    private.shadow_space[new] = {}

	new:set(private.pointers, setmetatable({}, private.meta))
	new:set(private.items, {})
end)

do
	type flatted = { [enumitem]: flatted_dependency }
	type work_list = { observer_var }
	type flatted_dependency = { [enumitem_connection_variant]: work_list }
	type pointer_internal = {
		work_list: work_list,
		read mode_list: flatted_dependency,
	}
	type pointers = { [pointer]: pointer_internal? }
	type related = {
		read notification_of: enumitem<any>,
		read work_list: work_list,
		read of: observer,
	}

	private.dummy = dummies.table
	private.meta = tables.__mode_ks
	private.shadow_space = setmetatable({} :: {[observer]: {[any]: any}}, private.meta)
	private.pointers = newproxy()
	private.items = newproxy()

	private.create_flatted_on = function(on: observer_on<any>): { enumitem }
		const output_for_cycle = {}

		if class:that(on, EnumItem.type) then
			const on_enumitem = on :: enumitem

			table.insert(output_for_cycle, on_enumitem)
		elseif class:that(on, EnumObject.type) then
			const on_enumobject = on :: enumobject
			const list_of_items = on_enumobject:get_enums_list()
			const list_of_related = private.create_flatted_on(list_of_items)

			table.move(list_of_related, 1, #list_of_related, #output_for_cycle + 1, output_for_cycle)
		elseif type(on) == types.table then
			const on_list = on :: { enumitem | enumobject }

			for _, v in on_list do
				const flat = private.create_flatted_on(v)
				table.move(flat, 1, #flat, #output_for_cycle + 1, output_for_cycle)
			end
		else
			stdout:oute("unknown CallType")
		end

		return output_for_cycle
	end

	private.get_pointers = function(of: observer): pointers
		return (of:get(private.pointers) or private.dummy) :: any
	end

	private.get_items = function(of: observer): flatted
		return (of:get(private.items) or private.dummy) :: any
	end

	private.get_mode = function(of: flatted_dependency, mode: enumitem_connection_variant)
		if not of[mode] then
			of[mode] = {}
		end

		return of[mode]
	end

	private.get_work_of = function(of: flatted, item: enumitem): flatted_dependency
		if not of[item] then
			of[item] = {}
		end

		return of[item]
	end

	private.generate_related = function(of: observer, item: enumitem<any>, list: work_list): related
		return table.freeze({
			notification_of = item,
			of = of,
			work_list = list,
		})
	end

	private.call = function(v: observer_var, related: related, ...): boolean
		const T = type(v)

		if related.of.deffered_call and coroutine.isyieldable() then
			task.defer(coroutine.resume, coroutine.running())
			coroutine.yield()
		end

		if T == types["function"] then
			const var_func = v :: (...any) -> any
			const out, msg = pcall(var_func, ...)
			const res = stderr:assert(out, `{tostring(msg)}`)
			return res
		elseif T == types.thread then
			const var_thread = v :: thread
			const out, msg = coroutine.resume(var_thread, ...)
			const res = stderr:assert(out, `{tostring(msg)}`)
			return res
		elseif class:that(v, class.type) then
			const var_observer = v :: observer
			var_observer:notificate(related.notification_of, ...)
		else
			stdout:oute("unexpected connection, skip")
			return false
		end

		return true
	end

	private.move_actions_to_mode = function(target: enumitem_connection_variant, related: related, ...)
		const dispatch_layer = private.get_work_of(private.get_items(related.of), related.notification_of)
		const target_layer = private.get_mode(dispatch_layer, target)
		const pointers = private.get_pointers(related.of)

		for _, v in pointers do
			if v.work_list == related.work_list then
				v.work_list = target_layer
			end
		end

		table.move(related.work_list, 1, #related.work_list, #target_layer + 1, target_layer)
		table.clear(related.work_list)
		dispatch_layer[target] = target_layer

		return private.dummy
	end

	private.relevant_actions = table.freeze({
		[ConnectionVariant.Ever] = function(related: related, ...)
			const result = {}

			for i, v in table.clone(related.work_list) do
				if not private.call(v, related, ...) then
					table.insert(result, v)
				end
			end

			return result
		end,

		[ConnectionVariant.Once] = function(related: related, ...)
			const result = {}

			for i, v in table.clone(related.work_list) do
				private.call(v, related, ...)
				table.insert(result, v)
			end

			return result
		end,

		[ConnectionVariant.Next] = function(related: related, ...)
			return private.move_actions_to_mode(ConnectionVariant.Ever, related, ...)
		end,

		[ConnectionVariant.Skip] = function(related: related, ...)
			return private.move_actions_to_mode(ConnectionVariant.Once, related, ...)
		end,

        -- reserved
		[ConnectionVariant.Hold] = function(related: related, ...)
			return private.dummy
		end,
	}) :: { [enumitem_connection_variant]: (work: related, ...unknown) -> { observer_var<any> } }

	private.move_pointed = function(
		work: pointer_internal,
		pointer: pointer<observer_var>,
		mode: enumitem_connection_variant
	)
		const target_list = work.mode_list[mode] or {}

		if work.work_list ~= target_list then
			--#if DEBUG
			if not pointer:is_pointed_exists() then
				if global.debug then
					stdout:oute("pointer does not exist?")
				end
			end
			--#endif

			const pointed = pointer:get_pointed()
			table.remove(work.work_list, table.find(work.work_list, pointed) or 0)
			table.insert(target_list, pointed)
			work.work_list = target_list
		end

		work.mode_list[mode] = target_list
	end

	private.relevant_pointer_setting =
		table.freeze({
			[ConnectionVariant.Ever] = function(work: pointer_internal, pointer: pointer<any>)
				private.move_pointed(work, pointer, ConnectionVariant.Ever)
			end,

			[ConnectionVariant.Next] = function(work: pointer_internal, pointer: pointer<any>)
				private.move_pointed(work, pointer, ConnectionVariant.Next)
			end,

			[ConnectionVariant.Once] = function(work: pointer_internal, pointer: pointer<any>)
				private.move_pointed(work, pointer, ConnectionVariant.Once)
			end,

			[ConnectionVariant.Skip] = function(work: pointer_internal, pointer: pointer<any>)
				private.move_pointed(work, pointer, ConnectionVariant.Skip)
			end,
		}) :: { [enumitem_connection_variant]: (work: pointer_internal, pointer: pointer) -> () }
end

ctype:read(class):write_tag(ctags.core)

return class
