--!strict
--!native
--!optimize 2

const CubeVolume = require("@class/struct/geometry/CubeVolume")
const types = require("@declare/types")
const stdout = require("@extension/stdout")
const SAT = require("@import/SAT")
const rbxtypes = require("@platform/roblox/rbxtypes")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const private = {}
const class: aabbvolume = CubeVolume:new({
	type = "aabbvolume",

	half = vector.zero,
	min = vector.zero,
	max = vector.zero,

	is_inside = ftype:write(function(self: aabbvolume, ...: unknown): boolean
		for _, value in { ... } do
			if typeof(value) == rbxtypes.Instance then
				const instance = value :: Instance

				const other_min, other_max = private.get_instance_bounds(instance)

				if not other_min or not other_max then
					stdout:oute("unsupported Instance in AABB is_inside")
					return false
				end

				if not private.is_inside_aabb(
					self.min,
					self.max,
					other_min,
					other_max
				)
				then
					return false 
				end

			elseif self:that(value, "aabbvolume") then
				const volume = value :: aabbvolume

				if not private.is_inside_aabb(
					self.min,
					self.max,
					volume.min,
					volume.max
				)
				then
					return false
				end

			elseif self:that(value, "cubevolume") then
				const volume = value :: cubevolume

				if not private.is_inside_cube(self, volume) then
					return false
				end

			else
				stdout:oute("unsupported geometry in AABB is_inside")
				return false
			end
		end

		return true
	end, types.boolean, "aabbvolume", ftype:var(rbxtypes.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	is_interacts = ftype:write(function(self: aabbvolume, ...: unknown): boolean
		for _, value in {...} do
			if not self:is_inside(value) and not self:is_intersection(value) then
				return false
			end
		end

		return true
	end, types.boolean, "aabbvolume", ftype:var(rbxtypes.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	is_intersection = ftype:write(function(self: aabbvolume, ...: unknown): boolean
		for _, value in {...} do
			if typeof(value) == rbxtypes.Instance then
				const instance = value :: Instance

				const other_min, other_max = private.get_instance_bounds(instance)

				if not other_min or not other_max then
					stdout:oute("unsupported Instance in AABB is_intersection")
					return false
				end

				if not private.is_intersection_aabb(
					self.min,
					self.max,
					other_min,
					other_max
				)
				then
					return false
				end

			elseif self:that(value, "aabbvolume") then
				const volume = value :: aabbvolume

				if not private.is_intersection_aabb(
					self.min,
					self.max,
					volume.min,
					volume.max
				)
				then
					return false
				end

			elseif self:that(value, "cubevolume") then
				const volume = value :: cubevolume

				if not private.is_intersection_cube(self, volume) then
					return false
				end

			else
				stdout:oute("unsupported geometry in AABB is_intersection")
				return false
			end
		end

		return true
	end, types.boolean, "aabbvolume", ftype:var(rbxtypes.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	from = ftype:write(function(self: aabbvolume, ...: geometry_supported): aabbvolume
		const values = {...}

		if #values == 0 then
			return self:clone()
		end

		if #values == 1 and self:that(values[1], "aabbvolume") then
			const volume = values[1] :: aabbvolume

			return self:clone(private.from_bounds(volume.min, volume.max))
		end

		local min: vector?
		local max: vector?

		for _, value in values do
			const other_min, other_max = private.get_bounds(self, value)

			if not other_min or not other_max then
				stdout:oute("unsupported geometry in AABB from")
				return self:clone()
			end

			if not min or not max then
				min = other_min
				max = other_max
			else
				min = vector.create(
					math.min(min.x, other_min.x),
					math.min(min.y, other_min.y),
					math.min(min.z, other_min.z)
				)

				max = vector.create(
					math.max(max.x, other_max.x),
					math.max(max.y, other_max.y),
					math.max(max.z, other_max.z)
				)
			end
		end

		return self:clone(private.from_bounds(min :: vector, max :: vector))
	end, "aabbvolume", "aabbvolume", ftype:var(rbxtypes.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	middle = ftype:write(function(self: aabbvolume, ...: geometry_supported): aabbvolume
		return private.middle(self, table.freeze({ ... }) :: { geometry_supported })
	end, "aabbvolume", "aabbvolume", ftype:var(rbxtypes.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	cover = ftype:write(function(self: aabbvolume, ...: geometry_supported): aabbvolume
		return private.cover(self, table.freeze({ ... }) :: { geometry_supported })
	end, "aabbvolume", "aabbvolume", ftype:var(rbxtypes.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	look_at = ftype:write(function(self: aabbvolume, at: vector, up: vector?) : aabbvolume
		const center = self:get_center()
		const direction = at - center

		if vector.dot(direction, direction) <= 1e-12 then
			return self:clone()
		end

		const front = vector.normalize(direction)
		local reference_up = vector.normalize(up or vector.create(0, 1, 0))

		if math.abs(vector.dot(front, reference_up)) > 0.999999 then
			reference_up = vector.create(1, 0, 0)

			if math.abs(vector.dot(front, reference_up)) > 0.999999 then
				reference_up = vector.create(0, 0, 1)
			end
		end

		const right = vector.normalize(vector.cross(reference_up, front))
		const real_up = vector.normalize(vector.cross(front, right))
		const half = self.half

		const world_half =
			vector.create(math.abs(right.x) * half.x + math.abs(real_up.x) * half.y + math.abs(front.x) * half.z, math.abs(
				right.y
			) * half.x + math.abs(real_up.y) * half.y + math.abs(front.y) * half.z, math.abs(right.z) * half.x + math.abs(real_up.z) * half.y + math.abs(front.z) * half.z)

		return self:clone(private.from_bounds(center - world_half, center + world_half))
	end, "aabbvolume", "aabbvolume", types.vector, ftype:opt(types.vector)),
})

do
	private.from_bounds = function(min: vector, max: vector)
		const center = (min + max) / 2
		const half = (max - min) / 2

		return {
			min = min,
			max = max,
			half = half,

			right = vector.create(max.x, center.y, center.z),
			left = vector.create(min.x, center.y, center.z),

			up = vector.create(center.x, max.y, center.z),
			bottom = vector.create(center.x, min.y, center.z),

			front = vector.create(center.x, center.y, min.z),
			back = vector.create(center.x, center.y, max.z),
		}
	end

	private.from_cframe = function(cframe: CFrame, size: Vector3): (vector, vector)
		const position = cframe.Position

		const half_x = size.X / 2
		const half_y = size.Y / 2
		const half_z = size.Z / 2

		const right = cframe.RightVector
		const up = cframe.UpVector
		const front = cframe.LookVector

		const half =
			vector.create(math.abs(right.X) * half_x + math.abs(up.X) * half_y + math.abs(front.X) * half_z, math.abs(
				right.Y
			) * half_x + math.abs(up.Y) * half_y + math.abs(front.Y) * half_z, math.abs(right.Z) * half_x + math.abs(up.Z) * half_y + math.abs(front.Z) * half_z)

		const center = vector.create(position.X, position.Y, position.Z)

		return center - half, center + half
	end

	private.get_instance_bounds = function(instance: Instance): (vector?, vector?)
		if instance:IsA("BasePart") then
			return private.from_cframe(instance.CFrame, instance.Size)
		elseif instance:IsA("Model") then
			const cframe, size = instance:GetBoundingBox()

			return private.from_cframe(cframe, size)

		elseif instance:IsA("PVInstance") then
			return private.from_cframe(instance:GetPivot(), Vector3.one)
		end

		return nil, nil
	end

	private.get_cube_bounds = function(volume: cubevolume): (vector, vector)
		const corners = volume:get_corners()

		local min = corners[1]
		local max = corners[1]

		for i = 2, #corners do
			const corner = corners[i]

			min = vector.create(math.min(min.x, corner.x), math.min(min.y, corner.y), math.min(min.z, corner.z))

			max = vector.create(math.max(max.x, corner.x), math.max(max.y, corner.y), math.max(max.z, corner.z))
		end

		return min, max
	end

	private.get_bounds = function(self: aabbvolume, value: geometry_supported): (vector?, vector?)
		if typeof(value) == rbxtypes.Instance then
			const instance = value :: Model | BasePart | PVInstance

			return private.get_instance_bounds(instance)
		end

		if self:that(value, "aabbvolume") then
			const volume = value :: aabbvolume

			return volume.min, volume.max
		elseif self:that(value, "cubevolume") then
			const volume = value :: cubevolume

			return private.get_cube_bounds(volume)
		end

		return nil, nil
	end

	private.is_inside_aabb = function(self_min: vector, self_max: vector, other_min: vector, other_max: vector): boolean
		return (
			self_min.x <= other_min.x
			and self_max.x >= other_max.x
			and self_min.y <= other_min.y
			and self_max.y >= other_max.y
			and self_min.z <= other_min.z
			and self_max.z >= other_max.z
		)
	end

	private.is_intersection_aabb = function(
		self_min: vector,
		self_max: vector,
		other_min: vector,
		other_max: vector
	): boolean
		return (
			self_min.x <= other_max.x
			and self_max.x >= other_min.x
			and self_min.y <= other_max.y
			and self_max.y >= other_min.y
			and self_min.z <= other_max.z
			and self_max.z >= other_min.z
		)
	end

	private.is_inside_cube = function(self: aabbvolume, volume: cubevolume): boolean
		for _, corner in volume:get_corners() do
			if
				not (
					self.min.x <= corner.x
					and self.max.x >= corner.x
					and self.min.y <= corner.y
					and self.max.y >= corner.y
					and self.min.z <= corner.z
					and self.max.z >= corner.z
				)
			then
				return false
			end
		end

		return true
	end

	private.is_intersection_cube = function(self: aabbvolume, volume: cubevolume): boolean
		const generator = SAT:compute_generator(
			self:get_sat_axises(),
			volume:get_sat_axises(),
			self.half,
			volume:to_vector() / 2,
			self:get_center(),
			volume:get_center()
		)

		const projection = SAT:compute_projection(generator)
		const mtv = SAT:compute_mtv(projection)

		return mtv.mtv >= 0
	end

	private.middle = function(self: aabbvolume, values: { geometry_supported }): aabbvolume
		const count = #values + 1

		local min = self.min
		local max = self.max

		for _, value in values do
			const other_min, other_max = private.get_bounds(self, value)

			if not other_min or not other_max then
				stdout:oute("unsupported geometry in AABB middle")
				return self:clone()
			end

			min += other_min
			max += other_max
		end

		min /= count
		max /= count

		return self:clone(private.from_bounds(min, max))
	end

	private.cover = function(self: aabbvolume, values: { geometry_supported }): aabbvolume
		local min = self.min
		local max = self.max

		for _, value in values do
			const other_min, other_max = private.get_bounds(self, value)

			if not other_min or not other_max then
				stdout:oute("unsupported geometry in AABB cover")
				return self:clone()
			end

			min =
				vector.create(math.min(min.x, other_min.x), math.min(min.y, other_min.y), math.min(min.z, other_min.z))

			max =
				vector.create(math.max(max.x, other_max.x), math.max(max.y, other_max.y), math.max(max.z, other_max.z))
		end

		return self:clone(private.from_bounds(min, max))
	end
end

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class