--!strict

--#include <project.gpp>
--#include <build.gpp>
--#include <fflag_core.gpp>
--#include <fflag.gpp>

const Reference = require("@class/common/Reference")
const Maybe = require("@class/common/gc/Maybe")
const KinematicController = require("@class/common/physics/KinematicController")
const PController = require("@class/common/physics/PController")
const PDController = require("@class/common/physics/PDController")
const PIController = require("@class/common/physics/PIController")
const Disposable = require("@class/core/Disposable")
const mtypes = require("@declare/mtypes")
const tables = require("@declare/tables")
const types = require("@declare/types")
const std = require("@extension/std")
const physics = require("@platform/roblox/physics")
const ftype = require("@static/ftype")
const ReferencePVInstance = require("@templates/class/reference/ReferencePVInstance")

type state = {
	instance: Instance?,
	filter: RaycastParams?,
	look: vector?,
	distance: number?,
	normal: vector,
	grounded: boolean,
	rising: boolean,
}

const private = { type = "entity" }
const class: entity = Disposable:new({
	type = private.type,
	enabled = false,
	up_direction = vector.create(0, 1, 0),
	move_direction = vector.zero,
	jump = false,
	walk_speed = 16,
	jump_power = 50,
	hip_height = 3,
	floor_reach = 1.5,
	auto_rotate = true,
	lock_rotation_x = true,
	lock_rotation_y = true,
	lock_rotation_z = true,

	is_grounded = ftype:write(function(self: entity): boolean
		return private.get_state(self).grounded
	end, types.boolean, private.type),

	get_floor_normal = ftype:write(function(self: entity): vector
		return private.get_state(self).normal
	end, types.vector, private.type),

	get_floor_distance = ftype:write(function(self: entity): number?
		return private.get_state(self).distance
	end, ftype:opt(types.number), private.type),

	get_reference = ftype:write(function(self: entity): reference<PVInstance?>
		return private.maybe_reference:enactment(self, ReferencePVInstance)
	end, Reference.type, private.type),

	get_movement_controller = ftype:write(function(self: entity): kinematiccontroller<vector>
		return self:get <<kinematiccontroller<vector>>> (private.movement_key)
	end, KinematicController.type, private.type),

	get_height_controller = ftype:write(function(self: entity): kinematiccontroller<number>
		return self:get <<kinematiccontroller<number>>> (private.height_key)
	end, KinematicController.type, private.type),

	get_rotation_controller = ftype:write(function(self: entity): kinematiccontroller<vector>
		return self:get <<kinematiccontroller<vector>>> (private.rotation_key)
	end, KinematicController.type, private.type),

	set_movement_controller = ftype:write(function(self: entity, to: kinematiccontroller<vector>): ()
		self:set(private.movement_key, to)
	end, mtypes.never, private.type, KinematicController.type),

	set_height_controller = ftype:write(function(self: entity, to: kinematiccontroller<number>): ()
		self:set(private.height_key, to)
	end, mtypes.never, private.type, KinematicController.type),

	set_rotation_controller = ftype:write(function(self: entity, to: kinematiccontroller<vector>): ()
		self:set(private.rotation_key, to)
	end, mtypes.never, private.type, KinematicController.type),
})

class:host(function(new)
	const new = new:as <<entity>> (class.type)
	private.register(new)
end)

do
	private.epsilon = 1e-6
	private.state_key = newproxy()
	private.movement_key = newproxy()
	private.height_key = newproxy()
	private.rotation_key = newproxy()
	private.entities = setmetatable({} :: { [entity]: true }, tables.__mode_ks)
	private.maybe_reference = Maybe:new() :: maybe<reference<PVInstance?>, entity>

	private.new_state = function(): state
		return {
			normal = class.up_direction,
			grounded = false,
			rising = false,
		}
	end

	private.new_movement = function(): kinematiccontroller<vector>
		return (PIController :: picontroller<vector>):new({
			proportional = 12,
			integral = 1,
			integral_limit = 8,
			output_limit = 250,
		})
	end

	private.new_height = function(): kinematiccontroller<number>
		return (PDController :: pdcontroller<number>):new({
			proportional = 300,
			derivative = 35,
			output_limit = 1000,
		})
	end

	private.new_rotation = function(): kinematiccontroller<vector>
		return (PController :: pcontroller<vector>):new({
			proportional = 12,
			output_limit = 25,
		})
	end

	private.register = function(new: entity)
		new:set(private.state_key, private.new_state())
		new:set(private.movement_key, private.new_movement())
		new:set(private.height_key, private.new_height())
		new:set(private.rotation_key, private.new_rotation())

		private.entities[new] = true
	end

	--#if ALL_CLASS_USEABLE
	private.register(class)
	--#endif

	private.get_state = function(of: entity): state
		return of:get <<state?>> (private.state_key) or private.new_state()
	end

	private.planar = function(of: vector): vector
		const flat = vector.create(of.x, 0, of.z)
		const magnitude = vector.magnitude(flat)

		if magnitude > 1 then
			return flat / magnitude
		end

		return flat
	end

	private.unit = function(of: vector): vector?
		const magnitude = vector.magnitude(of)
		return if magnitude > private.epsilon then of / magnitude else nil
	end

	private.get_tilt = function(up: vector, entity_up: vector): vector
		const axis = vector.cross(up, entity_up)
		const sine = vector.magnitude(axis)

		if sine <= private.epsilon then
			return vector.zero
		end

		return axis / sine * math.atan2(sine, vector.dot(up, entity_up))
	end

	private.get_yaw = function(from: vector?, to: vector?): number
		if not from or not to then
			return 0
		end

		return math.atan2(vector.cross(from, to).y, vector.dot(from, to))
	end

	private.rotate = function(of: entity, state: state, root: BasePart, direction: vector, delta: number)
		if not (of.lock_rotation_x or of.lock_rotation_y or of.lock_rotation_z) then
			return
		end

		const _, up, look = physics.get_axes(root)
		const facing = private.unit(vector.create(look.x, 0, look.z))
		const moving = private.unit(direction)

		if of.auto_rotate and moving then
			state.look = moving
		elseif not of.lock_rotation_y or state.look == nil then
			state.look = facing
		end

		const tilt = private.get_tilt(up, of.up_direction or class.up_direction)
		const error = vector.create(
			if of.lock_rotation_x then tilt.x else 0,
			if of.lock_rotation_y then private.get_yaw(facing, state.look) else 0,
			if of.lock_rotation_z then tilt.z else 0
		)

		const command = of:get_rotation_controller():apply_error(error, delta)
		const angular = physics.get_angular_velocity(root)

		physics.set_angular_velocity(root, vector.create(
			if of.lock_rotation_x then command.x else angular.x,
			if of.lock_rotation_y then command.y else angular.y,
			if of.lock_rotation_z then command.z else angular.z
		))
	end

	private.step = function(of: entity, delta: number)
		const state = private.get_state(of)
		const instance = of:get_reference():get_instance()
		const root = physics.get_root(instance)

		if not of.enabled or not root or not instance or delta <= 0 then
			state.grounded = false
			state.distance = nil
			return
		end

		if state.instance ~= instance then
			state.instance = instance
			state.filter = physics.create_filter({ instance })
			state.look = nil
			state.rising = false
		end

		const mass = physics.get_mass(root)
		const velocity = physics.get_linear_velocity(root)
		const hip_height = math.max(of.hip_height, 0)
		const reach = hip_height + math.max(of.floor_reach, 0)
		const distance, normal = physics.cast(physics.get_position(root), vector.create(0, -reach, 0), state.filter)

		if state.rising and velocity.y <= 0 then
			state.rising = false
		end

		state.distance = distance
		state.normal = normal or of.up_direction or class.up_direction
		state.grounded = distance ~= nil and not state.rising

		const direction = private.planar(of.move_direction)
		const planar = vector.create(velocity.x, 0, velocity.z)
		const acceleration = of:get_movement_controller():apply_measurement(direction * of.walk_speed, planar, delta)
		local impulse = vector.create(acceleration.x, 0, acceleration.z) * mass * delta

		const height = of:get_height_controller()

		if state.grounded and distance then
			if of.jump then
				of.jump = false
				state.rising = true
				state.grounded = false
				height:reset()
				impulse += vector.create(0, (of.jump_power - velocity.y) * mass, 0)
			else
				const lift = height:apply_measurement(hip_height, distance, delta)
				impulse += vector.create(0, math.max(physics.get_gravity() + lift, 0) * mass * delta, 0)
			end
		else
			height:reset()
		end

		if vector.magnitude(impulse) > 0 then
			physics.apply_impulse(root, impulse)
		end

		private.rotate(of, state, root, direction, delta)
	end

	private.connection = physics.on_step(function(delta: number)
		for k, v in private.entities do
			const succ, err = pcall(private.step, k, delta)

			if not succ then
				k.enabled = false
				--#if DEBUG
				std:outw(`{k.type} step failed, disabled with {err}`)
				--#endif
			end
		end
	end)
end

return class
