--!strict
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ReferenceNotification = require("@enums/notification/ReferenceNotification")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")
const utypes = require("@declare/utypes")

const private = {type = "reference"}
const class: reference = (Observer :: observer<enumitem_reference_notification>):new({
	type = private.type,

	call_function = ftype:write(function (self: reference, name: any, ...: any) : ...any
		if not self:is_instance_exists() then return nil end
		
		const status, result = pcall(function (...)
			const instance = self:get_instance() ::any
			return {instance[name](...)}
		end, ...)

		return status and table.unpack(result) or nil
	end, ftype:var_opt(mtypes.anyt), private.type, mtypes.anyt, ftype:var_opt(mtypes.anyt)),

	call_methode = ftype:write(function (self: reference, name: any, ...: any) : ...any
		return self:call_function(name, self:get_instance(), ...)
	end, ftype:var_opt(mtypes.anyt), private.type, mtypes.anyt, ftype:var_opt(mtypes.anyt)),

	read_field = ftype:write(function(self: reference, name: any) : unknown
		if not self:is_instance_exists() then return nil end
		
		const status, result = pcall(function ()
			return (self:get_instance() :: any)[name]
		end)

		return status == true and result or nil
	end, ftype:opt(mtypes.anyt), private.type, mtypes.anyt),

	write_field = ftype:write(function(self: reference, name: any, to: any) : ()
		if self:is_instance_exists() then
			pcall(function ()
				(self:get_instance() :: any)[name] = to
			end)
		end
	end, mtypes.never, private.type, mtypes.anyt, ftype:opt(mtypes.anyt)),

	has_field = ftype:write(function (self: reference, name: any, type: string?) : boolean
		return self:is_instance_exists() and pcall(function ()
			const readed = (self:get_instance() :: any)[name]
			
			if type ~= nil then
				if utypes.utype(readed) == type then
					return true
				else
					return false
				end
			else
				return true
			end
		end) or false
	end, types.boolean, private.type, mtypes.anyt, ftype:opt(types.string)),

	get_instance = ftype:write(function(self: reference): any?
		return private.stored[self]
	end, ftype:opt(mtypes.anyt), private.type),

	set_instance = ftype:write(function(self: reference, to: any): ()
		const stored = private.stored[self]
		const connection = private.connections[self]
		private.stored[self] = to

		if connection then
			connection:Disconnect()
			private.connections[self] = nil
		end

		if typeof(to) == "Instance" then
			const that = to :: Instance

			private.connections[self] = that.Destroying:Once(function()
				self:notificate(ReferenceNotification.DestroyedInstance)
			end)
		end

		if stored == nil and to == nil then
			self:notificate(ReferenceNotification.NullifiedInstance)
		elseif stored == nil and to ~= nil then
			self:notificate(ReferenceNotification.NewInstance)
		elseif stored ~= to then
			self:notificate(ReferenceNotification.ChangedInstance)
		end
	end, mtypes.never, private.type, ftype:uor(rbxtypes.Instance, mtypes.anyt)),

	is_instance_exists = ftype:write(function(self: reference): boolean
		return typeof(self:get_instance()) == rbxtypes.Instance
	end, types.boolean, private.type),

	clear = ftype:write(function(self: reference): ()
		const instance = self:get_instance() :: any

		if instance ~= nil then
			const T = utypes.utype(instance)

			if T == rbxtypes.Instance then
				instance:Destroy()
			elseif T == utypes.luaobject then
				if (self.is(instance, require("@class/core/Disposable").type)) then
					instance:free(true)
				end
			end
		end

		self:set_instance(nil :: any)
	end, mtypes.never, private.type),
})

do
	private.frozen = tables.__mode_ks
	private.stored = setmetatable({} :: { [reference]: Instance }, private.frozen)
	private.connections = setmetatable({} :: { [reference]: RBXScriptConnection }, private.frozen)
end

return class
