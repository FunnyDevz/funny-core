--!strict
--!native
--!optimize 2
const GeoVolume = require("@class/struct/geometry/GeoVolume")
const types = require("@declare/types")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const class: triangle = (GeoVolume :: geovolume<triangle>):new({
	type = "triangle",
	right = vector.zero,
	up = vector.zero,
	front = vector.zero,

	from_vector = ftype:write(function(self: triangle, right: vector?, up: vector?, front: vector?): triangle
		return self:new({
			right = right,
			up = up,
			front = front,
		})
	end, "triangle", "triangle", ftype:opt(types.vector), ftype:opt(types.vector), ftype:opt(types.vector)),

	get_center = ftype:write(function(self: triangle): vector
		return (self.right + self.up + self.front) / 3
	end, types.vector, "triangle"),

	get_normal_interpolated = ftype:write(function(self: triangle): vector
		return vector.normalize(self.right + self.up + self.front)
	end, types.vector, "triangle"),

	get_normal_geometric = ftype:write(function(self: triangle): vector
		return vector.cross((self.up - self.right), (self.front - self.right))
	end, types.vector, "triangle"),
})

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class
