--!strict
--!native
--!optimize 2
const Struct = require("@class/core/Struct")
const Triangle = require("@class/struct/geometry/Triangle")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")



const class: quad = Struct:new({
	type = "quad",

	left = Triangle:new(),
	right = Triangle:new(),

	get_center = function(self: quad): vector
		return (self.left:get_center() + self.right:get_center()) / 2
	end,

	get_normal_interpolated = function(self: quad): vector
		return vector.normalize((self.left:get_normal_interpolated() + self.right:get_normal_interpolated()))
	end,

	get_normal_geometric = function(self: quad): vector
		return vector.normalize((self.left:get_normal_geometric() + self.right:get_normal_geometric()))
	end,

	absolute = function(self: quad): quad
		const clone = self:clone({
			right = self.right:absolute(),
			left = self.left:absolute(),
		})

		return clone
	end,

	null = function(self: quad): quad
		const clone = self:clone({
			right = self.right:null(),
			left = self.left:null(),
		})

		return clone
	end,

	substract = function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:substract(with),
			left = self.left:substract(with),
		})

		return clone
	end,

	append = function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:append(with),
			left = self.left:append(with),
		})

		return clone
	end,

	multiple = function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:multiple(with),
			left = self.left:multiple(with),
		})

		return clone
	end,

	divide = function(self: quad, with: number): quad
		const clone = self:clone({
			right = self.right:divide(with),
			left = self.left:divide(with),
		})

		return clone
	end,

	invert = function(self: quad): quad
		const clone = self:clone({
			right = self.right:invert(),
			left = self.left:invert(),
		})

		return clone
	end,

	negation = function(self: quad): quad
		const clone = self:clone({
			right = self.right:negation(),
			left = self.left:negation(),
		})

		return clone
	end,

	lerp = function(self: quad, to: quad, alpha: number): quad
		const clone = self:clone({
			right = self.right:lerp(to.right, alpha),
			left = self.left:lerp(to.left, alpha),
		})

		return clone
	end,

	fuzzy_eq = function (self: quad, to: quad, epsilon: number?) : boolean
		return self.left:fuzzy_eq(to.left, epsilon) and self.right:fuzzy_eq(to.right, epsilon)
	end,

	normalize = function(self: quad): quad
		const clone = self:clone({
			right = self.right:normalize(),
			left = self.left:normalize(),
		})

		return clone
	end,

	infinity = function(self: quad): quad
		const clone = self:clone({
			right = self.right:infinity(),
			left = self.left:infinity(),
		})

		return clone
	end,
})

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class
