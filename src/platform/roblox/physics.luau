--!strict
const engine = require("@platform/roblox/engine")
const worldspace = require("@platform/roblox/worldspace")

return table.freeze {
	is_pvinstance = function(that: unknown): boolean
		return typeof(that) == "Instance" and (that :: Instance):IsA("PVInstance")
	end,

	get_root = function(of: Instance?): BasePart?
		if of == nil then
			return nil
		end

		if of:IsA("BasePart") then
			return of
		end

		if of:IsA("Model") then
			return of.PrimaryPart or of:FindFirstChildWhichIsA("BasePart", true)
		end

		return nil
	end,

	get_mass = function(part: BasePart): number
		return part.AssemblyMass
	end,

	get_gravity = function(): number
		return workspace.Gravity
	end,

	get_position = function(part: BasePart): vector
		const position = part.Position
		return vector.create(position.X, position.Y, position.Z)
	end,

	get_axes = function(part: BasePart): (vector, vector, vector)
		const cframe = part.CFrame
		const right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector

		return vector.create(right.X, right.Y, right.Z), vector.create(up.X, up.Y, up.Z), vector.create(look.X, look.Y, look.Z)
	end,

	get_linear_velocity = function(part: BasePart): vector
		const velocity = part.AssemblyLinearVelocity
		return vector.create(velocity.X, velocity.Y, velocity.Z)
	end,

	get_angular_velocity = function(part: BasePart): vector
		const velocity = part.AssemblyAngularVelocity
		return vector.create(velocity.X, velocity.Y, velocity.Z)
	end,

	set_angular_velocity = function(part: BasePart, to: vector): ()
		part.AssemblyAngularVelocity = Vector3.new(to.x, to.y, to.z)
	end,

	apply_impulse = function(part: BasePart, impulse: vector): ()
		part:ApplyImpulse(Vector3.new(impulse.x, impulse.y, impulse.z))
	end,

	create_filter = function(exclude: { Instance }): RaycastParams
		const params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		params.IgnoreWater = true
		params.RespectCanCollide = true
		return params
	end,

	cast = function(origin: vector, direction: vector, params: RaycastParams?): (number?, vector?)
		const result = worldspace.raycast(origin, direction, params)

		if not result then
			return nil, nil
		end

		const normal = result.Normal
		return result.Distance + vector.magnitude(direction) * 0.01, vector.create(normal.X, normal.Y, normal.Z)
	end,

	on_step = function(f: (delta: number) -> ()): RBXScriptConnection
		return engine.prephysic:Connect(function(delta: number)
			f(delta)
		end)
	end,
}
