--!strict
const Observer = require("@game/ReplicatedStorage/class/core/Observer")
const SecurityRNG = require("@game/ReplicatedStorage/class/service/SecurityRNG")
const StateMachineNotification = require("@game/ReplicatedStorage/enums/notification/StateMachineNotification")
const declare = require("@game/ReplicatedStorage/static/declare")

const private = {}
const class: statemachine = (Observer :: observer<enumitem_statemachine_notification>):new {
	type = "statemachine",

	get_state = function (self: statemachine, ...:enumitem) : boolean
		const list = private.worklist(self)
		
		for _, v in {...} do
			if not list[v] then
				return false
			end
		end

		return true
	end,

	set_state = function (self: statemachine, to: boolean?, ...: enumitem) : ()
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
	end,

	blacklist = function (self: statemachine, ...: enumitem) : ()
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
	end,
}

class:host(function(new)
	const new = new:as <<statemachine>> (class.type)

	new:set(private.key, setmetatable({}, declare.tables.__mode_ks))
	new:set(private.key2, setmetatable({}, declare.tables.__mode_vs))
end)

do

	private.key = SecurityRNG:get_hash_blake3("states_key")
	private.key2 = SecurityRNG:get_hash_blake3("states_blacklist_key")

	private.worklist = function (of: statemachine)
		return of:get <<{[enumitem]: boolean?}>> (private.key)
	end

	private.blacklist = function (of: statemachine)
		return of:get <<{enumitem}>>(private.key2)
	end
end

return class