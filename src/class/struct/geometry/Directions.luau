--!strict
--!native
--!optimize 2
const GeoVolume = require("@class/struct/geometry/GeoVolume")
const types = require("@declare/types")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const class : directions = GeoVolume:new {
    type = "directions",

    right = vector.zero,
    up = vector.zero,
    front = vector.zero,

    to_vector = ftype:write(function (self: directions) : vector
        return vector.create(vector.magnitude(self.right), vector.magnitude(self.up), vector.magnitude(self.front))
    end, types.vector, "directions"),
}

ctype:read(class):write_tag(ctags.geometry, ctags.struct)

return class