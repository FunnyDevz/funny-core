--!strict

return table.freeze {
    raycast = function (origin: vector, direction: vector, params: RaycastParams?): RaycastResult?
        const origin_engine: Vector3 = Vector3.new(origin.x, origin.y, origin.z)
        const direction_engine: Vector3 = Vector3.new(direction.x, direction.y, direction.z)

        return workspace:Raycast(origin_engine + direction_engine * 0.01, direction_engine, params)
    end,

    to_vector = function(...: Vector3): ...vector
        const result: { vector } = {}

        for _, v in { ... } do
            table.insert(result, vector.create(v.X, v.Y, v.Z))
        end

        return unpack(result)
	end,

	to_vector3 = function(...: vector): ...Vector3
        const result: { Vector3 } = {}

        for _, v in { ... } do
            table.insert(result, Vector3.new(v.x, v.y, v.z))
        end

        return unpack(result)
	end,
}