--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const std = require("@extension/std")
const ftype = require("@static/ftype")

const private = {type = "value"}
const class: value = (Observer :: observer<enumitem_operation_variant>):new({
	type = private.type,

	get_value = ftype:write(function(self: value): any
		const value: any = private.values[self]
		if value ~= nil then
			return value
		else
			const default = private.defaults[self]
			if default then
				return default
			end
		end

		return nil
	end, mtypes.anyt, private.type),

	set_value = ftype:write(function(self: value, value: any, default: boolean?): ()
		const stored: any = private.values[self]

		if default then
			private.defaults[self] = value
		else
			private.values[self] = value
		end

		if stored == nil then
			self:notificate(OperationVariant.New)
		elseif stored ~= value then
			self:notificate(OperationVariant.Change)
		elseif value == nil then
			self:notificate(OperationVariant.Remove)
		--#if VALUE_PRINT_ACT
		else
			std:outw("unexpected value behaviour, skip")
		--#endif
		end

	end, mtypes.never, private.type, mtypes.anyt, ftype:opt(types.boolean)),
})

do
	private.meta = tables.__mode_ks
	private.values = setmetatable({} :: { [value]: any }, private.meta)
	private.defaults = setmetatable({} :: { [value]: any }, private.meta)
end

return class
