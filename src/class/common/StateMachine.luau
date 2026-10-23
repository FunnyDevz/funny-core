--!strict
const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const StateMachineNotification = require("@enums/notification/StateMachineNotification")
const Cryptography = require("@import/Cryptography")
const ftype = require("@static/ftype")


const private = {}
const class: statemachine = (Observer :: observer<enumitem_statemachine_notification>):new {
	type = "statemachine",

	get_state = ftype:write(function (self: statemachine, ...:enumitem) : boolean
		const list = private.worklist(self)
		
		for _, v in {...} do
			if not list[v] then
				return false
			end
		end

		return true
	end, types.boolean, "statemachine", ftype:var(EnumItem.type)),

	set_state = ftype:write(function (self: statemachine, to: boolean?, ...: enumitem) : ()
		const list = private.worklist(self)
		const blacklist = private.blacklist(self)

		for _, v in {...} do
			if table.find(blacklist, v) then continue end
			
			const reserved = list[v]
			if reserved == to then continue end

			list[v] = to

			if reserved == nil then
				self:notificate(StateMachineNotification.NewState, v)
			else
				self:notificate(StateMachineNotification.ChangedState, v)
			end
		end
	end, mtypes.never, "statemachine", ftype:opt(types.boolean), ftype:var(EnumItem.type)),

	blacklist = ftype:write(function (self: statemachine, ...: enumitem) : ()
		const blacklist = private.blacklist(self)

		for _, v in {...} do
			const pos = table.find(blacklist, v)

			if pos then
				table.remove(blacklist, pos)
				self:notificate(StateMachineNotification.BlacklistRemoved, v)
			else
				table.insert(blacklist, v)
				self:notificate(StateMachineNotification.BlacklistAdded, v)
			end
		end
	end, mtypes.never, "statemachine", ftype:var(EnumItem.type)),
}

class:host(function(new)
	const new = new:as <<statemachine>> (class.type)

	new:set(private.key, setmetatable({}, tables.__mode_ks))
	new:set(private.key2, setmetatable({}, tables.__mode_vs))
end)

do

	private.key = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "states_key")
	private.key2 = Cryptography.Hashing.SHA2.SHA256(buffer.fromstring "states_blacklist_key")

	private.worklist = function (of: statemachine)
		return of:get <<{[enumitem]: boolean?}>> (private.key)
	end

	private.blacklist = function (of: statemachine)
		return of:get <<{enumitem}>>(private.key2)
	end
end

return class