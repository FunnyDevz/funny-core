--!strict
--!native
--!optimize 2
const Directions = require("@class/struct/geometry/Directions")
const GeoVolume = require("@class/struct/geometry/GeoVolume")
const types = require("@declare/types")
const Quat = require("@import/Quat")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const class: basis = (GeoVolume :: geovolume<basis>):new({
	type = "basis",
	rotation = Directions:new(),
	position = vector.zero,

	orthonormalize = ftype:write(function(self: basis): basis
		const right = self.rotation.right
		const up = self.rotation.up

		const orthonormal_right = vector.normalize(right)
		const orthonormal_up = vector.normalize(up - orthonormal_right * vector.dot(up, orthonormal_right))
		const orthonormal_front = -vector.normalize(vector.cross(orthonormal_right, orthonormal_up))

		const clone = self:clone({
			rotation = self.rotation:clone({
				right = orthonormal_right,
				up = orthonormal_up,
				front = orthonormal_front,
			}),
		})

		return clone
	end, "basis", "basis"),

	euler_angles = ftype:write(function(self: basis): ...number
		const right = self.rotation.right
		const up = self.rotation.up
		const front = self.rotation.front
		const pitch = math.asin(-right.z)
		const cos_pitch = math.cos(pitch)

		if math.abs(cos_pitch) > 1e-6 then
			const roll = math.atan2(up.z, front.z)
			const yaw = math.atan2(right.y, right.x)

			return roll, pitch, yaw
		end

		const roll = 0
		const yaw = math.atan2(-up.x, up.y)

		return roll, pitch, yaw
	end, ftype:var(types.number), "basis"),

    slerp = ftype:write(function(self: basis, to: basis, alpha: number) : basis
        const position = vector.lerp(self.position, to.position, alpha)
        const from_quaternion = Quat.from_looked(-self.rotation.front, self.rotation.up)
        const to_quaternion = Quat.from_looked(-to.rotation.front, to.rotation.up)
        const rotation = Quat.slerp(from_quaternion, to_quaternion, alpha)

        const x = rotation.x
        const y = rotation.y
        const z = rotation.z
        const w = Quat.scalar(rotation)

        const xx = x * x
        const yy = y * y
        const zz = z * z

        const xy = x * y
        const xz = x * z
        const yz = y * z

        const wx = w * x
        const wy = w * y
        const wz = w * z

        const right = vector.create(
            1 - 2 * (yy + zz),
            2 * (xy + wz),
            2 * (xz - wy)
        )

        const up = vector.create(
            2 * (xy - wz),
            1 - 2 * (xx + zz),
            2 * (yz + wx)
        )

        const back = vector.create(
            2 * (xz + wy),
            2 * (yz - wx),
            1 - 2 * (xx + yy)
        )

        const front = -back

        return self:clone {
            position = position,
            rotation = self.rotation:clone {
                right = right,
                up = up,
                front = front,
            }
        }
    end, "basis", "basis", "basis", types.number),

    to_basis = function(self: basis, ...: CFrame): ...basis
        const result: { basis } = {}

        for _, v in { ... } do
            const x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()

            table.insert(result, self:from_components(x, y, z, r00, r10, r20, r01, r11, r21, -r02, -r12, -r22))
        end

        return unpack(result)
    end,

    to_cframe = function(self: basis, ...: basis): ...CFrame
        const result: { CFrame } = {}

        for _, v in { ... } do
            const x, y, z, right_x, up_x, front_x, right_y, up_y, front_y, right_z, up_z, front_z = v:get_components()

            table.insert(
                result,
                CFrame.new(x, y, z, right_x, up_x, -front_x, right_y, up_y, -front_y, right_z, up_z, -front_z)
            )
        end

        return unpack(result)
    end,

	get_components = ftype:write(function(self: basis): (number, number, number, number, number, number, number, number, number, number, number, number)
			const right = self.rotation.right
			const up = self.rotation.up
			const front = self.rotation.front
			const pos = self.position

			return pos.x, pos.y, pos.z, right.x, up.x, front.x, right.y, up.y, front.y, right.z, up.z, front.z
		end,
		ftype:var(types.number),
		"basis"
	),

	from_components = ftype:write(function(
		self: basis,
		position_x: number?,
		position_y: number?,
		position_z: number?,
		rotation_right_x: number?,
		rotation_right_y: number?,
		rotation_right_z: number?,
		rotation_up_x: number?,
		rotation_up_y: number?,
		rotation_up_z: number?,
		rotation_front_x: number?,
		rotation_front_y: number?,
		rotation_front_z: number?
	): basis
		return self:clone({
			position = vector.create(position_x or 0, position_y or 0, position_z or 0),
			rotation = self.rotation:clone({
				right = vector.create(rotation_right_x or 0, rotation_right_y or 0, rotation_right_z or 0),
				up = vector.create(rotation_up_x or 0, rotation_up_y or 0, rotation_up_z or 0),
				front = vector.create(rotation_front_x or 0, rotation_front_y or 0, rotation_front_z or 0),
			}),
		})
	end, "basis", "basis",
        ftype:opt(types.number),  ftype:opt(types.number),  ftype:opt(types.number),
        ftype:opt(types.number), ftype:opt(types.number), ftype:opt(types.number),
        ftype:opt(types.number), ftype:opt(types.number), ftype:opt(types.number),
        ftype:opt(types.number), ftype:opt(types.number), ftype:opt(types.number)
    ),

	from_matrix = ftype:write(function(
		self: basis,
		position: vector?,
		rotation_right: vector?,
		rotation_up: vector?,
		rotation_front: vector?
	): basis
		return self:clone({
			position = position,
			rotation = self.rotation:clone({
				right = rotation_right,
				up = rotation_up,
				front = rotation_front,
			}),
		})
	end, "basis", "basis",  ftype:opt(types.vector),  ftype:opt(types.vector),  ftype:opt(types.vector),  ftype:opt(types.vector)),

	basis_to_world = ftype:write(function(self: basis, ...: basis): ...basis
		const result: { basis } = {}

		for _, v in { ... } do
			const rotation = v.rotation
			const right, up, front = self:direction_to_world(rotation.right, rotation.up, rotation.front)
			const position = self:point_to_world(v.position)

			table.insert(
				result,
				self:clone({
					position = position,
					rotation = self.rotation:clone({
						right = right,
						up = up,
						front = front,
					}),
				})
			)
		end

		return unpack(result)
	end, ftype:var("basis"), "basis", ftype:var("basis")),

	basis_to_local = ftype:write(function(self: basis, ...: basis): ...basis
		const result: { basis } = {}

		for _, v in { ... } do
			const rotation = v.rotation
			const right, up, front = self:direction_to_local(rotation.right, rotation.up, rotation.front)

			table.insert(
				result,
				self:clone({
					position = self:point_to_local(v.position),
					rotation = self.rotation:clone({
						right = right,
						up = up,
						front = front,
					}),
				})
			)
		end

		return unpack(result)
	end, ftype:var("basis"), "basis", ftype:var("basis")),

	direction_to_world = ftype:write(function(self: basis, ...: vector): ...vector
        const right = self.rotation.right
        const up = self.rotation.up
        const front = self.rotation.front
        const result: { vector } = {}

        for _, v in { ... } do
            table.insert(result, right * v.x + up * v.y - front * v.z)
        end

        return unpack(result)
    end, ftype:var(types.vector), "basis", ftype:var(types.vector)),

    direction_to_local = ftype:write(function(self: basis, ...: vector): ...vector
        const right = self.rotation.right
        const up = self.rotation.up
        const front = self.rotation.front
        const result: { vector } = {}

        for _, v in { ... } do
            table.insert(result, vector.create(vector.dot(v, right), vector.dot(v, up), -vector.dot(v, front)))
        end

        return unpack(result)
    end, ftype:var(types.vector), "basis", ftype:var(types.vector)),

    point_to_world = ftype:write(function(self: basis, ...: vector): ...vector
        const right = self.rotation.right
        const up = self.rotation.up
        const front = self.rotation.front
        const position = self.position
        const result: { vector } = {}

        for _, v in { ... } do
            table.insert(result, position + right * v.x + up * v.y - front * v.z)
        end

        return unpack(result)
    end, ftype:var(types.vector), "basis", ftype:var(types.vector)),

    point_to_local = ftype:write(function(self: basis, ...: vector): ...vector
        const right = self.rotation.right
        const up = self.rotation.up
        const front = self.rotation.front
        const position = self.position
        const result: { vector } = {}

        for _, v in { ... } do
            const delta = v - position

            table.insert(result, vector.create(vector.dot(delta, right), vector.dot(delta, up), -vector.dot(delta, front)))
        end

        return unpack(result)
    end, ftype:var(types.vector), "basis", ftype:var(types.vector)),

    multiple_basis = ftype:write(function(self: basis, ...: basis): basis
        local result = self

        for _, value in { ... } do
            const rotation = result.rotation
            const other = value.rotation

            const right = vector.create(
                rotation.right.x * other.right.x + rotation.up.x * other.right.y - rotation.front.x * other.right.z,

                rotation.right.y * other.right.x + rotation.up.y * other.right.y - rotation.front.y * other.right.z,

                rotation.right.z * other.right.x + rotation.up.z * other.right.y - rotation.front.z * other.right.z
            )

            const up = vector.create(
                rotation.right.x * other.up.x + rotation.up.x * other.up.y - rotation.front.x * other.up.z,

                rotation.right.y * other.up.x + rotation.up.y * other.up.y - rotation.front.y * other.up.z,

                rotation.right.z * other.up.x + rotation.up.z * other.up.y - rotation.front.z * other.up.z
            )

            const front = vector.create(
                rotation.right.x * other.front.x + rotation.up.x * other.front.y - rotation.front.x * other.front.z,

                rotation.right.y * other.front.x + rotation.up.y * other.front.y - rotation.front.y * other.front.z,

                rotation.right.z * other.front.x + rotation.up.z * other.front.y - rotation.front.z * other.front.z
            )

            const position = result.position
                + rotation.right * value.position.x
                + rotation.up * value.position.y
                - rotation.front * value.position.z

            result = result:clone({
                position = position,

                rotation = rotation:clone({
                    right = right,
                    up = up,
                    front = front,
                }),
            })
        end

        return result
    end, "basis", "basis", ftype:var("basis")),

	divide_basis = ftype:write(function(self: basis, ...: basis): basis 
        local result = self

        for _, v in { ... } do
	    	result = result:multiple_basis(v:inverse_basis())

        end

        return result
    end, "basis", "basis", ftype:var("basis")),

	append_basis = ftype:write(function(self: basis, ...: basis): basis
        local result = self

        for _, v in { ... } do
		    result = v:multiple_basis(result)

        end

        return result
    end, "basis", "basis", ftype:var("basis")),

	substract_basis = ftype:write(function(self: basis, ...: basis): basis
        local result = self

        for _, v in {...} do
		    result = v:inverse_basis():multiple_basis(result)
        end

        return result
    end, "basis", "basis", ftype:var("basis")),

	inverse_basis = ftype:write(function(self: basis): basis
        const rotation = self.rotation
        const right = vector.create(rotation.right.x, rotation.up.x, rotation.front.x)
        const up = vector.create(rotation.right.y, rotation.up.y, rotation.front.y)
        const front = vector.create(rotation.right.z, rotation.up.z, rotation.front.z)

        const position = vector.create(
            -vector.dot(self.position, right),
            -vector.dot(self.position, up),
            -vector.dot(self.position, front)
        )

        return self:clone({
            position = position,

            rotation = rotation:clone({
                right = right,
                up = up,
                front = front,
            }),
        })
    end, "basis", "basis"),
})

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class
