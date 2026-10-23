--!strict

--[[ 
	this is a Script draft
		- draft of IKR6Legs class
]]

const players = game:GetService("Players")
const runservice = game:GetService("RunService")

const tools = require("./tools")

const STEP_TORSO_ALPHA = 0

const STEP_FORWARD = 0.1
const IDLE_TIME = 0.35
const STAND_FORWARD = 0.1

const FOOT_SETTLE_ANGLE = math.rad(2)

const STEP_BLOCK_DISTANCE = 0.45
const STEP_MAX_HEIGHT = 0.65
const STEP_OBSTACLE_HEIGHT = 0.12

const IDLE_STEP_FORWARD = 0

const STEP_SPEED_MIN = 5
const STEP_SPEED_MAX = 80

const STEP_VELOCITY_MIN = 0
const STEP_VELOCITY_MAX = 32

const SETTLE_SPEED_MIN = 10
const SETTLE_SPEED_MAX = 150

const PLANTED_SPEED = 50

const LEG_FOLLOW_SPEED = 15
const LEG_ROTATION_INV_COEF = 0.5

const PREDICTION_TIME_MIN = 0.01
const PREDICTION_TIME_MAX = 0.1
const PREDICTION_CURVE = 1.1

--[==[
	Глубина расстояния между точками рейкаста относительно bottom-torso определяется
	как `s - LEG_FROM_COEF_DIFF`, где s - отрицательное или положительное соответствующее
	как Left/Right или cframe.X (right) и -cframe.X (left)
]==]
const LEG_FROM_COEF_DIF = 0.4

const RAYCAST_UP = 1
const RAYCAST_DOWN = 2

type FootPhase = "planted" | "stepping" | "settling"

type FootState = {
	read origin: BasePart,
	read part: BasePart,

	target: CFrame,
	contact: vector,

	read diff: number,
	phase: FootPhase,
}

type CharacterState = {
	read character: Model,
	read humanoid: Humanoid,
	read torso: BasePart,

	left: FootState,
	right: FootState,

	active: FootState,
	idle_time: number,
	fallback: boolean,
}

const SIGNAL: RBXScriptSignal<number> = runservice.Heartbeat
const STATES = {}

const function get_limb(character: Humanoid, model: Model, limb: Enum.Limb): BasePart
	for _, v in model:GetChildren() do
		if v:IsA("BasePart") and character:GetLimb(v) == limb then
			return v
		end
	end

	error(`cannot find limb {limb.Name} in {model:GetFullName()}`)
end

const function get_foots(character: Humanoid, model: Model): { left: BasePart, right: BasePart }
	return {
		left = get_limb(character, model, Enum.Limb.LeftLeg),
		right = get_limb(character, model, Enum.Limb.RightLeg),
	}
end

const function get_torso(character: Humanoid, model: Model): BasePart
	return get_limb(character, model, Enum.Limb.Torso)
end

const function get_humanoid(character: Model): Humanoid
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		for i = 1, 3 do
			task.wait(i)
			humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				break
			end
		end
	end

	return humanoid :: Humanoid
end

const function get_bottom(torso: BasePart, diff: number): vector
	const position = tools.to_vector(torso.Position)
	const right = tools.to_vector(torso.CFrame.RightVector)

	return position + vector.create(0, -torso.Size.Y / 2, 0) + right * diff
end

const function create_rayparams(model: Model): RaycastParams
	const rayparams = RaycastParams.new()

	rayparams.FilterType = Enum.RaycastFilterType.Exclude
	rayparams.RespectCanCollide = true
	rayparams.BruteForceAllSlow = false
	rayparams.IgnoreWater = true

	rayparams.ExcludeInstances = model:GetDescendants()

	return rayparams
end

const function raycast(origin: vector, direction: vector, params: RaycastParams?): RaycastResult?
	const safe_origin = origin + direction * 0.01

	return workspace:Raycast(tools.to_vector3(safe_origin), tools.to_vector3(direction), params)
end

const function get_step_raycast(
	from: vector,
	torso: BasePart,
	move_dir: vector,
	forward_distance: number
): (vector, vector)
	const cframe = torso.CFrame

	const up = tools.to_vector(cframe.UpVector)
	const down = -up

	const move_length = vector.magnitude(move_dir)

	local horizontal_direction: vector

	if move_length > 0.001 then
		horizontal_direction = move_dir / move_length
	else
		horizontal_direction = tools.to_vector(cframe.LookVector)
	end

	const origin = from + up * RAYCAST_UP
	const direction = horizontal_direction * forward_distance + down * (RAYCAST_UP + RAYCAST_DOWN)

	return origin, direction
end

const function cross(a: vector, b: vector): vector
	return vector.create(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

const function get_horizontal_velocity(humanoid: Humanoid): vector
	const root = humanoid.RootPart

	if not root then
		return vector.zero
	end

	const velocity = tools.to_vector(root.AssemblyLinearVelocity)

	return vector.create(velocity.x, 0, velocity.z)
end

const function get_speed_factor(humanoid: Humanoid): number
	const speed = vector.magnitude(get_horizontal_velocity(humanoid))
	const walk_speed = math.max(humanoid.WalkSpeed, 0.001)

	const factor = speed / walk_speed

	return math.clamp(factor, 0, 1)
end

const function is_step_blocked(
	foot: FootState,
	torso: BasePart,
	bottom: vector,
	move_direction: vector,
	params: RaycastParams
): boolean
	const move_length = vector.magnitude(move_direction)

	if move_length <= 1e-5 then
		return false
	end

	const direction = move_direction / move_length
	const up = tools.to_vector(torso.CFrame.UpVector)

	-- Проверяем, есть ли прямо перед ногой вертикальное препятствие.
	const obstacle_origin = bottom + up * STEP_OBSTACLE_HEIGHT
	const obstacle = raycast(obstacle_origin, direction * STEP_BLOCK_DISTANCE, params)

	if not obstacle then
		return false
	end

	const normal = tools.to_vector(obstacle.Normal)

	-- Наклонная/горизонтальная поверхность не считается стеной.
	if math.abs(vector.dot(normal, up)) > 0.5 then
		return false
	end

	-- Ищем верх препятствия в пределах допустимой высоты.
	const top_origin = tools.to_vector(obstacle.Position)
		+ direction * (foot.part.Size.Z * 0.5 + 0.05)
		+ up * (STEP_MAX_HEIGHT + 0.05)

	const top_result = raycast(top_origin, -up * (STEP_MAX_HEIGHT + 0.15), params)

	if not top_result then
		return true
	end

	const top_normal = tools.to_vector(top_result.Normal)

	if vector.dot(top_normal, up) < 0.7 then
		return true
	end

	const height = vector.dot(tools.to_vector(top_result.Position) - bottom, up)

	return height > STEP_MAX_HEIGHT
end

const function get_plant_target(foot: FootState, torso: BasePart): CFrame
	const part = foot.part
	const half_height = part.Size.Y * 0.5
	const contact = foot.contact
	const out_point = get_bottom(torso, foot.diff)
	local up = tools.to_vector(part.CFrame.UpVector)

	for _ = 1, 2 do
		const center = contact + up * half_height

		const direction = out_point - center
		const length = vector.magnitude(direction)

		if length <= 1e-5 then
			return part.CFrame
		end

		up = direction / length
	end

	local forward = out_point - tools.to_vector(torso.Position)

	forward = forward - up * vector.dot(forward, up)

	if vector.magnitude(forward) <= 1e-5 then
		return part.CFrame
	end

	forward = vector.normalize(forward)

	const right = vector.normalize(cross(forward, up))
	const back = vector.normalize(cross(right, up))
	const center = contact + up * half_height
	const center3, right3, up3, back3 = tools.to_vector3(center, right, up, back)

	return CFrame.fromMatrix(center3, right3, up3, back3)
end

const function get_knee_pos(
	of: vector,
	rayresult: RaycastResult,
	up: vector,
	move_dir: vector,
	facing_dir: vector
): vector
	const foot = tools.to_vector(rayresult.Position)
	const normal = tools.to_vector(rayresult.Normal)

	const leg = foot - of
	const distance = vector.magnitude(leg)

	if distance <= 1e-5 then
		return foot
	end

	const leg_dir = vector.normalize(leg)
	const move_flat = vector.create(move_dir.x, 0, move_dir.z)
	const facing_flat = vector.create(facing_dir.x, 0, facing_dir.z)

	const has_move = vector.magnitude(move_flat) > 1e-5

	const desired = if has_move
		then vector.normalize(move_flat)
		else if vector.magnitude(facing_flat) > 1e-5 then vector.normalize(facing_flat) else vector.zero

	const pole = desired - leg_dir * vector.dot(desired, leg_dir)
	const pole_dir = if vector.magnitude(pole) > 1e-5 then vector.normalize(pole) else vector.zero
	const blended_up = vector.lerp(up, normal, 0.2)
	const bend_up = if vector.magnitude(blended_up) > 1e-5 then vector.normalize(blended_up) else vector.normalize(up)

	const midpoint = of + leg * 0.5
	const half = distance * 0.5
	const pole_length = if has_move then half else distance * 0.1

	return midpoint + pole_dir * pole_length + bend_up * half
end

const function get_foot_facing(torso: BasePart, move_dir: vector): vector
	const torso_facing = tools.to_vector(torso.CFrame.LookVector)

	if vector.magnitude(move_dir) <= 1e-5 then
		return torso_facing
	end

	const move = vector.normalize(move_dir)
	const facing = vector.normalize(torso_facing)

	if vector.dot(move, facing) < LEG_ROTATION_INV_COEF then
		return facing
	end

	return move
end

const function get_leg_cframe(leg: BasePart, torso: BasePart, foot: vector, knee: vector, move_dir: vector): CFrame
	const torso_cframe = torso.CFrame
	const torso_inverse = torso_cframe:Inverse()
	const foot_local = tools.to_vector(torso_inverse:PointToWorldSpace(tools.to_vector3(foot)))
	const knee_local = tools.to_vector(torso_inverse:PointToWorldSpace(tools.to_vector3(knee)))
	const direction = knee_local - foot_local
	const length = vector.magnitude(direction)

	if length <= 1e-5 then
		return leg.CFrame
	end

	const up = direction / length
	const facing_dir = get_foot_facing(torso, move_dir)
	const facing_local = tools.to_vector(torso_inverse:VectorToWorldSpace(tools.to_vector3(facing_dir)))

	const torso_fwd_local = vector.create(0, 0, -1)
	const blended_fwd = vector.normalize(vector.lerp(facing_local, torso_fwd_local, STEP_TORSO_ALPHA))
	local forward = blended_fwd - up * vector.dot(blended_fwd, up)

	if vector.magnitude(forward) <= 1e-5 then
		const fallback = vector.create(1, 0, 0)

		forward = fallback - up * vector.dot(fallback, up)

		if vector.magnitude(forward) <= 1e-5 then
			return leg.CFrame
		end
	end

	forward = vector.normalize(forward)

	const right = vector.normalize(cross(forward, up))
	const back = vector.normalize(cross(right, up))

	const center = foot_local + up * (leg.Size.Y * 0.5)

	const center3, right3, up3, back3 = tools.to_vector3(center, right, up, back)

	const local_cframe = CFrame.fromMatrix(center3, right3, up3, back3)

	return torso_cframe * local_cframe
end

const function get_step_speed(humanoid: Humanoid): number
	const velocity = get_horizontal_velocity(humanoid)
	const speed = vector.magnitude(velocity)

	const factor =
		math.clamp((speed - STEP_VELOCITY_MIN) / math.max(STEP_VELOCITY_MAX - STEP_VELOCITY_MIN, 0.001), 0, 1)

	return STEP_SPEED_MIN + (STEP_SPEED_MAX - STEP_SPEED_MIN) * factor
end

const function get_settle_speed(humanoid: Humanoid): number
	const factor = get_speed_factor(humanoid)

	return SETTLE_SPEED_MIN + (SETTLE_SPEED_MAX - SETTLE_SPEED_MIN) * factor
end

const function step(character: Humanoid, model: Model, foot: FootState, torso: BasePart): (CFrame?, boolean)
	const move_direction = tools.to_vector(character.MoveDirection)
	const bottom = get_bottom(torso, foot.diff)
	const velocity = get_horizontal_velocity(character)
	const speed_factor = get_speed_factor(character)
	const prediction_factor = speed_factor ^ PREDICTION_CURVE
	const prediction_time = PREDICTION_TIME_MIN + (PREDICTION_TIME_MAX - PREDICTION_TIME_MIN) * prediction_factor
	const predicted_bottom = bottom + velocity * prediction_time
	const foot_facing = get_foot_facing(torso, move_direction)
	const params = create_rayparams(model)

	if is_step_blocked(foot, torso, predicted_bottom, move_direction, params) then
		return nil, true
	end

	const ray_origin, ray_direction = get_step_raycast(predicted_bottom, torso, move_direction, STEP_FORWARD)

	const ray_result = raycast(ray_origin, ray_direction, params)

	if not ray_result then
		return nil, false
	end

	const knee_pos = get_knee_pos(
		bottom,
		ray_result,
		tools.to_vector(torso.CFrame.UpVector),
		foot_facing,
		tools.to_vector(torso.CFrame.LookVector)
	)

	return get_leg_cframe(foot.part, torso, tools.to_vector(ray_result.Position), knee_pos, foot_facing), false
end

const function stand(
	character: Humanoid,
	model: Model,
	leg: BasePart,
	torso: BasePart,
	diff: number,
	forward_distance: number?
): CFrame?
	const move_direction = vector.zero
	const bottom = get_bottom(torso, diff)

	const ray_origin, ray_direction = get_step_raycast(bottom, torso, move_direction, forward_distance or STAND_FORWARD)

	const params = create_rayparams(model)
	const ray_result = raycast(ray_origin, ray_direction, params)

	if not ray_result then
		return nil
	end

	const up = tools.to_vector(torso.CFrame.UpVector)
	const facing = tools.to_vector(torso.CFrame.LookVector)

	const knee_pos = get_knee_pos(bottom, ray_result, up, vector.zero, facing)

	return get_leg_cframe(leg, torso, tools.to_vector(ray_result.Position), knee_pos, vector.zero)
end

const function character_added(character: Model)
	const humanoid = get_humanoid(character)

	const legs = get_foots(humanoid, character)
	const torso = get_torso(humanoid, character)

	const origin_left = legs.left
	const origin_right = legs.right

	const clone_left = origin_left:Clone()
	const clone_right = origin_right:Clone()

	origin_left.Transparency = 1
	origin_right.Transparency = 1
	--torso.Transparency = 0.95
	--clone_left.Transparency = 0.5
	--clone_right.Transparency = 0.5

	clone_left.Anchored = true
	clone_left.CanCollide = false
	clone_left.CanQuery = false
	clone_left.CanTouch = false
	clone_left.Name ..= "_VIS"

	clone_right.Anchored = true
	clone_right.CanCollide = false
	clone_right.CanQuery = false
	clone_right.CanTouch = false
	clone_right.Name ..= "_VIS"

	clone_left.Parent = character
	clone_right.Parent = character

	local left: FootState = {
		origin = origin_left,
		part = clone_left,
		target = clone_left.CFrame,
		contact = tools.to_vector(clone_left.Position),
		diff = -(1 - LEG_FROM_COEF_DIF),
		phase = "planted",
	}

	local right: FootState = {
		origin = origin_right,
		part = clone_right,
		target = clone_right.CFrame,
		contact = tools.to_vector(clone_right.Position),
		diff = 1 - LEG_FROM_COEF_DIF,
		phase = "planted",
	}

	STATES[character] = {
		character = character,
		humanoid = humanoid,
		torso = torso,

		left = left,
		right = right,

		active = left,
		idle_time = 0,
		fallback = false,
	}
end

const function begin_step(foot: FootState, target: CFrame)
	foot.target = target

	-- Нижняя поверхность ноги должна остаться в точке raycast.
	const position = tools.to_vector(target.Position)
	const up = tools.to_vector(target.UpVector)

	foot.contact = position - up * (foot.part.Size.Y * 0.5)
	foot.phase = "stepping"
end

const function begin_idle_step(state: CharacterState): boolean
	const active = state.active
	const other = if active == state.left then state.right else state.left

	if active.phase ~= "planted" then
		return false
	end

	const target = stand(state.humanoid, state.character, other.part, state.torso, other.diff, IDLE_STEP_FORWARD)

	if not target then
		return false
	end

	begin_step(other, target)
	state.active = other

	return true
end

const function begin_fallback(state: CharacterState)
	state.fallback = true

	state.left.phase = "planted"
	state.right.phase = "planted"

	state.left.target = state.left.origin.CFrame
	state.right.target = state.right.origin.CFrame

	state.left.part.CFrame = state.left.origin.CFrame
	state.right.part.CFrame = state.right.origin.CFrame
end

const function is_step_finished(foot: FootState): boolean
	const position_delta = foot.target.Position - foot.part.Position

	if position_delta.Magnitude > 0.05 then
		return false
	end

	const current_up = foot.part.CFrame.UpVector
	const target_up = foot.target.UpVector

	return math.acos(math.clamp(current_up:Dot(target_up), -1, 1)) <= math.rad(5)
end

const function is_settle_finished(foot: FootState, target: CFrame): boolean
	const current_up = foot.part.CFrame.UpVector
	const target_up = target.UpVector

	const up_dot = math.clamp(current_up:Dot(target_up), -1, 1)

	return math.acos(up_dot) <= FOOT_SETTLE_ANGLE
end

const function get_origin_contact(foot: FootState): vector
	const origin = foot.origin
	const up = tools.to_vector(origin.CFrame.UpVector)

	return tools.to_vector(origin.Position) - up * (foot.part.Size.Y * 0.5)
end

const function solve_fallback(state: CharacterState)
	for _, foot in { state.left, state.right } do
		const origin_cframe = foot.origin.CFrame

		foot.phase = "planted"
		foot.target = origin_cframe
		foot.contact = get_origin_contact(foot)

		foot.part.CFrame = origin_cframe
	end
end

const function solve_foot(foot: FootState, torso: BasePart, delta: number, humanoid: Humanoid)
	local alpha = 1 - math.exp(-LEG_FOLLOW_SPEED * delta)

	if foot.phase == "stepping" then
		const step_speed = get_step_speed(humanoid)
		alpha = 1 - math.exp(-step_speed * delta)
		const current = foot.part.CFrame
		const target = foot.target

		const next = current:Lerp(target, alpha)

		const offset = target.Position - next.Position
		const horizontal = Vector3.new(offset.X, 0, offset.Z)

		const distance = horizontal.Magnitude
		const lift = math.min(distance, 1)

		const position = Vector3.new(next.Position.X, target.Position.Y + lift, next.Position.Z)

		foot.part.CFrame = CFrame.new(position) * next.Rotation

		if is_step_finished(foot) then
			foot.phase = "settling"
		end

		return
	end

	if foot.phase == "settling" then
		const settle_speed = get_settle_speed(humanoid)
		alpha = 1 - math.exp(-settle_speed * delta)
		const target = get_plant_target(foot, torso)

		foot.target = target

		const current = foot.part.CFrame
		const next = current:Lerp(target, alpha)

		foot.part.CFrame = next

		if is_settle_finished(foot, target) then
			foot.phase = "planted"
		end

		return
	end

	alpha = 1 - math.exp(-PLANTED_SPEED * delta)
	const target = get_plant_target(foot, torso)

	foot.target = target
	foot.part.CFrame = foot.part.CFrame:Lerp(target, alpha)
end

SIGNAL:Connect(function(delta: number)
	for character, state in STATES do
		if not character.Parent then
			STATES[character] = nil
			continue
		end

		const move_direction = tools.to_vector(state.humanoid.MoveDirection)
		const is_moving = vector.magnitude(move_direction) >= 0.01

		if is_moving then
			state.idle_time = 0
		else
			state.idle_time += delta
		end

		if state.fallback then
			solve_fallback(state)
		else
			solve_foot(state.left, state.torso, delta, state.humanoid)
			solve_foot(state.right, state.torso, delta, state.humanoid)
		end

		if not is_moving and state.idle_time >= IDLE_TIME then
			if state.left.phase == "planted" then
				const target = stand(state.humanoid, state.character, state.left.part, state.torso, state.left.diff)

				if target then
					state.left.target = target
					state.left.contact = tools.to_vector(target.Position)
						- tools.to_vector(target.UpVector) * (state.left.part.Size.Y * 0.5)
				end
			end

			if state.right.phase == "planted" then
				const target = stand(state.humanoid, state.character, state.right.part, state.torso, state.right.diff)

				if target then
					state.right.target = target
					state.right.contact = tools.to_vector(target.Position)
						- tools.to_vector(target.UpVector) * (state.right.part.Size.Y * 0.5)
				end
			end

			continue
		end

		if not is_moving then
			continue
		end

		const active = state.active
		const other = if active == state.left then state.right else state.left

		if active.phase ~= "planted" then
			continue
		end

		const target, blocked = step(state.humanoid, state.character, other, state.torso)

		if blocked then
			if not begin_idle_step(state) then
				begin_fallback(state)
			end

			continue
		end

		if not target then
			begin_fallback(state)
			continue
		end

		state.fallback = false

		begin_step(other, target)
		state.active = other
	end
end)

const function player_added(player: Player)
	player.CharacterAdded:Connect(character_added)

	if player.Character then
		character_added(player.Character)
	end
end

do
	for _, v in players:GetPlayers() do
		player_added(v)
	end

	players.PlayerAdded:Connect(player_added)
end
