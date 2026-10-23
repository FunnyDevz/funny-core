--!strict
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const ReferenceNotification = require("@enums/notification/ReferenceNotification")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ftype = require("@static/ftype")

const private = {}
const class: reference = Observer:new({
	type = "reference",

	get_instance = ftype:write(function(self: reference): any?
		return private.stored[self]
	end, ftype:opt(mtypes.anyt), "reference"),

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
	end, mtypes.never, "reference", ftype:uor(rbxtypes.Instance, mtypes.anyt)),

	is_instance_exists = ftype:write(function(self: reference): boolean
		return typeof(self:get_instance()) == "Instance"
	end, types.boolean, "reference"),

	clear = ftype:write(function(self: reference): ()
		const instance = self:get_instance()
		if instance and type(instance) == rbxtypes.Instance then
			const rbx_instance = instance :: Instance
			rbx_instance:Destroy()
		end

		self:set_instance(nil :: any)
	end, mtypes.never, "reference"),
})

do
	private.frozen = tables.__mode_ks
	private.stored = setmetatable({} :: { [reference]: Instance }, private.frozen)
	private.connections = setmetatable({} :: { [reference]: RBXScriptConnection }, private.frozen)
end

return class
