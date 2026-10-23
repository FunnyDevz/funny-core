--!strict
--!native
--!optimize 2
const Struct = require("@class/core/Struct")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const types = require("@declare/types")
const geometry = require("@project/geometry")
const ftype = require("@static/ftype")

const class : geovolume = Struct:new {
    type = "geovolume",

    absolute = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.abs(value)
        end))

        return clone
    end, "geovolume", "geovolume"),

    null = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.zero
        end))

        return clone
    end, "geovolume", "geovolume"),

    substract = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.create(value.x - with, value.y - with, value.z - with)
        end))
        
        return clone
    end, "geovolume", "geovolume", types.number),

    append = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.create(value.x + with, value.y + with, value.z + with)
        end))
        
        return clone
    end, "geovolume", "geovolume", types.number),

    multiple = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return value * with
        end))

        return clone
    end, "geovolume", "geovolume", types.number),

    divide = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return value / with
        end))
        
        return clone
    end, "geovolume", "geovolume", types.number),

    invert = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return -value
        end))
        
        return clone
    end, "geovolume", "geovolume"),

    normalize = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.normalize(value)
        end))
        
        return clone
    end, "geovolume", "geovolume"),

    infinity = ftype:write(function(self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.create(math.huge, math.huge, math.huge)
        end))

        return clone
    end, "geovolume", "geovolume"),

    fuzzy_eq = ftype:write(function (self: geovolume, to: geovolume, epsilon: number?) : boolean
        const epsilon = epsilon or geometry.fuzzy_eq_diff

        const compare1 = self:each<<vector>>(types.vector, function(value: vector): vector
            return value
        end)

        const compare2 = to:each<<vector>>(types.vector, function(value: vector): vector
            return value
        end)

        for i, v in compare1 do
            const j = compare2[i]
            if j then
                const delta = (v - j)
                if vector.dot(delta, delta) > epsilon * epsilon then
                    return false
                end
            end
        end
        
        return true
    end, types.boolean, "geovolume", "geovolume", ftype:opt(types.number)),

    negation = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return -vector.abs(value)
        end))

        return clone
    end, "geovolume", "geovolume"),

    lerp = ftype:write(function (self: geovolume, to: geovolume, alpha: number) : geovolume
        const result: {[unknown]: vector} = {}

        const compare1 = self:each<<vector>>(types.vector, function(value: vector): vector
            return value
        end)

        const compare2 = to:each<<vector>>(types.vector, function(value: vector): vector
            return value
        end)

        for i, v in compare1 do
            const j = compare2[i]
            if j then
                result[i] = vector.lerp(v, j, alpha)
            end
        end

        return self:clone(result)
    end, "geovolume", "geovolume", "geovolume", types.number)
}

ctype:read(class):write_tag(ctags.geometry, ctags.struct)


return class