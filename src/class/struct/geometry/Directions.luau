--!strict
--!native
--!optimize 2
const GeoVolume = require("@class/struct/geometry/GeoVolume")

const class : directions = GeoVolume:new {
    type = "directions",

    right = vector.zero,
    up = vector.zero,
    front = vector.zero,
}

return class