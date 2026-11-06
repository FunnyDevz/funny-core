--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Reference = require("@class/common/Reference")
const Connection = require("@class/common/signal/Connection")
const Event = require("@class/common/signal/Event")
const Disposable = require("@class/core/Disposable")
const LuaObject = require("@class/core/LuaObject")
const Path = require("@class/core/Path")
const mtypes = require("@declare/mtypes")
const types = require("@declare/types")
const ttable = require("@extension/ttable")
const rbxtypes = require("@platform/roblox/rbxtypes")
const mtluaobject = require("@project/mtluaobject")
const ftype = require("@static/ftype")

const private = {type = "maid"}
const class: maid = Disposable:new {
	type = private.type,

	clear = ftype:write(function (self: maid) : ()
		const list = private.get(self)
	
		if not table.isfrozen(list) then
			table.clear(list)
		end
	end, mtypes.never, private.type),

	count = ftype:write(function (self: maid) : number
		return #private.get(self)
	end, types.number, private.type),

	length = ftype:write(function (self: maid) : number
		return ttable.length(private.get(self))
	end, types.number, private.type),

	-- this feature is available only because the interface obliges
	adjust = ftype:write(function (self: maid, to: number) : ()
		const list = private.get(self)
		
		if table.isfrozen(list) then
			return
		end

		if math.abs(to) ~= to then
			table.remove(list, to)
		else
			for i = 1, to do
				table.remove(list, i)
			end
		end
	end, mtypes.never, private.type, types.number),

	insert = ftype:write(function (self: maid, ...) : ()
		const list = private.get(self)
		if not table.isfrozen(list) then
			const need = {...}

			for i = 1, #need do
				table.insert(list, need[i])
			end
		end
	end, mtypes.never, private.type, ftype:var_or(rbxtypes.Instance, Disposable.type, Reference.type, Path.type)),

	remove = ftype:write(function (self: maid, ...) : ()
		const list = private.get(self)
		
		if not table.isfrozen(list) then
			const need = {...}

			for i = 1, #need do
				table.remove(list, table.find(list, need[i]) or 0)
			end
		end
	end, mtypes.never, private.type, ftype:var_or(rbxtypes.Instance, Disposable.type, Reference.type, Path.type)),

	collect = ftype:write(function (self: maid, utype: string) : ...any
		const list = private.get(self)

		for _, v: any in list do
			const TT = typeof(v)

			if rbxtypes:is_rbx_type(TT) then
				if TT == rbxtypes.Instance then
					const that = v :: Instance
					if that.ClassName == utype then
						return that
					end
				elseif TT == utype then
					return v
				end
			elseif TT == mtluaobject.luaobject_type then
				if LuaObject.is(v, LuaObject.type) then
					if LuaObject.is(v, utype) then
						return v
					end
				end
			end
		end
	end, ftype:var(mtypes.anyt), private.type, types.string),

	find = ftype:write(function (self: maid, ...) : ...boolean
		const list = private.get(self)
		const is: {boolean} = {}
		const need = {...}

		for i = 1, #need do
			is[i] = table.find(list, need[i]) ~= nil
		end

		return table.unpack(is)
	end, ftype:var(types.boolean), private.type, ftype:var_opt(mtypes.anyt))
}

do
	private.everyone = newproxy()

	private.new = function (new: luaobject) : ()
		const new = new:as <<maid>> (class.type)
		const closure = {}

		new:set(private.everyone, closure)
		new:finally(function (id)
			private.clean(closure)
		end)
	end

	private.get = function (of: maid) : {unknown}
		return of:get <<{unknown}>> (private.everyone)
	end

	private.clean = function (tbl: {unknown}) : ()
		for _, v: any in tbl do
			const TT = typeof(v)
			
			if TT == rbxtypes.Instance then
				const that_instance = v  :: Instance
				that_instance:Destroy()
			elseif TT == rbxtypes.RBXScriptConnection then
				const that_connection = v :: RBXScriptConnection
				that_connection:Disconnect()
			elseif TT == mtluaobject.luaobject_type then
				if class.is(v, LuaObject.type) then
					if class.is(v, Disposable.type) then
						const that_disposable = v :: disposable
						that_disposable:free()
					elseif class.is(v, Reference.type) then
						const that_reference = v :: reference
						const value_referenced = that_reference:get_instance()
						private.clean({ value_referenced })
					elseif class.is(v, Path.type) then
						const that_path = v :: path
						const value = that_path:get_by_path_or_nil()
						private.clean({value})
					elseif class.is(v, Connection.type) then
						const that_connection = v :: connection
						that_connection:disconnect()
					elseif class.is(v, Event.type) then
						const that_event = v :: event
						that_event:disconnect_all_connections()
					end
				end
			end
		end

		if not table.isfrozen(tbl) then
			table.clear(tbl)
		end
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif
end

class:host(private.new)

return class
