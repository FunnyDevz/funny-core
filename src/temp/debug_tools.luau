const debris = game:GetService("Debris")

const tools = require("./tools")


--[[
	DEBUG
]]
const DEBUG_ENABLED = true
const DEBUG_DRAW_TIME = 0.35
const DEBUG_FOLDER_NAME = "_FootIKDebug"

const DEBUG_RAY_COLOR = Color3.fromRGB(80, 170, 255)
const DEBUG_HIT_COLOR = Color3.fromRGB(255, 90, 90)
const DEBUG_NORMAL_COLOR = Color3.fromRGB(100, 255, 120)
const DEBUG_KNEE_COLOR = Color3.fromRGB(255, 210, 80)
const DEBUG_SELF_HIT_COLOR = Color3.fromRGB(255, 40, 40)

const DEBUG_LINE_THICKNESS = 0.035
const DEBUG_POINT_SIZE = 0.12

const module = {}

const debug_folder = if DEBUG_ENABLED
	then (workspace:FindFirstChild(DEBUG_FOLDER_NAME) or Instance.new("Folder"))
	else nil

if debug_folder then
	debug_folder.Name = DEBUG_FOLDER_NAME
	debug_folder.Parent = workspace
end

function module.debug_warn(message: string)
	if DEBUG_ENABLED then
		warn(`[FootIK] {message}`)
	end
end

function module.debug_check(condition: boolean, message: string): boolean
	if not condition then
		module.debug_warn(message)
	end

	return condition
end

function module.is_finite_vector(value_vector: Vector3 | vector): boolean
	local value: Vector3 = typeof(value_vector) == "Vector3" and value_vector or tools.to_vector3(value_vector)

	return value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < 1e9
		and math.abs(value.Y) < 1e9
		and math.abs(value.Z) < 1e9
end

function module.debug_line(from: vector, to: vector, color: Color3, transparency: number?)
	if not DEBUG_ENABLED or not debug_folder then
		return
	end

	const from3 = tools.to_vector3(from)
	const to3 = tools.to_vector3(to)

	const direction = to3 - from3
	const length = direction.Magnitude

	if length <= 1e-5 then
		return
	end

	const part = Instance.new("Part")
	part.Name = "Line"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = transparency or 0
	part.Color = color

	part.Size = Vector3.new(DEBUG_LINE_THICKNESS, DEBUG_LINE_THICKNESS, length)

	part.CFrame = CFrame.lookAt((from3 + to3) * 0.5, to3)

	part.Parent = debug_folder

	debris:AddItem(part, DEBUG_DRAW_TIME)
end

function module.debug_point(position: vector, color: Color3, size: number?)
	if not DEBUG_ENABLED or not debug_folder then
		return
	end

	const position3 = tools.to_vector3(position)

	const point = Instance.new("Part")
	point.Name = "Point"
	point.Shape = Enum.PartType.Ball
	point.Anchored = true
	point.CanCollide = false
	point.CanTouch = false
	point.CanQuery = false
	point.CastShadow = false
	point.Material = Enum.Material.Neon
	point.Transparency = 0
	point.Color = color

	const dimension = size or DEBUG_POINT_SIZE

	point.Size = Vector3.new(dimension, dimension, dimension)

	point.Position = position3
	point.Parent = debug_folder

	debris:AddItem(point, DEBUG_DRAW_TIME)
end

function module.debug_raycast(from: vector, to: vector, result: RaycastResult?, model: Model?, knee: vector?)
	if not DEBUG_ENABLED then
		return
	end

	if result then
		const hit_position = tools.to_vector(result.Position)
		const hit_instance = result.Instance

		const self_hit = model ~= nil and hit_instance:IsDescendantOf(model)

		module.debug_line(from, hit_position, if self_hit then DEBUG_SELF_HIT_COLOR else DEBUG_RAY_COLOR)
		module.debug_line(hit_position, to, DEBUG_HIT_COLOR, 0.75)
		module.debug_point(hit_position, if self_hit then DEBUG_SELF_HIT_COLOR else DEBUG_HIT_COLOR)

		const normal = tools.to_vector(result.Normal)
		const normal_end = hit_position + normal * 0.5

		module.debug_line(hit_position, normal_end, DEBUG_NORMAL_COLOR)

		if knee then
			module.debug_point(knee, DEBUG_KNEE_COLOR)
			module.debug_line(hit_position, knee, DEBUG_KNEE_COLOR)
		end

		if self_hit then
			module.debug_warn(`raycast hit own character: {hit_instance:GetFullName()}`)
		end
	else
		module.debug_line(from, to, DEBUG_RAY_COLOR)
		module.debug_point(to, DEBUG_HIT_COLOR)
	end
end

return module