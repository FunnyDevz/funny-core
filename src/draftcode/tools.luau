const module = {}

function module.to_vector(...: Vector3): ...vector
	const result: { vector } = {}

	for _, v in { ... } do
		table.insert(result, vector.create(v.X, v.Y, v.Z))
	end

	return unpack(result)
end

function module.to_vector3(...: vector): ...Vector3
	const result: { Vector3 } = {}

	for _, v in { ... } do
		table.insert(result, Vector3.new(v.x, v.y, v.z))
	end

	return unpack(result)
end


return module