--!strict

--[[
	this is a Script draft
		- draft of IKR6Arms
]]

const players = game:GetService("Players")
const runservice = game:GetService("RunService")

const tools = require("./tools")

--[[
	CONFIG
		Настройки поведения решателя и его релевантного функционала.
		Всё, что влияет на позу, скорость или переключение состояний,
		должно настраиваться здесь, а не в теле алгоритма.
]]

-- Общие настройки решателя.
const MAX_DELTA = 1 / 15

const SHOULDER_FORWARD_DIFF = 0
const SHOULDER_SIDE_COEF = 0.5
const SHOULDER_UP_COEF = 0.5

const ARM_FOLLOW_SPEED = 14
const ARM_FAST_FOLLOW_SPEED = 26
const ARM_TAKE_FOLLOW_SPEED = 20
const ARM_HOLD_FOLLOW_SPEED = 24

const ARM_DIRECTION_EPSILON = 1e-5

-- Настройки состояния idle.
const IDLE_UP_DIFF = 0
const IDLE_LEFT_DIFF = 0.06
const IDLE_RIGHT_DIFF = 0.06
const IDLE_FORWARD_DIFF = 0.02
const IDLE_SWAY_AMPLITUDE = 0.03
const IDLE_SWAY_FREQUENCY = 1.1

-- Настройки состояния walk.
const WALK_STATE_MIN_SPEED = 0.6
const WALK_STATE_MIN_INPUT = 0.01
const WALK_SPEED_REFERENCE = 16
const RUN_SPEED_REFERENCE = 32
const WALK_SWING_MIN = 0.22
const WALK_SWING_MAX = 1.05
const WALK_FREQUENCY_MIN = 4.5
const WALK_FREQUENCY_MAX = 11.5
const WALK_SIDE_OUT = 0.04
const RUN_FORWARD_BIAS = 0.18
const RUN_SIDE_OUT = 0.05
const RUN_UP_BIAS = 0.12
const RUN_FREQUENCY_BONUS = 3.5

-- Настройки состояния jump.
const JUMP_UP = 1
const JUMP_FORWARD = 0.04
const JUMP_SIDE_OUT = 0.16
const JUMP_SWAY = 0.04
const JUMP_SWAY_FREQUENCY = 5

-- Настройки состояния fly.
const FLY_LIFT = 0.88
const FLY_FORWARD = 0.18
const FLY_SIDE_OUT = 0.18
const FLY_SWAY = 0.12
const FLY_SWAY_FREQUENCY = 3
const FLY_FALLING_REFERENCE = 28
const FLY_FALL_LOWER = 0.28
const FLY_LANDING_SPREAD = 0.32

-- Настройки состояния hold.
-- Дистанции кистей вдоль линии target_root -> target.
const HOLD_RIGHT_HAND_DISTANCE = 0.15
const HOLD_LEFT_HAND_DISTANCE = 0.95
const HOLD_REACTION_SIDE = 0.035
const HOLD_REACTION_UP = 0.025
const HOLD_REACTION_FREQUENCY = 2.4
const HOLD_REACTION_PHASE = math.pi

-- Служебные настройки.
const SEARCH_HUMANOID_ATTEMPTS = 3
const ARM_VISUAL_SUFFIX = "_VIS"

-- Идентификаторы состояний.
const STATE_IDLE = "idle"
const STATE_WALK = "walk"
const STATE_JUMP = "jump"
const STATE_FLY = "fly"
const STATE_TAKE = "take"
const STATE_HOLD = "hold"

type SolverState = "idle" | "walk" | "jump" | "fly" | "take" | "hold"
type ArmSide = "left" | "right"

type ArmState = {
	read origin: BasePart,
	read part: BasePart,
	read side: ArmSide,
	read sign: number,
	read origin_transparency: number,

	target: CFrame,
	hand: vector,
	take_target: vector?,
}

type TorsoData = {
	read position: vector,
	read right: vector,
	read up: vector,
	read look: vector,
	read half_x: number,
	read half_y: number,
}

type CharacterState = {
	read character: Model,
	read humanoid: Humanoid,
	read torso: BasePart,

	left: ArmState,
	right: ArmState,

	state: SolverState,
	manual_state: SolverState?,
	state_time: number,
	elapsed: number,
	walk_phase: number,

	hold_target: vector?,
	hold_root: vector?,
}

const SIGNAL: RBXScriptSignal<number> = runservice.Heartbeat
const STATES: { [Model]: CharacterState } = {}

const VALID_STATES: { [string]: boolean } = table.freeze({
	[STATE_IDLE] = true,
	[STATE_WALK] = true,
	[STATE_JUMP] = true,
	[STATE_FLY] = true,
	[STATE_TAKE] = true,
	[STATE_HOLD] = true,
})

const function find_limb(humanoid: Humanoid, model: Model, limb: Enum.Limb): BasePart?
	for _, v in model:GetChildren() do
		if v.Name:sub(-#ARM_VISUAL_SUFFIX) == ARM_VISUAL_SUFFIX then
			continue
		end

		if v:IsA("BasePart") and humanoid:GetLimb(v) == limb then
			return v
		end
	end

	return nil
end

const function get_humanoid(character: Model): Humanoid?
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		for i = 1, SEARCH_HUMANOID_ATTEMPTS do
			task.wait(i)
			humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				break
			end
		end
	end

	return humanoid
end

const function get_velocity(humanoid: Humanoid): vector
	const root = humanoid.RootPart

	if not root then
		return vector.zero
	end

	return tools.to_vector(root.AssemblyLinearVelocity)
end

const function get_speed_data(humanoid: Humanoid): (vector, number, number, number)
	const velocity = get_velocity(humanoid)
	const horizontal = vector.create(velocity.x, 0, velocity.z)
	const speed = vector.magnitude(horizontal)
	const speed_factor = math.clamp(speed / WALK_SPEED_REFERENCE, 0, 1)
	const run_factor = math.clamp(
		(speed - WALK_SPEED_REFERENCE) / math.max(RUN_SPEED_REFERENCE - WALK_SPEED_REFERENCE, 0.001),
		0,
		1
	)

	return velocity, speed, speed_factor, run_factor
end

const function get_torso_data(torso: BasePart): TorsoData
	const cframe = torso.CFrame
	const size = torso.Size

	return {
		position = tools.to_vector(cframe.Position),
		right = tools.to_vector(cframe.RightVector),
		up = tools.to_vector(cframe.UpVector),
		look = tools.to_vector(cframe.LookVector),
		half_x = size.X * SHOULDER_SIDE_COEF,
		half_y = size.Y * SHOULDER_UP_COEF,
	}
end

const function get_shoulder(arm: ArmState, torso: TorsoData): vector
	const side_offset = torso.half_x + arm.part.Size.X * 0.5

	return torso.position
		+ torso.right * (arm.sign * side_offset)
		+ torso.up * torso.half_y
		+ torso.look * SHOULDER_FORWARD_DIFF
end

const function get_idle_hand(
	state: CharacterState,
	arm: ArmState,
	shoulder: vector,
	torso: TorsoData
): vector
	const phase = state.elapsed * IDLE_SWAY_FREQUENCY + (if arm.side == "left" then 0 else math.pi)
	const sway = math.sin(phase) * IDLE_SWAY_AMPLITUDE
	const side_diff = if arm.side == "left" then IDLE_LEFT_DIFF else IDLE_RIGHT_DIFF
	const direction = -torso.up
		+ torso.up * IDLE_UP_DIFF
		+ torso.right * (arm.sign * side_diff)
		+ torso.look * IDLE_FORWARD_DIFF
		+ torso.up * sway

	return shoulder + vector.normalize(direction) * arm.part.Size.Y
end

const function get_walk_hand(
	state: CharacterState,
	arm: ArmState,
	shoulder: vector,
	torso: TorsoData,
	speed_factor: number,
	run_factor: number
): vector
	const phase = state.walk_phase + (if arm.side == "left" then 0 else math.pi)
	const swing = WALK_SWING_MIN + (WALK_SWING_MAX - WALK_SWING_MIN) * speed_factor
	const angle = math.sin(phase) * swing + run_factor * RUN_FORWARD_BIAS
	const down = -torso.up
	const direction = down * math.cos(angle)
		+ torso.look * math.sin(angle)
		+ torso.up * (run_factor * RUN_UP_BIAS)
		+ torso.right * (arm.sign * (WALK_SIDE_OUT + run_factor * RUN_SIDE_OUT))

	return shoulder + vector.normalize(direction) * arm.part.Size.Y
end

const function get_jump_hand(
	state: CharacterState,
	arm: ArmState,
	shoulder: vector,
	torso: TorsoData
): vector
	const phase = state.state_time * JUMP_SWAY_FREQUENCY + (if arm.side == "left" then 0 else math.pi)
	const sway = math.sin(phase) * JUMP_SWAY
	const direction = torso.up * JUMP_UP
		+ torso.look * (JUMP_FORWARD + sway)
		+ torso.right * (arm.sign * JUMP_SIDE_OUT)

	return shoulder + vector.normalize(direction) * arm.part.Size.Y
end

const function get_fly_hand(
	state: CharacterState,
	arm: ArmState,
	shoulder: vector,
	torso: TorsoData,
	vertical_velocity: number
): vector
	const falling = math.clamp(-vertical_velocity / math.max(FLY_FALLING_REFERENCE, 0.001), 0, 1)
	const phase = state.state_time * FLY_SWAY_FREQUENCY + (if arm.side == "left" then 0 else math.pi)
	const sway = math.sin(phase) * FLY_SWAY
	const direction = torso.up * (FLY_LIFT - falling * FLY_FALL_LOWER)
		+ torso.look * (FLY_FORWARD + sway)
		+ torso.right * (arm.sign * (FLY_SIDE_OUT + falling * FLY_LANDING_SPREAD))

	return shoulder + vector.normalize(direction) * arm.part.Size.Y
end

const function get_take_hand(arm: ArmState, shoulder: vector): vector?
	const target = arm.take_target

	if not target then
		return nil
	end

	-- Рука R6 жёсткая: кисть всегда остаётся на полной длине руки,
	-- поэтому target задаёт направление вытягивания, а не точку кисти.
	const direction = target - shoulder
	const distance = vector.magnitude(direction)

	if distance <= ARM_DIRECTION_EPSILON then
		return nil
	end

	return shoulder + (direction / distance) * arm.part.Size.Y
end

const function get_hold_hand(
	state: CharacterState,
	arm: ArmState,
	shoulder: vector,
	torso: TorsoData
): vector?
	const target = state.hold_target
	const root = state.hold_root

	if not target or not root then
		return nil
	end

	local aim = target - root
	const aim_length = vector.magnitude(aim)

	if aim_length <= ARM_DIRECTION_EPSILON then
		aim = torso.look
	else
		aim = aim / aim_length
	end

	const hand_distance = if arm.side == "right"
		then HOLD_RIGHT_HAND_DISTANCE
		else HOLD_LEFT_HAND_DISTANCE

	const phase = state.elapsed * HOLD_REACTION_FREQUENCY
		+ (if arm.side == "left" then 0 else HOLD_REACTION_PHASE)
	const reaction = torso.right * (math.sin(phase) * HOLD_REACTION_SIDE)
		+ torso.up * (math.cos(phase) * HOLD_REACTION_UP)

	const desired = root + aim * hand_distance + reaction
	const direction = desired - shoulder
	const distance = vector.magnitude(direction)

	if distance <= ARM_DIRECTION_EPSILON then
		return nil
	end

	return shoulder + (direction / distance) * arm.part.Size.Y
end

const function get_arm_cframe(
	arm: ArmState,
	torso: TorsoData,
	shoulder: vector,
	hand: vector
): CFrame
	local direction = hand - shoulder
	const length = vector.magnitude(direction)

	if length <= ARM_DIRECTION_EPSILON then
		return arm.part.CFrame
	end

	direction /= length

	-- Локальная +Y часть руки смотрит от кисти к плечу.
	const up = -direction
	const look_hint = torso.look
	local forward = look_hint - up * vector.dot(look_hint, up)

	if vector.magnitude(forward) <= ARM_DIRECTION_EPSILON then
		const right_hint = torso.right
		forward = right_hint - up * vector.dot(right_hint, up)

		if vector.magnitude(forward) <= ARM_DIRECTION_EPSILON then
			return arm.part.CFrame
		end
	end

	forward = vector.normalize(forward)

	const right = vector.normalize(vector.cross(forward, up))
	const back = vector.normalize(vector.cross(right, up))
	const center = shoulder + direction * (arm.part.Size.Y * 0.5)
	const center3, right3, up3, back3 = tools.to_vector3(center, right, up, back)

	return CFrame.fromMatrix(center3, right3, up3, back3)
end

const function build_arm_target(
	state: CharacterState,
	arm: ArmState,
	torso: TorsoData,
	speed_factor: number,
	run_factor: number,
	vertical_velocity: number
): CFrame
	const shoulder = get_shoulder(arm, torso)
	local hand: vector? = nil

	if state.state == STATE_HOLD then
		hand = get_hold_hand(state, arm, shoulder, torso)
	elseif state.state == STATE_TAKE then
		hand = get_take_hand(arm, shoulder)
	end

	if not hand then
		if state.state == STATE_WALK then
			hand = get_walk_hand(state, arm, shoulder, torso, speed_factor, run_factor)
		elseif state.state == STATE_JUMP then
			hand = get_jump_hand(state, arm, shoulder, torso)
		elseif state.state == STATE_FLY then
			hand = get_fly_hand(state, arm, shoulder, torso, vertical_velocity)
		else
			hand = get_idle_hand(state, arm, shoulder, torso)
		end
	end

	arm.hand = hand

	return get_arm_cframe(arm, torso, shoulder, hand)
end

const function get_follow_speed(solver_state: SolverState): number
	if solver_state == STATE_JUMP or solver_state == STATE_FLY then
		return ARM_FAST_FOLLOW_SPEED
	elseif solver_state == STATE_TAKE then
		return ARM_TAKE_FOLLOW_SPEED
	elseif solver_state == STATE_HOLD then
		return ARM_HOLD_FOLLOW_SPEED
	end

	return ARM_FOLLOW_SPEED
end

const function solve_arm(state: CharacterState, arm: ArmState, delta: number)
	const alpha = 1 - math.exp(-get_follow_speed(state.state) * delta)

	arm.part.CFrame = arm.part.CFrame:Lerp(arm.target, alpha)
end

const function detect_auto_state(state: CharacterState, speed: number): SolverState
	const humanoid_state = state.humanoid:GetState()

	if humanoid_state == Enum.HumanoidStateType.Flying then
		return STATE_FLY
	end

	if humanoid_state == Enum.HumanoidStateType.Jumping
		or humanoid_state == Enum.HumanoidStateType.Freefall
	then
		return STATE_JUMP
	end

	if state.humanoid.FloorMaterial == Enum.Material.Air then
		return STATE_JUMP
	end

	const move_direction = tools.to_vector(state.humanoid.MoveDirection)

	if vector.magnitude(move_direction) >= WALK_STATE_MIN_INPUT or speed >= WALK_STATE_MIN_SPEED then
		return STATE_WALK
	end

	return STATE_IDLE
end

const function resolve_state(state: CharacterState, speed: number): SolverState
	if state.manual_state then
		return state.manual_state
	end

	if state.hold_target and state.hold_root then
		return STATE_HOLD
	end

	if state.left.take_target or state.right.take_target then
		return STATE_TAKE
	end

	return detect_auto_state(state, speed)
end

const function update_character(state: CharacterState, delta: number)
	const velocity, speed, speed_factor, run_factor = get_speed_data(state.humanoid)

	state.elapsed += delta
	state.state_time += delta

	const next_state = resolve_state(state, speed)

	if next_state ~= state.state then
		state.state = next_state
		state.state_time = 0
	end

	if state.state == STATE_WALK then
		const frequency = WALK_FREQUENCY_MIN
			+ (WALK_FREQUENCY_MAX - WALK_FREQUENCY_MIN) * speed_factor
			+ run_factor * RUN_FREQUENCY_BONUS

		state.walk_phase += delta * frequency
	end

	const torso = get_torso_data(state.torso)

	state.left.target = build_arm_target(
		state,
		state.left,
		torso,
		speed_factor,
		run_factor,
		velocity.y
	)
	state.right.target = build_arm_target(
		state,
		state.right,
		torso,
		speed_factor,
		run_factor,
		velocity.y
	)

	solve_arm(state, state.left, delta)
	solve_arm(state, state.right, delta)
end

const function create_arm_state(
	origin: BasePart,
	side: ArmSide,
	sign: number,
	character: Model
): ArmState
	const part = origin:Clone() :: BasePart
	const origin_transparency = origin.Transparency

	part.Name ..= ARM_VISUAL_SUFFIX
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 0
	part.LocalTransparencyModifier = 0
	part.Parent = character

	origin.Transparency = 1

	return {
		origin = origin,
		part = part,
		side = side,
		sign = sign,
		origin_transparency = origin_transparency,
		target = part.CFrame,
		hand = tools.to_vector(part.Position),
		take_target = nil,
	}
end

const function cleanup_arm(arm: ArmState)
	if arm.part.Parent then
		arm.part:Destroy()
	end

	if arm.origin.Parent then
		arm.origin.Transparency = arm.origin_transparency
	end
end

const function cleanup_character(state: CharacterState)
	cleanup_arm(state.left)
	cleanup_arm(state.right)
end

const function character_added(character: Model)
	if STATES[character] then
		return
	end

	const humanoid = get_humanoid(character)

	if not humanoid then
		return
	end

	if STATES[character] then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end

	const left_origin = find_limb(humanoid, character, Enum.Limb.LeftArm)
	const right_origin = find_limb(humanoid, character, Enum.Limb.RightArm)
	const torso = find_limb(humanoid, character, Enum.Limb.Torso)

	if not left_origin then
		return
	end

	if not right_origin then
		return
	end

	if not torso then
		return
	end

	const left = create_arm_state(left_origin, "left", -1, character)
	const right = create_arm_state(right_origin, "right", 1, character)

	STATES[character] = {
		character = character,
		humanoid = humanoid,
		torso = torso,

		left = left,
		right = right,

		state = STATE_IDLE,
		manual_state = nil,
		state_time = 0,
		elapsed = 0,
		walk_phase = 0,

		hold_target = nil,
		hold_root = nil,
	}

	humanoid.Died:Once(function()
		const state = STATES[character]

		if not state then
			return
		end

		cleanup_character(state)
		STATES[character] = nil
	end)
end

const function player_added(player: Player)
	player.CharacterAdded:Connect(character_added)

	player.CharacterRemoving:Connect(function(character: Model)
		const state = STATES[character]

		if not state then
			return
		end

		cleanup_character(state)
		STATES[character] = nil
	end)

	if player.Character then
		character_added(player.Character)
	end
end

--[[
	Публичный интерфейс агрегатора рук.

	Все позиции - мировые vector-координаты.

	ARMS.set_state(character, state_name)
		Принудительно включает состояние. state_name = nil возвращает
		автоматическое переключение по состоянию персонажа.

	ARMS.set_take_target(character, side, target)
		target для конкретной руки: "left" или "right".

	ARMS.set_hold_target(character, target, target_root)
		Общая цель для пары рук. Линия target - target_root задаёт
		направление оружия.

	ARMS.set_hold_target_local(character, target_offset, target_root_offset)
		То же самое, но offsets задаются относительно торса:
		x - right, y - up, z - look (вперёд).

	ARMS.clear_take_target(character, side)
	ARMS.clear_take_targets(character)
	ARMS.clear_hold_target(character)
]]
const ARMS: { [string]: any } = {}

const function is_valid_state(state_name: string): boolean
	return VALID_STATES[state_name] == true
end

ARMS.set_state = function(character: Model, state_name: string?)
	const state = STATES[character]

	if not state then
		return
	end

	if state_name == nil then
		state.manual_state = nil
		return
	end

	if not is_valid_state(state_name) then
		warn(`[IKR6Arms] unknown state "{state_name}"`)
		return
	end

	state.manual_state = state_name :: SolverState
end

ARMS.get_state = function(character: Model): SolverState?
	const state = STATES[character]

	return if state then state.state else nil
end

ARMS.is_supported = function(character: Model): boolean
	return STATES[character] ~= nil
end

ARMS.set_take_target = function(character: Model, side: string, target: vector)
	const state = STATES[character]

	if not state then
		return
	end

	if side == "left" then
		state.left.take_target = target
	elseif side == "right" then
		state.right.take_target = target
	else
		warn(`[IKR6Arms] unknown arm side "{side}"`)
	end
end

ARMS.clear_take_target = function(character: Model, side: string)
	const state = STATES[character]

	if not state then
		return
	end

	if side == "left" then
		state.left.take_target = nil
	elseif side == "right" then
		state.right.take_target = nil
	else
		warn(`[IKR6Arms] unknown arm side "{side}"`)
	end
end

ARMS.clear_take_targets = function(character: Model)
	const state = STATES[character]

	if not state then
		return
	end

	state.left.take_target = nil
	state.right.take_target = nil
end

ARMS.set_hold_target = function(character: Model, target: vector, target_root: vector)
	const state = STATES[character]

	if not state then
		return
	end

	state.hold_target = target
	state.hold_root = target_root
end

ARMS.set_hold_target_local = function(character: Model, target_offset: vector, target_root_offset: vector)
	const state = STATES[character]

	if not state then
		return
	end

	const torso = get_torso_data(state.torso)

	state.hold_target = torso.position
		+ torso.right * target_offset.x
		+ torso.up * target_offset.y
		+ torso.look * target_offset.z
	state.hold_root = torso.position
		+ torso.right * target_root_offset.x
		+ torso.up * target_root_offset.y
		+ torso.look * target_root_offset.z
end

ARMS.clear_hold_target = function(character: Model)
	const state = STATES[character]

	if not state then
		return
	end

	state.hold_target = nil
	state.hold_root = nil
end

_G.IKR6Arms = ARMS

SIGNAL:Connect(function(delta: number)
	const step = math.min(delta, MAX_DELTA)

	for character, state in STATES do
		if not character.Parent or not state.torso.Parent then
			cleanup_character(state)
			STATES[character] = nil
			continue
		end

		update_character(state, step)
	end
end)

do
	players.PlayerAdded:Connect(player_added)

	for _, v in players:GetPlayers() do
		player_added(v)
	end
end

