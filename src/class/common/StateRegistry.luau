--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const EnumItem = require("@class/core/EnumItem")
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const StateMachineNotification = require("@enums/notification/StateMachineNotification")
const ftype = require("@static/ftype")


const private = {type = "stateregistry"}
const class: stateregistry = (Observer :: observer<enumitem_statemachine_notification>):new {
	type = private.type,

	get_state = ftype:write(function (self: stateregistry, ...:enumitem) : boolean
		const list = private.worklist(self)
		
		for _, v in {...} do
			if not list[v] then
				return false
			end
		end

		return true
	end, types.boolean, private.type, ftype:var(EnumItem.type)),

	set_state = ftype:write(function (self: stateregistry, to: boolean?, ...: enumitem) : ()
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
	end, mtypes.never, private.type, ftype:opt(types.boolean), ftype:var(EnumItem.type)),

	blacklist = ftype:write(function (self: stateregistry, ...: enumitem) : ()
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
	end, mtypes.never, private.type, ftype:var(EnumItem.type)),
}

class:host(function(new)
	const new = new:as <<stateregistry>> (class.type)

	new:set(private.key, setmetatable({}, tables.__mode_ks))
	new:set(private.key2, setmetatable({}, tables.__mode_vs))
end)

do

	private.key = newproxy()
	private.key2 = newproxy()

	private.worklist = function (of: stateregistry)
		return of:get <<{[enumitem]: boolean?}>> (private.key)
	end

	private.blacklist = function (of: stateregistry)
		return of:get <<{enumitem}>>(private.key2)
	end
end

return class