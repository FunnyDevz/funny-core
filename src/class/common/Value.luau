--!strict
const Observer = require("@class/core/Observer")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const OperationVariant = require("@enums/descriptor/OperationVariant")
const stdout = require("@extension/stdout")
const ftype = require("@static/ftype")

const private = {}
const class: value = (Observer :: observer<enumitem_operation_variant>):new({
	type = "value",

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
	end, mtypes.anyt, "value"),

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
			stdout:outw("unexpected value behaviour, skip")
		--#endif
		end

	end, mtypes.never, "value", mtypes.anyt, ftype:opt(types.boolean)),
})

do
	private.meta = tables.__mode_ks
	private.values = setmetatable({} :: { [value]: any }, private.meta)
	private.defaults = setmetatable({} :: { [value]: any }, private.meta)
end

return class
