--!strict
--!native
--!optimize 2
const Struct = require("@class/core/Struct")
const types = require("@declare/types")
const geometry = require("@project/geometry")
const ftype = require("@static/ftype")

const tname = "geovolume"
const class : geovolume = Struct:new {
    type = tname,

    absolute = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.abs(value)
        end))

        return clone
    end, tname, tname),

    null = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.zero
        end))

        return clone
    end, tname, tname),

    substract = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.create(value.x - with, value.y - with, value.z - with)
        end))
        
        return clone
    end, tname, tname, types.number),

    append = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.create(value.x + with, value.y + with, value.z + with)
        end))
        
        return clone
    end, tname, tname, types.number),

    multiple = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return value * with
        end))

        return clone
    end, tname, tname, types.number),

    divide = ftype:write(function (self: geovolume, with: number) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return value / with
        end))
        
        return clone
    end, tname, tname, types.number),

    invert = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return -value
        end))
        
        return clone
    end, tname, tname),

    normalize = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.normalize(value)
        end))
        
        return clone
    end, tname, tname),

    infinity = ftype:write(function(self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return vector.create(math.huge, math.huge, math.huge)
        end))

        return clone
    end, tname, tname),

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
    end, types.boolean, tname, tname, ftype:opt(types.number)),

    negation = ftype:write(function (self: geovolume) : geovolume
        const clone = self:clone(self:each<<vector>>(types.vector, function(value: vector): vector
            return -vector.abs(value)
        end))

        return clone
    end, tname, tname),

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
    end, tname, tname, tname, types.number)
}

return class