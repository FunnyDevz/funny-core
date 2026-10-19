--!strict
--!native
--!optimize 2

const Struct = require("@game/ReplicatedStorage/class/core/Struct")
const AABBVolume = require("@game/ReplicatedStorage/class/struct/geometry/AABBVolume")
const CubeVolume = require("@game/ReplicatedStorage/class/struct/geometry/CubeVolume")
const SAT = require("@game/ReplicatedStorage/dependency/SAT")
const ctags = require("@game/ReplicatedStorage/static/ctags")
const ctype = require("@game/ReplicatedStorage/static/ctype")
const declare = require("@game/ReplicatedStorage/static/declare")
const ftype = require("@game/ReplicatedStorage/static/ftype")
const project = require("@game/ReplicatedStorage/static/project")

const private = {}
const class: obbvolume = CubeVolume:new({
	type = "obbvolume",
	half = vector.one / 2,

	from = ftype:write(function(self: obbvolume, ...: geometry_supported): obbvolume
		const values = { ... }

		if #values == 0 then
			return self:clone()
		end

		local new = private.convert(values[1])

		if not new then
			project.console_out_error("unsupported geometry in OBB from")
			return self:clone()
		end

		for i = 2, #values do
			const converted = private.generate_from_convert(new, values[i])

			if converted then
				new = converted
			end
		end

		return new
	end, "obbvolume", "obbvolume", ftype:var(declare.roblox.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	middle = ftype:write(function(self: obbvolume, ...: geometry_supported): obbvolume
		const values = { ... }

		if #values == 0 then
			return self:clone()
		end

		const right_axis, up_axis, front_axis = private.get_axes(self)

		local center_sum = self:get_center()
		local right_half_sum = self.half.x
		local up_half_sum = self.half.y
		local front_half_sum = self.half.z
		local count = 1

		for _, value in values do
			const volume = private.convert(value)

			if not volume then
				project.console_out_error("unsupported geometry in OBB middle")
				return self:clone()
			end

			const center = volume:get_center()
			const axises = { private.get_axes(volume) }

			center_sum += center

			right_half_sum += math.abs(vector.dot(right_axis, axises[1])) * volume.half.x + math.abs(
				vector.dot(right_axis, axises[2])
			) * volume.half.y + math.abs(vector.dot(right_axis, axises[3])) * volume.half.z

			up_half_sum += math.abs(vector.dot(up_axis, axises[1])) * volume.half.x + math.abs(
				vector.dot(up_axis, axises[2])
			) * volume.half.y + math.abs(vector.dot(up_axis, axises[3])) * volume.half.z

			front_half_sum += math.abs(vector.dot(front_axis, axises[1])) * volume.half.x + math.abs(
				vector.dot(front_axis, axises[2])
			) * volume.half.y + math.abs(vector.dot(front_axis, axises[3])) * volume.half.z

			count += 1
		end

		const center = center_sum / count

		return private.from_basis(
			self,
			center,
			right_axis,
			up_axis,
			front_axis,
			vector.create(right_half_sum / count, up_half_sum / count, front_half_sum / count)
		)
	end, "obbvolume", "obbvolume", ftype:var(declare.roblox.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	cover = ftype:write(function(self: obbvolume, ...: geometry_supported): obbvolume
		return private.cover(self, { ... })
	end, "obbvolume", "obbvolume", ftype:var(declare.roblox.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	is_inside = ftype:write(function(self: obbvolume, ...: unknown): boolean
		for _, value in { ... } do
			const volume = private.convert(value :: any)

			if not volume then
				project.console_out_error("unsupported geometry in OBB is_inside")
				return false
			end

			if not private.is_inside_obb(self, volume) then
				return false
			end
		end

		return true
	end, declare.boolean, "obbvolume", ftype:var(declare.roblox.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	is_interacts = ftype:write(function(self: obbvolume, ...: unknown): boolean
		for _, value in { ... } do
			if not self:is_inside(value) and not self:is_intersection(value) then
				return false
			end
		end

		return true
	end, declare.boolean, "obbvolume", ftype:var(declare.roblox.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	is_intersection = ftype:write(function(self: obbvolume, ...: unknown): boolean
		for _, value in { ... } do
			const volume = private.convert(value :: any)

			if not volume then
				project.console_out_error("unsupported geometry in OBB is_intersection")
				return false
			end

			if not private.is_intersection_obb(self, volume) then
				return false
			end
		end

		return true
	end, declare.boolean, "obbvolume", ftype:var(declare.roblox.Instance, "aabbvolume", "obbvolume", "cubevolume")),

	look_at = ftype:write(function(self: obbvolume, at: vector, up: vector?): obbvolume
		const center = self:get_center()
		const delta = at - center

		if vector.dot(delta, delta) <= 1e-12 then
			return self:clone()
		end

		const front = vector.normalize(delta)
		local reference_up = up or vector.create(0, 1, 0)

		if vector.dot(reference_up, reference_up) <= 1e-12 then
			reference_up = vector.create(0, 1, 0)
		else
			reference_up = vector.normalize(reference_up)
		end

		if math.abs(vector.dot(front, reference_up)) > 0.999999 then
			reference_up = vector.create(1, 0, 0)

			if math.abs(vector.dot(front, reference_up)) > 0.999999 then
				reference_up = vector.create(0, 0, 1)
			end
		end

		const right = vector.normalize(vector.cross(reference_up, front))
		const real_up = vector.normalize(vector.cross(front, right))

		return private.from_basis(self, center, right, real_up, front, self.half)
	end, "obbvolume", "obbvolume", declare.vector, ftype:opt(declare.vector)),

	rotate_radian = ftype:write(function(self: obbvolume, radian_vector: vector): obbvolume
		const right, up, front = private.get_axes(self)
		const roll = radian_vector.x
		const pitch = radian_vector.y
		const yaw = radian_vector.z
		const sin_roll = math.sin(roll)
		const cos_roll = math.cos(roll)
		const sin_pitch = math.sin(pitch)
		const cos_pitch = math.cos(pitch)
		const sin_yaw = math.sin(yaw)
		const cos_yaw = math.cos(yaw)
		const right_x = cos_yaw * cos_pitch
		const right_y = sin_yaw * cos_pitch
		const right_z = -sin_pitch
		const up_x = cos_yaw * sin_pitch * sin_roll - sin_yaw * cos_roll
		const up_y = sin_yaw * sin_pitch * sin_roll + cos_yaw * cos_roll
		const up_z = cos_pitch * sin_roll
		const front_x = cos_yaw * sin_pitch * cos_roll + sin_yaw * sin_roll
		const front_y = sin_yaw * sin_pitch * cos_roll - cos_yaw * sin_roll
		const front_z = cos_pitch * cos_roll
		const new_right = right * right_x + up * right_y + front * right_z
		const new_up = right * up_x + up * up_y + front * up_z
		const new_front = right * front_x + up * front_y + front * front_z

		-- Rz(yaw) * Ry(pitch) * Rx(roll)

		return private.from_basis(self, self:get_center(), new_right, new_up, new_front, self.half)
	end, "obbvolume", "obbvolume", declare.vector),

	get_rotation_radian = ftype:write(function(self: obbvolume): vector
		const right, up, front = private.get_axes(self)

		const pitch = math.asin(-right.z)
		const cos_pitch = math.cos(pitch)

		if math.abs(cos_pitch) > 1e-6 then
			const roll = math.atan2(up.z, front.z)
			const yaw = math.atan2(right.y, right.x)

			return vector.create(roll, pitch, yaw)
		end

		const roll = 0
		const yaw = math.atan2(-up.x, up.y)

		return vector.create(roll, pitch, yaw)
	end, declare.vector, "obbvolume"),
})

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

do
	--[[
		Создаёт OBB из центра, трёх осей и half-size.
		оси нормализуются и ортогонализуются.
	]]
	private.from_basis = function(
		self: obbvolume,
		center: vector,
		right: vector,
		up: vector,
		front: vector,
		half: vector
	): obbvolume
		const right_axis = vector.normalize(right)
		const up_projected = up - right_axis * vector.dot(up, right_axis)
		const up_axis = vector.normalize(up_projected)

		local front_axis = vector.normalize(vector.cross(right_axis, up_axis))

		if vector.dot(front_axis, front) < 0 then
			front_axis = -front_axis
		end

		return self:clone({
			half = vector.create(math.abs(half.x), math.abs(half.y), math.abs(half.z)),

			right = center + right_axis * math.abs(half.x),
			left = center - right_axis * math.abs(half.x),

			up = center + up_axis * math.abs(half.y),
			bottom = center - up_axis * math.abs(half.y),

			front = center + front_axis * math.abs(half.z),
			back = center - front_axis * math.abs(half.z),
		})
	end

	private.get_axes = function(self: obbvolume): (vector, vector, vector)
		const center = self:get_center()

		return vector.normalize(self.right - center),
			vector.normalize(self.up - center),
			vector.normalize(self.front - center)
	end

	private.get_cube_half = function(volume: cubevolume): vector
		const center = volume:get_center()

		return vector.create(
			vector.magnitude(volume.right - center),
			vector.magnitude(volume.up - center),
			vector.magnitude(volume.front - center)
		)
	end

	private.from_cframe = function(self: obbvolume, cframe: CFrame, size: Vector3): obbvolume
		const position = cframe.Position

		const center = vector.create(position.X, position.Y, position.Z)

		const right = cframe.RightVector
		const up = cframe.UpVector
		const front = cframe.LookVector

		return private.from_basis(
			self,
			center,
			vector.create(right.X, right.Y, right.Z),
			vector.create(up.X, up.Y, up.Z),
			vector.create(front.X, front.Y, front.Z),
			vector.create(size.X / 2, size.Y / 2, size.Z / 2)
		)
	end

	private.from_aabb = function(self: obbvolume, volume: aabbvolume): obbvolume
		const center = volume:get_center()

		return private.from_basis(
			self,
			center,
			volume.right - center,
			volume.up - center,
			volume.front - center,
			volume.half
		)
	end

	private.from_cube = function(self: obbvolume, volume: cubevolume): obbvolume
		const center = volume:get_center()
		const half = private.get_cube_half(volume)

		return private.from_basis(self, center, volume.right - center, volume.up - center, volume.front - center, half)
	end

	private.from_model = function(self: obbvolume, instance: Model): obbvolume
		const cframe, size = instance:GetBoundingBox()

		return private.from_cframe(self, cframe, size)
	end

	private.from_basepart = function(self: obbvolume, instance: BasePart): obbvolume
		return private.from_cframe(self, instance.CFrame, instance.Size)
	end

	private.from_pvinstance = function(self: obbvolume, instance: PVInstance): obbvolume
		if instance:IsA("BasePart") then
			return private.from_basepart(self, instance)
		elseif instance:IsA("Model") then
			return private.from_model(self, instance)
		end

		return self
	end

	--[[
		Возвращает OBB из geometry_supported.
		Здесь происходит только конвертация, без объединения.
	]]
	private.convert = function(v: geometry_supported): obbvolume?
		const gen = private.find_right_in(private.convert_list, v)

		if gen then
			return gen(v)
		end

		return nil
	end

	private.convert_list = table.freeze({
		[class.type] = function(value: obbvolume): obbvolume
			return value:clone()
		end,

		[AABBVolume.type] = function(value: aabbvolume): obbvolume
			return private.from_aabb(class, value)
		end,

		[CubeVolume.type] = function(value: cubevolume): obbvolume
			return private.from_cube(class, value)
		end,

		["Model"] = function(value: Model): obbvolume
			return private.from_model(class, value)
		end,

		["BasePart"] = function(value: BasePart): obbvolume
			return private.from_basepart(class, value)
		end,

		["PVInstance"] = function(value: PVInstance): obbvolume
			return private.from_pvinstance(class, value)
		end,
	}) :: {
		[string]: (geometry_supported) -> obbvolume,
	}

	--[[
		Объединяет уже существующий OBB с новым объектом.
		Ориентация сохраняется у prev.
	]]
	private.cover_obb = function(prev: obbvolume, new: obbvolume): obbvolume
		const center = prev:get_center()
		const right_axis, up_axis, front_axis = private.get_axes(prev)

		local min_right = -prev.half.x
		local max_right = prev.half.x
		local min_up = -prev.half.y
		local max_up = prev.half.y
		local min_front = -prev.half.z
		local max_front = prev.half.z

		for _, corner in new:get_corners() do
			const delta = corner - center

			const right = vector.dot(delta, right_axis)
			const up = vector.dot(delta, up_axis)
			const front = vector.dot(delta, front_axis)

			min_right = math.min(min_right, right)
			max_right = math.max(max_right, right)

			min_up = math.min(min_up, up)
			max_up = math.max(max_up, up)

			min_front = math.min(min_front, front)
			max_front = math.max(max_front, front)
		end

		const new_center = center
			+ right_axis * ((min_right + max_right) / 2)
			+ up_axis * ((min_up + max_up) / 2)
			+ front_axis * ((min_front + max_front) / 2)

		const new_half = vector.create((max_right - min_right) / 2, (max_up - min_up) / 2, (max_front - min_front) / 2)

		return private.from_basis(prev, new_center, right_axis, up_axis, front_axis, new_half)
	end

	private.generate_from_convert = function(self: obbvolume, v: geometry_supported): obbvolume?
		const gen = private.find_right_in(private.from_convert, v)

		if gen then
			return gen(self, v)
		end

		return nil
	end

	private.from_convert = table.freeze({
		[class.type] = function(prev: obbvolume, new: obbvolume): obbvolume
			return private.cover_obb(prev, new)
		end,

		[AABBVolume.type] = function(prev: obbvolume, new: aabbvolume): obbvolume
			return private.cover_obb(prev, private.from_aabb(prev, new))
		end,

		[CubeVolume.type] = function(prev: obbvolume, new: cubevolume): obbvolume
			return private.cover_obb(prev, private.from_cube(prev, new))
		end,

		["Model"] = function(prev: obbvolume, new: Model): obbvolume
			return private.cover_obb(prev, private.from_model(prev, new))
		end,

		["BasePart"] = function(prev: obbvolume, new: BasePart): obbvolume
			return private.cover_obb(prev, private.from_basepart(prev, new))
		end,

		["PVInstance"] = function(prev: obbvolume, new: PVInstance): obbvolume
			return private.cover_obb(prev, private.from_pvinstance(prev, new))
		end,
	}) :: {
		[string]: (obbvolume, geometry_supported | Instance) -> obbvolume,
	}

	private.is_inside_point = function(self: obbvolume, point: vector): boolean
		const center = self:get_center()
		const right_axis, up_axis, front_axis = private.get_axes(self)

		const delta = point - center

		const right = math.abs(vector.dot(delta, right_axis))
		const up = math.abs(vector.dot(delta, up_axis))
		const front = math.abs(vector.dot(delta, front_axis))

		return (right <= self.half.x and up <= self.half.y and front <= self.half.z)
	end

	private.is_inside_obb = function(self: obbvolume, other: obbvolume): boolean
		for _, corner in other:get_corners() do
			if not private.is_inside_point(self, corner) then
				return false
			end
		end

		return true
	end

	private.is_intersection_obb = function(self: obbvolume, other: obbvolume): boolean
		const generator = SAT:compute_generator(
			self:get_sat_axises(),
			other:get_sat_axises(),
			self.half,
			other.half,
			self:get_center(),
			other:get_center()
		)

		const projection = SAT:compute_projection(generator)
		const mtv = SAT:compute_mtv(projection)

		return mtv.mtv >= 0
	end

	private.cover = function(self: obbvolume, values: { geometry_supported }): obbvolume
		local result = self

		for _, value in values do
			const converted = private.convert(value)

			if not converted then
				project.console_out_error("unsupported geometry in OBB cover")
				return result
			end

			result = private.cover_obb(result, converted)
		end

		return result
	end

	private.find_right_in = function(list: { [string]: (...any) -> any }, v: geometry_supported): ((...any) -> any)?
		local func

		if class:that(v, Struct.type) then
			const var = v :: luaobject
			func = list[var.type]
		elseif typeof(v) == declare.roblox.Instance then
			const var = v :: Model | BasePart | PVInstance

			-- Сначала точное имя класса.
			func = list[var.ClassName]

			-- Затем наследование Roblox Instance.
			if not func then
				if var:IsA("BasePart") then
					func = list["BasePart"]
				elseif var:IsA("Model") then
					func = list["Model"]
				elseif var:IsA("PVInstance") then
					func = list["PVInstance"]
				end
			end
		else
			project.console_out_error("cannot reach unknown LuaObject, skipped")
			return nil
		end

		if not project.assert(func, "cannot find right generator", true) then
			return nil
		end

		return func
	end
end

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class
