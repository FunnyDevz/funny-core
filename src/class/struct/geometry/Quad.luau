--!strict
--!native
--!optimize 2
const Struct = require("@class/core/Struct")
const Triangle = require("@class/struct/geometry/Triangle")
const types = require("@declare/types")
const ftype = require("@static/ftype")

const tname = "quad"
const class: quad = Struct:new({
	type = tname,

	left = Triangle:new(),
	right = Triangle:new(),

	get_center = ftype:write(function(self: quad): vector
		return (self.left:get_center() + self.right:get_center()) / 2
	end, types.vector, tname),

	get_normal_interpolated = ftype:write(function(self: quad): vector
		return vector.normalize((self.left:get_normal_interpolated() + self.right:get_normal_interpolated()))
	end, types.vector, tname),

	get_normal_geometric = ftype:write(function(self: quad): vector
		return vector.normalize((self.left:get_normal_geometric() + self.right:get_normal_geometric()))
	end, types.vector, tname),

	absolute = ftype:write(function(self: quad): quad
		const clone = self:clone({
			right = self.right:absolute(),
			left = self.left:absolute(),
		})

		return clone
	end, tname, tname),

	null = ftype:write(function(self: quad): quad
		const clone = self:clone({
			right = self.right:null(),
			left = self.left:null(),
		})

		return clone
	end, tname, tname),

	substract = ftype:write(function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:substract(with),
			left = self.left:substract(with),
		})

		return clone
	end, tname, tname, types.number),

	append = ftype:write(function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:append(with),
			left = self.left:append(with),
		})

		return clone
	end, tname, tname, types.number),

	multiple = ftype:write(function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:multiple(with),
			left = self.left:multiple(with),
		})

		return clone
	end, tname, tname, types.number),

	divide = ftype:write(function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:divide(with),
			left = self.left:divide(with),
		})

		return clone
	end, tname, tname, types.number),

	invert = ftype:write(function(self: quad): quad
		const clone = self:clone({
			right = self.right:invert(),
			left = self.left:invert(),
		})

		return clone
	end, tname, tname),

	negation = ftype:write(function(self: quad): quad
		const clone = self:clone({
			right = self.right:negation(),
			left = self.left:negation(),
		})

		return clone
	end, tname, tname),

	lerp = ftype:write(function(self: quad, to: quad, alpha: number): quad
		const clone = self:clone({
			right = self.right:lerp(to.right, alpha),
			left = self.left:lerp(to.left, alpha),
		})

		return clone
	end, tname, tname, tname, types.number),

	fuzzy_eq = ftype:write(function (self: quad, to: quad, epsilon: number?) : boolean
		return self.left:fuzzy_eq(to.left, epsilon) and self.right:fuzzy_eq(to.right, epsilon)
	end, types.boolean, tname, tname, ftype:opt(types.number)),

	normalize = ftype:write(function(self: quad): quad
		const clone = self:clone({
			right = self.right:normalize(),
			left = self.left:normalize(),
		})

		return clone
	end, tname, tname),

	infinity = ftype:write(function(self: quad): quad
		const clone = self:clone({
			right = self.right:infinity(),
			left = self.left:infinity(),
		})

		return clone
	end, tname, tname),
})

return class
