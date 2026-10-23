--!strict
--!native
--!optimize 2

const EnumItem = require("@class/core/EnumItem")
const Basis = require("@class/struct/geometry/Basis")
const Directions = require("@class/struct/geometry/Directions")
const GeoVolume = require("@class/struct/geometry/GeoVolume")
const Quad = require("@class/struct/geometry/Quad")
const Triangle = require("@class/struct/geometry/Triangle")
const types = require("@declare/types")
const DirectionVariant = require("@enums/descriptor/DirectionVariant")
const stdout = require("@extension/stdout")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const class: cubevolume = (GeoVolume :: geovolume<cubevolume>):new({
	type = "cubevolume",

	up = vector.zero,
	bottom = vector.zero,
	left = vector.zero,
	right = vector.zero,
	front = vector.zero,
	back = vector.zero,

	get_corners = ftype:write(function(self: cubevolume): { vector }
		const center: vector = self:get_center()

		return {
			self.right + self.up + self.front - center * 2,
			self.right + self.up + self.back - center * 2,
			self.right + self.bottom + self.front - center * 2,
			self.right + self.bottom + self.back - center * 2,

			self.left + self.up + self.front - center * 2,
			self.left + self.up + self.back - center * 2,
			self.left + self.bottom + self.front - center * 2,
			self.left + self.bottom + self.back - center * 2,
		}
	end, types.table, "cubevolume"),

	get_direction = ftype:write(function(self: cubevolume, direction: enumitem): vector
		if direction == DirectionVariant.Right then
			return self.right
		elseif direction == DirectionVariant.Left then
			return self.left
		elseif direction == DirectionVariant.Up then
			return self.up
		elseif direction == DirectionVariant.Bottom then
			return self.bottom
		elseif direction == DirectionVariant.Front then
			return self.front
		elseif direction == DirectionVariant.Back then
			return self.back
		end

		return stdout:oute("unsupported DirectionVariant item") or vector.zero
	end, types.vector, "cubevolume", EnumItem.type),

	get_axises = ftype:write(function(self: cubevolume): directions
		return Directions:new({
			right = self:get_direction(DirectionVariant.Right),
			up = self:get_direction(DirectionVariant.Up),
			front = self:get_direction(DirectionVariant.Front),
		})
	end, Directions.type, "cubevolume"),

	get_sat_axises = ftype:write(function(self: cubevolume): { vector }
		const axises = self:get_axises()
		const center = self:get_center()
		const result = {}

		result[1] = vector.normalize(axises.right - center)
		result[2] = vector.normalize(axises.up - center)
		result[3] = vector.normalize(axises.front - center)

		return result
	end, types.table, "cubevolume"),

	get_quad = ftype:write(function(self: cubevolume, direction: enumitem): quad
		if direction == DirectionVariant.Right then
			return Quad:new({
				right = Triangle:from_vector(
					self.right + self.up + self.front,
					self.right + self.up + self.back,
					self.right + self.bottom + self.front
				),
				left = Triangle:from_vector(
					self.right + self.up + self.back,
					self.right + self.bottom + self.back,
					self.right + self.bottom + self.front
				),
			})
		elseif direction == DirectionVariant.Left then
			return Quad:new({
				right = Triangle:from_vector(
					self.left + self.up + self.front,
					self.left + self.bottom + self.front,
					self.left + self.up + self.back
				),
				left = Triangle:from_vector(
					self.left + self.up + self.back,
					self.left + self.bottom + self.front,
					self.left + self.bottom + self.back
				),
			})
		elseif direction == DirectionVariant.Up then
			return Quad:new({
				right = Triangle:from_vector(
					self.up + self.right + self.front,
					self.up + self.front + self.left,
					self.up + self.right + self.back
				),
				left = Triangle:from_vector(
					self.up + self.right + self.back,
					self.up + self.front + self.left,
					self.up + self.left + self.back
				),
			})
		elseif direction == DirectionVariant.Bottom then
			return Quad:new({
				right = Triangle:from_vector(
					self.bottom + self.right + self.front,
					self.bottom + self.right + self.back,
					self.bottom + self.left + self.front
				),
				left = Triangle:from_vector(
					self.bottom + self.right + self.back,
					self.bottom + self.left + self.back,
					self.bottom + self.left + self.front
				),
			})
		elseif direction == DirectionVariant.Front then
			return Quad:new({
				right = Triangle:from_vector(
					self.front + self.right + self.up,
					self.front + self.left + self.up,
					self.front + self.right + self.bottom
				),
				left = Triangle:from_vector(
					self.front + self.left + self.up,
					self.front + self.left + self.bottom,
					self.front + self.right + self.bottom
				),
			})
		elseif direction == DirectionVariant.Back then
			return Quad:new({
				right = Triangle:from_vector(
					self.back + self.right + self.up,
					self.back + self.right + self.bottom,
					self.back + self.left + self.up
				),
				left = Triangle:from_vector(
					self.back + self.left + self.up,
					self.back + self.right + self.bottom,
					self.back + self.left + self.bottom
				),
			})
		end

		return stdout:oute "unsupported DirectionVariant item" or Quad
	end, Quad.type, "cubevolume", EnumItem.type),

	to_vector = ftype:write(function(self: cubevolume): vector
		return vector.create(vector.magnitude(self.right), vector.magnitude(self.up), vector.magnitude(self.front))
	end, types.vector, "cubevolume"),

	to_basis = ftype:write(function(self: cubevolume): basis
		return Basis:new({
			position = self:get_center(),
			rotation = self:get_axises(),
		})
	end, types.vector, "cubevolume"),

	get_center = ftype:write(function(self: cubevolume): vector
		return (self.up + self.bottom + self.left + self.right + self.front + self.back) / 6
	end, types.vector, "cubevolume"),
})

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class
