--!strict
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const BinderNotification = require("@enums/notification/BinderNotification")
const stdout = require("@extension/stdout")
const datamodel = require("@platform/roblox/datamodel")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

const private = {}
const class: binder = (Observer :: observer<enumitem_binder_notification>):new({
	type = "binder",
	tag = "",
	maker = nil :: any,
	ancestors = nil :: { Instance }?,

	start = ftype:write(function(self: binder): ()
		if private.connections[self] or self.tag == "" then
			return
		end

		private.connections[self] = {
			datamodel.on_tag_added(self.tag, function(instance)
				private.watch(self, instance)
			end),
			datamodel.on_tag_removed(self.tag, function(instance)
				private.forget(self, instance)
			end),
		}

		for k, v in datamodel.get_tagged(self.tag) do
			private.watch(self, v)
		end
	end, mtypes.never, "binder"),

	stop = ftype:write(function(self: binder): ()
		const connections = private.connections[self]

		if not connections then
			return
		end

		private.connections[self] = nil

		for k, v in connections do
			v:Disconnect()
		end

		for k in table.clone(private.watching[self]) do
			private.forget(self, k)
		end
	end, mtypes.never, "binder"),

	is_started = ftype:write(function(self: binder): boolean
		return private.connections[self] ~= nil
	end, types.boolean, "binder"),

	get_object = ftype:write(function(self: binder, instance: Instance): any
		return private.bound[self][instance]
	end, ftype:opt(mtypes.anyt), "binder", rbxtypes.Instance),

	get_objects = ftype:write(function(self: binder): { [Instance]: any }
		return table.clone(private.bound[self])
	end, types.table, "binder"),
})

class:host(function(new)
	const new = new:as <<binder>> (class.type)

	-- Наследники получают копии, а не ссылки
	if (type(new.ancestors) == types.table) then
		new.ancestors = table.clone(new.ancestors)
	end

	private.bound[new] = {}
	private.watching[new] = {}
end)

do
	private.frozen = tables.__mode_ks
	private.bound = setmetatable({} :: { [binder]: { [Instance]: any } }, private.frozen)
	private.watching = setmetatable({} :: { [binder]: { [Instance]: RBXScriptConnection } }, private.frozen)
	private.connections = setmetatable({} :: { [binder]: { RBXScriptConnection } }, private.frozen)

	function private.watch(that: binder, instance: Instance)
		const watching = private.watching[that]

		if watching[instance] then
			return
		end

		watching[instance] = datamodel.on_ancestry_changed(instance, function()
			private.update(that, instance)
		end)

		private.update(that, instance)
	end

	function private.forget(that: binder, instance: Instance)
		const watching = private.watching[that]
		const connection = watching[instance]

		if connection then
			connection:Disconnect()
			watching[instance] = nil
		end

		private.unbind(that, instance)
	end

	function private.update(that: binder, instance: Instance)
		const allowed = datamodel.is_inside(instance, that.ancestors)
		const bound = private.bound[that][instance] ~= nil

		if allowed and not bound then
			private.bind(that, instance)
		elseif not allowed and bound then
			private.unbind(that, instance)
		end
	end

	function private.make(that: binder, instance: Instance): any
		const maker = that.maker :: any

		if type(maker) == types["function"] then
			return maker(instance)
		end

		const made = maker:new()
		if type(made) == types.table and type(made.set_instance) == types["function"] then
			made:set_instance(instance)
		end

		return made
	end

	function private.bind(that: binder, instance: Instance)
		const succ, result = pcall(private.make, that, instance)

		if not succ then
			stdout:outw(`binder "{that.tag}" cannot bind {instance:GetFullName()}:`, result)
			return
		end

		if result == nil then return end

		private.bound[that][instance] = result
		that:notificate(BinderNotification.Bound, instance, result)
	end

	function private.unbind(that: binder, instance: Instance)
		const bound = private.bound[that]
		const value = bound[instance]

		if value == nil then
			return
		end

		bound[instance] = nil
		that:notificate(BinderNotification.Unbound, instance, value)

		const it = value :: any
		if type(it) == types.table and type(it.is) == types["function"] and it:is("disposable") and not it:released() then
			it:free()
		end
	end
end

return class
