--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const LuaObject = require("@class/core/LuaObject")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const std = require("@extension/std")
const ftype = require("@static/ftype")

type quantity = any

const private = { type = "kinematiccontroller" }
const class: kinematiccontroller = LuaObject:new({
	type = private.type,
	proportional = 1,
	output_limit = math.huge,

	apply_error = ftype:write(function(self: kinematiccontroller, error: quantity, delta: number): quantity
		return private.compute(self, error, nil, delta)
	end, ftype:uor(types.number, types.vector), private.type, ftype:uor(types.number, types.vector), types.number),

	apply_measurement = ftype:write(
		function(self: kinematiccontroller, setpoint: quantity, measurement: quantity, delta: number): quantity
			if not std:check(type(setpoint) == type(measurement), "setpoint and measurement must share a type") then
				return private.compute(self, setpoint, nil, delta)
			end

			return private.compute(self, setpoint - measurement, measurement, delta)
		end,

		ftype:uor(types.number, types.vector),
		private.type,
		ftype:uor(types.number, types.vector),
		ftype:uor(types.number, types.vector),
		types.number
	),

	get_output = ftype:write(function(self: kinematiccontroller): quantity?
		return private.get_state(self).output
	end, ftype:or_opt(types.number, types.vector), private.type),

	get_error = ftype:write(function(self: kinematiccontroller): quantity?
		return private.get_state(self).error
	end, ftype:or_opt(types.number, types.vector), private.type),

	reset = ftype:write(function(self: kinematiccontroller): ()
		private.states[self] = private.new_state()
	end, mtypes.never, private.type),
})

do
	type state = {
		error: quantity?,
		output: quantity?,
		measurement: quantity?,
		integral: quantity?,
	}

	type operations = {
		read zero: quantity,
		read clamp: (value: quantity, limit: number) -> quantity,
	}

	type related = {
		read error: quantity,
		read measurement: quantity?,
		read delta: number,
		read operations: operations,
	}

	type term = (self: kinematiccontroller, state: state, related: related) -> quantity

	private.meta = tables.__mode_ks
	private.states = setmetatable({} :: { [kinematiccontroller]: state }, private.meta)
	private.new_state = function(): state return {} end
	private.new = function (new: luaobject)
		const new = new:as<<kinematiccontroller>>(class.type)
		private.states[new] = private.new_state()
	end

	--#if ALL_CLASS_USEABLE
	private.new(class)
	--#endif

	private.get_state = function(of: kinematiccontroller): state
		const state = private.states[of]

		if state then
			return state
		end

		const new = private.new_state()
		private.states[of] = new
		return new
	end

	private.get_gain = function(of: kinematiccontroller, name: string): number
		const gain = (of :: any)[name]
		return if type(gain) == types.number then gain else 0
	end

	private.relevant_operations = table.freeze({
		[types.number] = table.freeze({
			zero = 0,
			clamp = function(value: number, limit: number): number
				return math.clamp(value, -limit, limit)
			end,
		}),

		[types.vector] = table.freeze({
			zero = vector.zero,
			clamp = function(value: vector, limit: number): vector
				const magnitude = vector.magnitude(value)

				if magnitude > limit and magnitude > 0 then
					return value * (limit / magnitude)
				end

				return value
			end,
		}),
	}) :: { read [string]: operations }

	private.terms = table.freeze({
		function(self: kinematiccontroller, state: state, related: related): quantity
			return related.error * self.proportional
		end,

		function(self: kinematiccontroller, state: state, related: related): quantity
			const gain = private.get_gain(self, "integral")

			if gain == 0 then
				state.integral = nil
				return related.operations.zero
			end

			const limit = (self :: any).integral_limit
			const accumulated = (state.integral or related.operations.zero) + related.error * related.delta
			state.integral = related.operations.clamp(accumulated, if type(limit) == types.number then limit else math.huge)

			return state.integral * gain
		end,

		function(self: kinematiccontroller, state: state, related: related): quantity
			const gain = private.get_gain(self, "derivative")

			if gain == 0 or related.delta <= 0 then
				return related.operations.zero
			end

			if related.measurement ~= nil then
				if state.measurement == nil then
					return related.operations.zero
				end

				return (state.measurement - related.measurement) / related.delta * gain
			end

			if state.error == nil then
				return related.operations.zero
			end

			return (related.error - state.error) / related.delta * gain
		end,
	}) :: { term }

	private.compute = function(self: kinematiccontroller, error: quantity, measurement: quantity?, delta: number): quantity
		const operations = private.relevant_operations[type(error)]

		if not std:check(operations, `unsupported kinematic quantity {type(error)}`) then
			return error
		end

		local state = private.get_state(self)

		if state.error ~= nil and type(state.error) ~= type(error) then
			state = private.new_state()
			private.states[self] = state
		end

		if (state.measurement == nil) ~= (measurement == nil) then
			state.measurement = nil
			state.error = nil
		end

		const related: related = table.freeze({
			error = error,
			measurement = measurement,
			delta = if delta == delta and delta > 0 then delta else 0,
			operations = operations,
		})

		local output = operations.zero

		for k, v in private.terms do
			output += v(self, state, related)
		end

		output = operations.clamp(output, self.output_limit)

		state.error = error
		state.measurement = measurement
		state.output = output

		return output
	end
end

class:host(private.new)

return class
