--!nocheck

-- IKR6Arms.lua — фейковые R6 руки. Чистое прототипное ООП, без единого сервиса.
--
--   Proto            — базовый прототип (математика/утилиты, наследуется обоими классами)
--   IKR6Arm          — ОДНА рука (геометрия, IK, коллизии, позы, скорость)
--   IKR6Arms         — персонаж (состояния, походка, idle-подсостояния, две IKR6Arm)
--
-- Все бывшие константы — поля КОНКРЕТНОГО объекта (клонируются из Class.defaults в момент
-- создания), т.е. крутятся индивидуально: rig.left.ARM_ELBOW_POLE_DOWN = 1.4 и т.д.
-- Никаких RunService/Players/Heartbeat — тик даёт владелец через rig:update(dt).
--
--   local IKR6Arms = require(path.IKR6Arms)
--   local rig = IKR6Arms.new(character, {
--       MAX_DELTA = 1 / 20,
--       arm   = { ARM_FOLLOW_SPEED_LINEAR_COEF = 1.6 },  -- обеим рукам
--       left  = { IDLE_TWIST = math.rad(6) },            -- только левой
--       world = workspace,                               -- опционально, иначе ищется по предкам
--   })
--   rig:update(dt)                      -- звать самому откуда угодно
--   rig:set_state("run"); rig:set_state(nil)
--   rig:set_take_target("right", vector.create(0, 3, -4))
--   rig:set_hold_target_local(vector.create(0, 0, -1.5), vector.create(0, 0, -0.5))
--   rig.left.ARM_SPEED_REFERENCE = 12   -- индивидуальная привязка к скорости
--   rig:destroy()
--
--   IKR6Arms.Arm — сам класс IKR6Arm (если нужно собрать руку вручную).

-- ==== TYPES ======================================================
type Dict = { [string]: any }

type SolverState = "idle" | "walk" | "run" | "jump" | "fly" | "pushed" | "take" | "hold"
type IdleSubState = "none" | "crossed" | "behind" | "action"
type IdleAction = "watch" | "scratch" | "stretch"
type ArmSide = "left" | "right"

type TorsoData = {
	position: vector,
	right: vector,
	up: vector,
	look: vector,
	half_x: number,
	half_y: number,
	half: vector,
}

type MotionData = {
	velocity: vector,
	horizontal: vector,
	speed: number,
	linear_speed: number,
	walk_factor: number,
	run_factor: number,
	input: number,
}

type ArmIKResult = { elbow: vector, upper_dir: vector, lower_dir: vector }

-- ==== BASE PROTOTYPE =============================================
local Proto: Dict = {}
Proto.__index = Proto

Proto.defaults = {
	ARM_DIRECTION_EPSILON = 1e-5,
}

function Proto:clone_value(v: any): any
	if type(v) == "table" then
		local out: Dict = {}
		for k, vv in v do
			out[k] = self:clone_value(vv)
		end
		return out
	end
	return v
end

function Proto:apply_defaults(src: Dict?)
	if not src then
		return
	end
	for k, v in src do
		self[k] = self:clone_value(v)
	end
end

function Proto:configure(opts: Dict?)
	if not opts then
		return
	end
	for k, v in opts do
		self[k] = self:clone_value(v)
	end
	return self
end

function Proto:merged(...: Dict?): Dict
	local out: Dict = {}
	for i = 1, select("#", ...) do
		local src = select(i, ...)
		if src then
			for k, v in src do
				out[k] = self:clone_value(v)
			end
		end
	end
	return out
end

-- math ------------------------------------------------------------
function Proto:mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Proto:damp(from: number, to: number, speed: number, dt: number): number
	if speed <= 0 then
		return to
	end
	return to + (from - to) * math.exp(-speed * dt)
end

function Proto:damp_vec(from: vector, to: vector, speed: number, dt: number): vector
	if speed <= 0 then
		return to
	end
	return from + (to - from) * (1 - math.exp(-speed * dt))
end

function Proto:smoothstep(v: number): number
	local t = math.clamp(v, 0, 1)
	return t * t * (3 - 2 * t)
end

function Proto:nlerp(from: vector, to: vector, a: number): vector
	local m = from + (to - from) * a
	local l = vector.magnitude(m)
	if l <= self.ARM_DIRECTION_EPSILON then
		return if a < 0.5 then from else to
	end
	return m / l
end

function Proto:damp_nlerp(from: vector, to: vector, speed: number, dt: number): vector
	if speed <= 0 then
		return to
	end
	return self:nlerp(from, to, 1 - math.exp(-speed * dt))
end

function Proto:norm_or(d: vector, fb: vector): vector
	local l = vector.magnitude(d)
	return if l <= self.ARM_DIRECTION_EPSILON then fb else d / l
end

function Proto:to_local(t: TorsoData, d: vector): vector
	return vector.create(vector.dot(d, t.right), vector.dot(d, t.up), vector.dot(d, t.look))
end

function Proto:to_world(t: TorsoData, d: vector): vector
	return t.right * d.x + t.up * d.y + t.look * d.z
end

function Proto:vec(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

function Proto:v3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

function Proto:pose(dir: vector, fb: vector, twist: number): (vector, number)
	return self:norm_or(dir, fb), twist
end

-- ==== IKR6Arm ====================================================
local IKR6Arm: Dict = setmetatable({}, { __index = Proto })
IKR6Arm.__index = IKR6Arm

IKR6Arm.defaults = {
	-- визуал
	ARM_VISUAL_SUFFIX = "_VIS",
	ARM_VISUAL_TRANSPARENCY = 0,
	ARM_ORIGIN_TRANSPARENCY = 1,

	-- сокет плеча
	SHOULDER_FORWARD_DIFF = 0,
	SHOULDER_SIDE_COEF = 0.5,
	SHOULDER_UP_COEF = 0.5,
	ARM_SOCKET_INSET = 0.02,
	ARM_SOCKET_LIFT = 0,
	ARM_SHOULDER_TOP_GAP = 0.02,
	ARM_SHOULDER_TOP_LIFT = 0,
	ARM_SHOULDER_TOP_FORWARD = 0,

	-- локоть
	ARM_ELBOW_UPPER_COEF = 0.5,
	ARM_ELBOW_LOWER_COEF = 0.5,
	ARM_ELBOW_POLE_DOWN = 1.0,
	ARM_ELBOW_POLE_OUTWARD = 0.65,
	ARM_ELBOW_POLE_BACK = 0.25,
	ARM_ELBOW_REACH_IDLE = 0.985,
	ARM_ELBOW_REACH_RUN = 0.78,
	ARM_ELBOW_RUN_SWING_SHORTEN = 0.08,
	ARM_ELBOW_REACH_SPEED_SHORTEN = 0.04,
	ARM_ELBOW_BASE_BLEND = 0.35,
	ARM_ELBOW_RUN_BLEND = 0.72,
	ARM_ELBOW_DIRECTION_WEIGHT = 0.55,
	ARM_ELBOW_RUN_DIRECTION_BOOST = 0.25,
	ARM_ELBOW_BLEND_SPEED = 8,

	-- ограничение выворота плеча
	ARM_SHOULDER_YAW_OUTWARD_DEG = 80,
	ARM_SHOULDER_YAW_INWARD_DEG = 18,
	ARM_SHOULDER_YAW_BACK_OUTWARD_DEG = 80,
	ARM_SHOULDER_YAW_BACK_INWARD_DEG = 20,
	ARM_SHOULDER_YAW_MIN_HORIZONTAL = 0.22,
	ARM_SHOULDER_YAW_FULL_HORIZONTAL = 0.48,

	-- СКОРОСТЬ РУКИ (привязка к текущей скорости тела)
	follow_speeds = {
		idle = 16,
		walk = 16,
		run = 22,
		jump = 28,
		fly = 28,
		pushed = 30,
		take = 24,
		hold = 26,
	},
	ARM_FOLLOW_SPEED_MIN = 12,
	ARM_FOLLOW_SPEED_MAX = 60,
	ARM_FOLLOW_SPEED_LINEAR_COEF = 1.25,
	ARM_FOLLOW_SPEED_INPUT_BOOST = 8,
	ARM_SPEED_REFERENCE = 16,
	ARM_SPEED_SCALE_MIN = 0.6,
	ARM_SPEED_SCALE_MAX = 2.5,
	ARM_FOLLOW_SPEED_SCALE_WEIGHT = 1,
	ARM_SHOULDER_SPEED_WEIGHT = 0.5,
	ARM_SWAY_SPEED_WEIGHT = 0.65,

	-- коллизии
	ARM_COLLISION_RADIUS_COEF = 0.5,
	ARM_COLLISION_RADIUS_FALLBACK = 0.2,
	ARM_COLLISION_PADDING = 0.02,
	ARM_COLLISION_DEFLECT = 0.55,
	ARM_COLLISION_ITERATIONS = 3,
	ARM_COLLISION_RADIUS_SMOOTH = 14,
	ARM_COLLISION_WIDTH_SAMPLES = 3,
	ARM_COLLISION_SWEEP_START_SCALE = 0.75,
	ARM_COLLISION_SWEEP_MAX_OFFSET = 0.15,

	-- стена
	ARM_WALL_QUERY_DISTANCE = 0.35,
	ARM_WALL_ANGLE_MIN_DEG = 70,
	ARM_WALL_ANGLE_MAX_DEG = 120,
	ARM_WALL_STRENGTH = 0.65,
	ARM_WALL_INWARD_WEIGHT = 0.55,
	ARM_WALL_UP_LIMIT = 0.08,

	-- втягивание плеча
	ARM_SHOULDER_ROOT_DISTANCE = 0,
	ARM_SHOULDER_RETRACT_MAX_DISTANCE = 0,
	ARM_SHOULDER_RETRACT_SPEED = 18,
	ARM_SHOULDER_RETRACT_WALL_BOOST = 0.35,

	-- динамика плеча
	SHOULDER_SMOOTH = 18,
	SHOULDER_GAIT_FORWARD_WALK = 0.045,
	SHOULDER_GAIT_FORWARD_RUN = 0.13,
	SHOULDER_GAIT_UP_WALK = 0.015,
	SHOULDER_GAIT_UP_RUN = 0.055,
	SHOULDER_GAIT_SIDE_WALK = 0.008,
	SHOULDER_GAIT_SIDE_RUN = 0.028,
	SHOULDER_JUMP_LIFT = 0.05,
	SHOULDER_JUMP_FORWARD = 0.02,
	SHOULDER_FLY_LIFT = 0.07,
	SHOULDER_FLY_FORWARD = 0.04,
	SHOULDER_PUSHED_UP = 0.02,
	SHOULDER_PUSHED_BACK = 0.08,
	SHOULDER_TAKE_FORWARD = 0.16,
	SHOULDER_TAKE_SIDE = 0.09,
	SHOULDER_TAKE_UP = 0.05,
	SHOULDER_HOLD_FORWARD = 0.09,
	SHOULDER_HOLD_UP = 0.02,
	SHOULDER_HOLD_SIDE = 0.02,

	-- досягаемость
	ARM_REACH_INWARD_LIMIT = 0.12,
	ARM_REACH_FORWARD_CROSS_BONUS = 0.16,
	ARM_TAKE_FORWARD_MIN = -0.03,
	ARM_HOLD_FORWARD_MIN = -0.14,
	ARM_REACH_SIDE_BIAS = 0.35,
	ARM_REACH_DOT_MIN = 0.08,
	ARM_REACH_OWN_SIDE_THRESHOLD = 0.20,
	ARM_REACH_OWN_SIDE_TAKE_BACK_MIN = -0.85,
	ARM_REACH_OWN_SIDE_HOLD_BACK_MIN = -0.55,

	-- корпус
	ARM_BODY_PADDING = 0.08,
	ARM_BODY_SAMPLE_COUNT = 5,
	ARM_BODY_FRONT_SAFE_COEF = 0.72,
	ARM_BODY_HOLD_FRONT_SAFE_COEF = 0.35,

	-- idle-поза
	IDLE_UP_DIFF = 0,
	IDLE_LEFT_DIFF = 0.06,
	IDLE_RIGHT_DIFF = 0.06,
	IDLE_FORWARD_DIFF = 0.02,
	IDLE_SWAY_AMPLITUDE = 0.03,
	IDLE_SWAY_FREQUENCY = 1.1,
	IDLE_TWIST = math.rad(4),
	IDLE_BREATH_FREQUENCY = 1.6,
	IDLE_BREATH_AMPLITUDE = 0.02,

	IDLE_CROSSED_DOWN = 0.3,
	IDLE_CROSSED_FORWARD = 0.85,
	IDLE_CROSSED_INWARD = 0.6,
	IDLE_CROSSED_LAYER = 0.08,
	IDLE_CROSSED_TWIST = math.rad(70),

	IDLE_BEHIND_DOWN = 0.85,
	IDLE_BEHIND_BACK = 0.45,
	IDLE_BEHIND_INWARD = 0.4,
	IDLE_BEHIND_TWIST = math.rad(-25),
	IDLE_BEHIND_WALK_SWAY = 0.08,

	IDLE_WATCH_DOWN = 0.25,
	IDLE_WATCH_FORWARD = 0.8,
	IDLE_WATCH_INWARD = 0.55,
	IDLE_WATCH_TWIST = math.rad(80),

	IDLE_SCRATCH_UP = 0.85,
	IDLE_SCRATCH_FORWARD = 0.25,
	IDLE_SCRATCH_INWARD = 0.35,
	IDLE_SCRATCH_SWAY = 0.06,
	IDLE_SCRATCH_FREQUENCY = 14,

	IDLE_STRETCH_SIDE = 0.12,
	IDLE_STRETCH_BACK = 0.06,
	IDLE_STRETCH_SWAY = 0.04,
	IDLE_STRETCH_FREQUENCY = 3,

	-- шаг / бег
	WALK_FORWARD_AMPLITUDE_MIN = math.rad(9),
	WALK_FORWARD_AMPLITUDE_MAX = math.rad(28),
	WALK_BACK_AMPLITUDE_MIN = math.rad(7),
	WALK_BACK_AMPLITUDE_MAX = math.rad(22),
	WALK_SIDE_OUT = 0.05,
	WALK_INWARD = 0.05,
	WALK_TWIST = math.rad(6),

	RUN_FORWARD_AMPLITUDE = math.rad(46),
	RUN_BACK_AMPLITUDE = math.rad(38),
	RUN_FORWARD_BIAS = math.rad(6),
	RUN_UP_BIAS = 0.12,
	RUN_BACK_LIFT = 0.05,
	RUN_SIDE_OUT = 0.09,
	RUN_INWARD = 0.10,
	RUN_TWIST = math.rad(12),

	-- прыжок
	JUMP_UP = 1,
	JUMP_FORWARD = 0.04,
	JUMP_SIDE_OUT = 0.16,
	JUMP_SWAY = 0.04,
	JUMP_SWAY_FREQUENCY = 5,
	JUMP_FALLING_REFERENCE = 26,
	JUMP_FALL_LOWER = 0.95,
	JUMP_LANDING_SPREAD = 0.32,
	JUMP_FALL_FORWARD_REDUCE = 0.55,
	JUMP_FALL_SWAY_REDUCE = 0.45,

	-- полёт
	FLY_LIFT = 0.88,
	FLY_FORWARD = 0.18,
	FLY_SIDE_OUT = 0.18,
	FLY_SWAY = 0.12,
	FLY_SWAY_FREQUENCY = 3,
	FLY_FALLING_REFERENCE = 26,
	FLY_FALL_LOWER = 1.02,
	FLY_LANDING_SPREAD = 0.42,
	FLY_FALL_FORWARD_REDUCE = 0.65,
	FLY_FALL_SWAY_REDUCE = 0.55,

	-- отброс
	PUSHED_FORWARD = 1,
	PUSHED_UP = 0.15,
	PUSHED_SIDE = 0.12,
	PUSHED_VELOCITY_BIAS = 0.35,
	PUSHED_SWAY = 0.12,
	PUSHED_SWAY_FREQUENCY = 9,
	PUSHED_TWIST = math.rad(-20),

	-- удержание
	HOLD_HAND_DISTANCE = 0.15,
	HOLD_HAND_SIDE_SPREAD = 0.16,
	HOLD_REACTION_SIDE = 0.035,
	HOLD_REACTION_UP = 0.025,
	HOLD_REACTION_FREQUENCY = 2.4,
	HOLD_REACTION_PHASE = math.pi,
}

function IKR6Arm.new(origin: BasePart, side: ArmSide, sign: number, char: Model, opts: Dict?): Dict
	local self: Dict = setmetatable({}, IKR6Arm) :: any
	self:apply_defaults(Proto.defaults)
	self:apply_defaults(IKR6Arm.defaults)
	self:configure(opts)

	self.is_arm = true
	self.side = side
	self.sign = sign
	self.character = char
	self.origin = origin
	self.rig = nil

	local part = origin:Clone() :: BasePart
	self.origin_transparency = origin.Transparency
	for _, c in part:GetChildren() do
		if c:IsA("JointInstance") then
			c:Destroy()
		end
	end
	part.Name = part.Name .. self.ARM_VISUAL_SUFFIX
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = self.ARM_VISUAL_TRANSPARENCY
	part.LocalTransparencyModifier = 0
	part.Parent = char
	origin.Transparency = self.ARM_ORIGIN_TRANSPARENCY
	self.part = part

	local cr = math.min(origin.Size.X, origin.Size.Z) * self.ARM_COLLISION_RADIUS_COEF
	if cr <= self.ARM_DIRECTION_EPSILON then
		cr = self.ARM_COLLISION_RADIUS_FALLBACK
	end

	local fl = origin.Size.Y
	local tc = math.max(self.ARM_ELBOW_UPPER_COEF + self.ARM_ELBOW_LOWER_COEF, self.ARM_DIRECTION_EPSILON)

	self.smooth_local = vector.create(0, -1, 0)
	self.smooth_twist = 0
	self.smooth_shoulder_local = vector.zero
	self.collision_radius = cr
	self.take_target = nil
	self.upper_length = fl * (self.ARM_ELBOW_UPPER_COEF / tc)
	self.lower_length = fl * (self.ARM_ELBOW_LOWER_COEF / tc)
	self.shoulder_retract = 0
	self.elbow_blend = self.ARM_ELBOW_BASE_BLEND
	self.sway_phase = 0

	return self
end

function IKR6Arm:destroy()
	if self.part then
		if self.part.Parent then
			self.part:Destroy()
		end
		self.part = nil
	end
	if self.origin and self.origin.Parent then
		self.origin.Transparency = self.origin_transparency
	end
	self.take_target = nil
	self.rig = nil
end

function IKR6Arm:inward(t: TorsoData): vector
	return -t.right * self.sign
end

function IKR6Arm:phase(): number
	return if self.side == "left" then 0 else math.pi
end

-- ==== SPEED BINDING ==============================================
function IKR6Arm:speed_scale(m: MotionData): number
	local ref = math.max(self.ARM_SPEED_REFERENCE, self.ARM_DIRECTION_EPSILON)
	return math.clamp(m.linear_speed / ref, self.ARM_SPEED_SCALE_MIN, self.ARM_SPEED_SCALE_MAX)
end

function IKR6Arm:sway_rate(m: MotionData): number
	return self:mix(1, self:speed_scale(m), self.ARM_SWAY_SPEED_WEIGHT)
end

function IKR6Arm:follow_speed(m: MotionData): number
	local base = self.follow_speeds[self.rig.state] or self.follow_speeds.idle
	local scaled = base * self:mix(1, self:speed_scale(m), self.ARM_FOLLOW_SPEED_SCALE_WEIGHT)
	return math.clamp(
		scaled + m.linear_speed * self.ARM_FOLLOW_SPEED_LINEAR_COEF + m.input * self.ARM_FOLLOW_SPEED_INPUT_BOOST,
		self.ARM_FOLLOW_SPEED_MIN,
		self.ARM_FOLLOW_SPEED_MAX
	)
end

-- ==== SOCKETS ====================================================
function IKR6Arm:socket_local(t: TorsoData): vector
	local so = math.max(t.half_x - self.ARM_SOCKET_INSET, 0)
	return vector.create(self.sign * so, t.half_y + self.ARM_SOCKET_LIFT, self.SHOULDER_FORWARD_DIFF)
end

function IKR6Arm:top_local(t: TorsoData): vector
	return self:socket_local(t)
		+ vector.create(
			self.sign * (self.part.Size.X * 0.5 + self.ARM_SHOULDER_TOP_GAP),
			self.ARM_SHOULDER_TOP_LIFT,
			self.ARM_SHOULDER_TOP_FORWARD
		)
end

-- ==== ROTATION LIMIT =============================================
function IKR6Arm:clamp_rotation(d: vector): vector
	local n = self:norm_or(d, vector.create(0, -1, 0))
	local hz = vector.create(n.x, 0, n.z)
	local hm = vector.magnitude(hz)
	if hm <= self.ARM_DIRECTION_EPSILON then
		return n
	end
	local span = math.max(
		self.ARM_SHOULDER_YAW_FULL_HORIZONTAL - self.ARM_SHOULDER_YAW_MIN_HORIZONTAL,
		self.ARM_DIRECTION_EPSILON
	)
	local w = self:smoothstep((hm - self.ARM_SHOULDER_YAW_MIN_HORIZONTAL) / span)
	if w <= 0 then
		return n
	end
	local h = hz / hm
	local outward, forward = h.x * self.sign, h.z
	local angle = math.atan2(outward, forward)
	local clamped: vector
	if math.abs(angle) <= math.pi * 0.5 then
		local c =
			math.clamp(angle, -math.rad(self.ARM_SHOULDER_YAW_INWARD_DEG), math.rad(self.ARM_SHOULDER_YAW_OUTWARD_DEG))
		clamped = vector.create(self.sign * math.sin(c), 0, math.cos(c))
	else
		local ba = math.atan2(outward, -forward)
		local c = math.clamp(
			ba,
			-math.rad(self.ARM_SHOULDER_YAW_BACK_INWARD_DEG),
			math.rad(self.ARM_SHOULDER_YAW_BACK_OUTWARD_DEG)
		)
		clamped = vector.create(self.sign * math.sin(c), 0, -math.cos(c))
	end
	local bh = self:nlerp(h, clamped, w) * hm
	return self:norm_or(vector.create(bh.x, n.y, bh.z), n)
end

-- ==== IK =========================================================
function IKR6Arm:solve_ik(t: TorsoData, sh: vector, hand: vector): ArmIKResult
	local to = hand - sh
	local dist = vector.magnitude(to)
	local up, lo = self.upper_length, self.lower_length
	local total = up + lo
	if dist <= self.ARM_DIRECTION_EPSILON or total <= self.ARM_DIRECTION_EPSILON then
		local fb = -t.up
		return { elbow = sh + fb * up, upper_dir = fb, lower_dir = fb }
	end
	local hd = to / dist
	local min_r = math.abs(up - lo) + self.ARM_DIRECTION_EPSILON
	local max_r = total - self.ARM_DIRECTION_EPSILON
	local reach = math.clamp(dist, min_r, max_r)
	local cs = math.clamp((up * up + reach * reach - lo * lo) / (2 * up * reach), -1, 1)
	local bend = math.acos(cs)
	local pole = -t.up * self.ARM_ELBOW_POLE_DOWN
		+ t.right * (self.sign * self.ARM_ELBOW_POLE_OUTWARD)
		- t.look * self.ARM_ELBOW_POLE_BACK
	local axis = vector.cross(hd, pole)
	local al = vector.magnitude(axis)
	if al <= self.ARM_DIRECTION_EPSILON then
		axis = t.right * self.sign
		al = vector.magnitude(axis)
		if al <= self.ARM_DIRECTION_EPSILON then
			axis = t.up
			al = vector.magnitude(axis)
		end
	end
	axis = axis / al
	local t1 = hd * math.cos(bend)
	local t2 = vector.cross(axis, hd) * math.sin(bend)
	local t3 = axis * vector.dot(axis, hd) * (1 - math.cos(bend))
	local ud = self:norm_or(t1 + t2 + t3, hd)
	local el = sh + ud * up
	return { elbow = el, upper_dir = ud, lower_dir = self:norm_or(hand - el, hd) }
end

function IKR6Arm:cframe(t: TorsoData, sh: vector, dir: vector, twist: number, ik: ArmIKResult): CFrame
	if vector.magnitude(dir) <= self.ARM_DIRECTION_EPSILON then
		dir = -t.up
	end
	local up = self:norm_or(self:nlerp(-ik.upper_dir, -ik.lower_dir, self.elbow_blend), -dir)
	local fh = t.look
	local to_el = ik.elbow - sh
	local proj = to_el - up * vector.dot(to_el, up)
	if vector.magnitude(proj) > self.ARM_DIRECTION_EPSILON then
		fh = vector.normalize(proj)
	end
	local fwd = fh - up * vector.dot(fh, up)
	if vector.magnitude(fwd) <= self.ARM_DIRECTION_EPSILON then
		fwd = t.right - up * vector.dot(t.right, up)
		if vector.magnitude(fwd) <= self.ARM_DIRECTION_EPSILON then
			return self.part.CFrame
		end
	end
	fwd = vector.normalize(fwd)
	local side = vector.cross(fwd, up)
	local tw = vector.normalize(fwd * math.cos(twist) - side * (self.sign * math.sin(twist)))
	local right = vector.normalize(vector.cross(tw, up))
	local back = vector.normalize(vector.cross(right, up))
	local center = sh - up * (self.part.Size.Y * 0.5)
	return CFrame.fromMatrix(self:v3(center), self:v3(right), self:v3(up), self:v3(back))
end

-- ==== TORSO GUARD ================================================
function IKR6Arm:segment_hits_torso_local(t: TorsoData, s: vector, f: vector, pad: number): boolean
	local h = t.half
	for i = 1, self.ARM_BODY_SAMPLE_COUNT do
		local p = s + (f - s) * (i / (self.ARM_BODY_SAMPLE_COUNT + 1))
		if math.abs(p.x) <= h.x + pad and p.y >= -h.y - pad and p.y <= h.y + pad and math.abs(p.z) <= h.z + pad then
			return true
		end
	end
	return false
end

function IKR6Arm:direction_hits_torso(t: TorsoData, sh: vector, dir: vector, len: number, pad: number): boolean
	local sh_l = self:to_local(t, sh - t.position)
	local end_l = sh_l + self:to_local(t, dir) * len
	return self:segment_hits_torso_local(t, sh_l, end_l, pad)
end

function IKR6Arm:keep_direction_out_of_torso(t: TorsoData, sh: vector, dir: vector): vector
	local len = self.part.Size.Y
	if not self:direction_hits_torso(t, sh, dir, len, self.ARM_BODY_PADDING) then
		return dir
	end
	local ld = self:to_local(t, dir)
	local best = dir
	local best_s = -math.huge
	local cands: { vector } = {
		ld + vector.create(self.sign * 0.38, -0.06, 0.14),
		ld + vector.create(self.sign * 0.28, -0.16, 0.10),
		ld + vector.create(self.sign * 0.20, 0.04, 0.24),
		ld + vector.create(self.sign * 0.46, 0.00, -0.06),
		ld + vector.create(self.sign * 0.12, -0.28, 0.18),
	}
	for _, cl in cands do
		local c = self:norm_or(self:to_world(t, cl), dir)
		local sc = vector.dot(c, dir)
		if sc > best_s and not self:direction_hits_torso(t, sh, c, len, self.ARM_BODY_PADDING) then
			best = c
			best_s = sc
		end
	end
	return best
end

function IKR6Arm:is_target_reachable(t: TorsoData, sh: vector, target: vector, take: boolean): boolean
	local to = target - sh
	local dist = vector.magnitude(to)
	if dist <= self.ARM_DIRECTION_EPSILON then
		return false
	end
	local ld = self:to_local(t, to / dist)
	local outward = ld.x * self.sign
	local forward = ld.z
	local fwd_limit = if take then self.ARM_TAKE_FORWARD_MIN else self.ARM_HOLD_FORWARD_MIN
	local own = outward > self.ARM_REACH_OWN_SIDE_THRESHOLD
	if own then
		local relax = if take then self.ARM_REACH_OWN_SIDE_TAKE_BACK_MIN else self.ARM_REACH_OWN_SIDE_HOLD_BACK_MIN
		if relax < fwd_limit then
			fwd_limit = relax
		end
	end
	if forward < fwd_limit then
		return false
	end
	if not own then
		local fn = math.clamp(forward, 0, 1)
		if outward < -(self.ARM_REACH_INWARD_LIMIT + fn * self.ARM_REACH_FORWARD_CROSS_BONUS) then
			return false
		end
		local allowed =
			self:norm_or(vector.create(self.sign * self.ARM_REACH_SIDE_BIAS, 0.12, 1), vector.create(0, 0, 1))
		if vector.dot(ld, allowed) < self.ARM_REACH_DOT_MIN then
			return false
		end
	end
	local sh_l = self:to_local(t, sh - t.position)
	local tg_l = self:to_local(t, target - t.position)
	local safe = if take then self.ARM_BODY_FRONT_SAFE_COEF else self.ARM_BODY_HOLD_FRONT_SAFE_COEF
	if tg_l.z < t.half.z * safe then
		if self:segment_hits_torso_local(t, sh_l, tg_l, self.ARM_BODY_PADDING) then
			return false
		end
	end
	return true
end

-- ==== WALL =======================================================
function IKR6Arm:apply_wall_constraint(t: TorsoData, dir: vector, n: vector?, s: number): vector
	if n == nil or s <= 0 then
		return dir
	end
	local fn = n - t.up * vector.dot(n, t.up)
	if vector.magnitude(fn) <= self.ARM_DIRECTION_EPSILON then
		return dir
	end
	fn = vector.normalize(fn)
	local inward = self:inward(t)
	if vector.dot(fn, inward) < 0 then
		fn = -fn
	end
	local ang = math.deg(math.acos(math.clamp(vector.dot(dir, fn), -1, 1)))
	if ang < self.ARM_WALL_ANGLE_MIN_DEG or ang > self.ARM_WALL_ANGLE_MAX_DEG then
		return dir
	end
	local fd = dir - t.up * vector.dot(dir, t.up)
	if vector.magnitude(fd) <= self.ARM_DIRECTION_EPSILON then
		fd = dir
	end
	local target =
		self:norm_or(fd + fn * self.ARM_WALL_INWARD_WEIGHT + inward * (self.ARM_WALL_INWARD_WEIGHT * 0.45), dir)
	local m = self:nlerp(dir, target, math.clamp(self.ARM_WALL_STRENGTH * s, 0, 1))
	local ml = self:to_local(t, m)
	ml = vector.create(ml.x, math.min(ml.y, self.ARM_WALL_UP_LIMIT), ml.z)
	return self:norm_or(self:to_world(t, ml), m)
end

function IKR6Arm:query_side_wall(t: TorsoData, sh: vector, dir: vector): (vector?, number)
	local rig = self.rig
	local world = rig.world
	if not world then
		return nil, 0
	end
	local r = math.max(self.collision_radius + self.ARM_COLLISION_PADDING, 0.02)
	local mid = sh + dir * (self.part.Size.Y * 0.45)
	local out = t.right * self.sign
	local cd = self.ARM_WALL_QUERY_DISTANCE + r
	local res = world:Spherecast(self:v3(mid), r, self:v3(out * cd), rig.rayparams)
	if not res then
		return nil, 0
	end
	local n = self:vec(res.Normal)
	if vector.magnitude(n) <= self.ARM_DIRECTION_EPSILON then
		return nil, 0
	end
	n = vector.normalize(n)
	if vector.dot(n, out) > 0 then
		n = -n
	end
	return n, 1 - math.clamp(res.Distance / math.max(cd, self.ARM_DIRECTION_EPSILON), 0, 1)
end

-- ==== COLLISION ==================================================
function IKR6Arm:point_blocked(pos: vector, r: number): boolean
	local rig = self.rig
	local world = rig.world
	if not world then
		return false
	end
	for _, part in world:GetPartBoundsInRadius(self:v3(pos), r, rig.overlap_params) do
		if part:IsA("Terrain") then
			continue
		end
		if part:IsA("BasePart") and part.CanCollide then
			return true
		end
	end
	return false
end

function IKR6Arm:is_direction_clear(sh: vector, dir: vector, len: number, r: number): boolean
	local rig = self.rig
	local world = rig.world
	if not world then
		return true
	end
	local l = vector.magnitude(dir)
	if l <= self.ARM_DIRECTION_EPSILON then
		return false
	end
	local d = dir / l
	local so = math.min(r * self.ARM_COLLISION_SWEEP_START_SCALE, len * self.ARM_COLLISION_SWEEP_MAX_OFFSET)
	local o = sh + d * so
	local cl = math.max(len - so - r, 0.02)
	local res = world:Spherecast(self:v3(o), r, self:v3(d * cl), rig.rayparams)
	if res and res.Distance < cl then
		return false
	end
	for i = 1, self.ARM_COLLISION_WIDTH_SAMPLES do
		if self:point_blocked(sh + d * (len * (i / (self.ARM_COLLISION_WIDTH_SAMPLES + 1))), r) then
			return false
		end
	end
	return true
end

function IKR6Arm:resolve_collision(t: TorsoData, sh: vector, dir: vector): (vector, vector?, number)
	local rig = self.rig
	local world = rig.world
	local len = self.part.Size.Y
	if not world or len <= self.ARM_DIRECTION_EPSILON then
		return dir, nil, 0
	end
	local r = math.max(self.collision_radius + self.ARM_COLLISION_PADDING, 0.02)
	local cur = self:norm_or(dir, -t.up)
	if self:is_direction_clear(sh, cur, len, r) then
		return cur, nil, 0
	end

	local last_n: vector? = nil
	local last_s = 0

	for _ = 1, self.ARM_COLLISION_ITERATIONS do
		local so = math.min(r * self.ARM_COLLISION_SWEEP_START_SCALE, len * self.ARM_COLLISION_SWEEP_MAX_OFFSET)
		local o = sh + cur * so
		local cl = math.max(len - so - r, 0.02)
		local res = world:Spherecast(self:v3(o), r, self:v3(cur * cl), rig.rayparams)
		local n: vector? = nil
		if res and res.Distance < cl then
			local rn = self:vec(res.Normal)
			if vector.magnitude(rn) > self.ARM_DIRECTION_EPSILON then
				n = vector.normalize(rn)
				last_n = n
				last_s = math.max(last_s, 1 - math.clamp(res.Distance / math.max(cl, self.ARM_DIRECTION_EPSILON), 0, 1))
			end
		end

		if n ~= nil then
			local tang = cur - n * vector.dot(cur, n)
			local tl = vector.magnitude(tang)
			if tl <= self.ARM_DIRECTION_EPSILON then
				tang = t.up - n * vector.dot(t.up, n)
				tl = vector.magnitude(tang)
				if tl <= self.ARM_DIRECTION_EPSILON then
					local hint = t.right * self.sign
					tang = hint - n * vector.dot(hint, n)
					tl = vector.magnitude(tang)
					if tl <= self.ARM_DIRECTION_EPSILON then
						break
					end
				end
			end
			tang = tang / tl
			if vector.dot(tang, cur) < -0.1 then
				tang = -tang
			end
			cur = self:nlerp(cur, tang, self.ARM_COLLISION_DEFLECT)
		else
			local cands: { vector } = {
				self:nlerp(cur, t.up, 0.45),
				self:nlerp(cur, t.right * self.sign, 0.45),
				self:nlerp(cur, -t.look, 0.35),
				self:nlerp(cur, -t.up, 0.35),
			}
			local best: vector? = nil
			local best_s = -math.huge
			for _, c in cands do
				if vector.magnitude(c) > self.ARM_DIRECTION_EPSILON then
					local cn = vector.normalize(c)
					local sc = vector.dot(cn, cur)
					if sc > best_s and self:is_direction_clear(sh, cn, len, r) then
						best = cn
						best_s = sc
					end
				end
			end
			if best ~= nil then
				return best, nil, 0
			end
			local safe = self:norm_or(t.up + t.right * self.sign * 0.5 - t.look * 0.2, cur)
			cur = self:nlerp(cur, safe, self.ARM_COLLISION_DEFLECT)
		end

		if self:is_direction_clear(sh, cur, len, r) then
			return cur, nil, 0
		end
	end
	return cur, last_n, last_s
end

-- ==== REACH ======================================================
function IKR6Arm:reach_scale(m: MotionData): number
	local rig = self.rig
	local run = rig.run_blend
	local s = self:mix(self.ARM_ELBOW_REACH_IDLE, self.ARM_ELBOW_REACH_RUN, run)
	if run > 0 then
		local sw = rig.gait_swing * (if self.side == "left" then 1 else -1)
		s -= run * math.clamp(sw, 0, 1) * self.ARM_ELBOW_RUN_SWING_SHORTEN
	end
	s -= math.max(self:speed_scale(m) - 1, 0) * self.ARM_ELBOW_REACH_SPEED_SHORTEN
	if rig.state == "take" or rig.state == "hold" then
		s = math.max(s, 0.985)
	end
	return math.clamp(s, 0.3, 1)
end

-- ==== SHOULDER OFFSET ============================================
function IKR6Arm:dynamic_shoulder_offset(t: TorsoData, _m: MotionData, base_sh: vector): vector
	local rig = self.rig
	local off = vector.zero
	local sw = rig.gait_swing * (if self.side == "left" then 1 else -1)
	local amt = rig.gait_strength
	if amt > 0.001 then
		local run = rig.run_blend
		local fwd = self:mix(self.SHOULDER_GAIT_FORWARD_WALK, self.SHOULDER_GAIT_FORWARD_RUN, run)
		local up = self:mix(self.SHOULDER_GAIT_UP_WALK, self.SHOULDER_GAIT_UP_RUN, run)
		local side = self:mix(self.SHOULDER_GAIT_SIDE_WALK, self.SHOULDER_GAIT_SIDE_RUN, run)
		off += vector.create(self.sign * side * sw * amt, up * math.abs(sw) * amt, fwd * sw * amt)
	end
	if rig.state == "jump" then
		off += vector.create(0, self.SHOULDER_JUMP_LIFT, self.SHOULDER_JUMP_FORWARD)
	elseif rig.state == "fly" then
		off += vector.create(0, self.SHOULDER_FLY_LIFT, self.SHOULDER_FLY_FORWARD)
	elseif rig.state == "pushed" then
		off += vector.create(0, self.SHOULDER_PUSHED_UP, -self.SHOULDER_PUSHED_BACK)
	end
	if self.take_target and self:is_target_reachable(t, base_sh, self.take_target, true) then
		local to = self.take_target - base_sh
		local l = vector.magnitude(to)
		if l > self.ARM_DIRECTION_EPSILON then
			local ld = self:to_local(t, to / l)
			off += vector.create(
				self.sign * math.clamp(ld.x * self.sign, 0, 1) * self.SHOULDER_TAKE_SIDE,
				math.clamp(ld.y, 0, 1) * self.SHOULDER_TAKE_UP,
				math.clamp(ld.z, 0, 1) * self.SHOULDER_TAKE_FORWARD
			)
		end
	end
	if rig.hold_target and rig.hold_root and rig:compute_hold_hand_point(self, t, base_sh, false) then
		local aim = rig.hold_target - rig.hold_root
		local al = vector.magnitude(aim)
		if al > self.ARM_DIRECTION_EPSILON then
			local la = self:to_local(t, aim / al)
			off += vector.create(
				self.sign * self.SHOULDER_HOLD_SIDE,
				self.SHOULDER_HOLD_UP,
				math.clamp(la.z, 0, 1) * self.SHOULDER_HOLD_FORWARD
			)
		end
	end
	return off
end

-- ==== POSES (dispatch: self["pose_" .. state]) ====================
function IKR6Arm:pose_idle(t: TorsoData, _m: MotionData, _sh: vector): (vector?, number)
	local rig = self.rig
	local ph = rig.elapsed * self.IDLE_SWAY_FREQUENCY + self:phase()
	local sway = math.sin(ph) * self.IDLE_SWAY_AMPLITUDE
	local sd = if self.side == "left" then self.IDLE_LEFT_DIFF else self.IDLE_RIGHT_DIFF
	local d = -t.up + t.up * self.IDLE_UP_DIFF + t.right * (self.sign * sd) + t.look * (self.IDLE_FORWARD_DIFF + sway)
	return self:pose(d, -t.up, self.IDLE_TWIST)
end

function IKR6Arm:pose_gait(t: TorsoData, _m: MotionData, _sh: vector): (vector?, number)
	local rig = self.rig
	local run = rig.run_blend
	local str = rig.gait_strength
	local swing = rig.gait_swing * (if self.side == "left" then 1 else -1)
	local fa = self:mix(
		self:mix(self.WALK_FORWARD_AMPLITUDE_MIN, self.WALK_FORWARD_AMPLITUDE_MAX, str),
		self.RUN_FORWARD_AMPLITUDE,
		run
	)
	local ba = self:mix(
		self:mix(self.WALK_BACK_AMPLITUDE_MIN, self.WALK_BACK_AMPLITUDE_MAX, str),
		self.RUN_BACK_AMPLITUDE,
		run
	)
	local ang = (if swing >= 0 then swing * fa else swing * ba) + run * self.RUN_FORWARD_BIAS
	local d = -t.up * math.cos(ang) + t.look * math.sin(ang)
	local fwd = math.clamp(math.sin(ang), 0, 1)
	local back = math.clamp(-math.sin(ang), 0, 1)
	d += t.up * (run * (self.RUN_UP_BIAS * fwd + self.RUN_BACK_LIFT * back))
	local side = self:mix(self.WALK_SIDE_OUT, self.RUN_SIDE_OUT, run)
		- fwd * self:mix(self.WALK_INWARD, self.RUN_INWARD, run)
	d += t.right * (self.sign * side)
	return self:pose(d, -t.up, self:mix(self.WALK_TWIST, self.RUN_TWIST, run) * (0.35 + 0.65 * fwd))
end

IKR6Arm.pose_walk = IKR6Arm.pose_gait
IKR6Arm.pose_run = IKR6Arm.pose_gait

function IKR6Arm:pose_jump(t: TorsoData, m: MotionData, _sh: vector): (vector?, number)
	local fall = math.clamp(-m.velocity.y / math.max(self.JUMP_FALLING_REFERENCE, 0.001), 0, 1)
	local ph = self.sway_phase * self.JUMP_SWAY_FREQUENCY + self:phase()
	local sway = math.sin(ph) * self.JUMP_SWAY * (1 - fall * self.JUMP_FALL_SWAY_REDUCE)
	local lift = self.JUMP_UP - fall * self.JUMP_FALL_LOWER
	local fwd = (self.JUMP_FORWARD + sway) * (1 - fall * self.JUMP_FALL_FORWARD_REDUCE)
	local side = self.JUMP_SIDE_OUT + fall * self.JUMP_LANDING_SPREAD
	return self:pose(t.up * lift + t.look * fwd + t.right * (self.sign * side), -t.up, 0)
end

function IKR6Arm:pose_fly(t: TorsoData, m: MotionData, _sh: vector): (vector?, number)
	local fall = math.clamp(-m.velocity.y / math.max(self.FLY_FALLING_REFERENCE, 0.001), 0, 1)
	local ph = self.sway_phase * self.FLY_SWAY_FREQUENCY + self:phase()
	local sway = math.sin(ph) * self.FLY_SWAY * (1 - fall * self.FLY_FALL_SWAY_REDUCE)
	local lift = self.FLY_LIFT - fall * self.FLY_FALL_LOWER
	local fwd = (self.FLY_FORWARD + sway) * (1 - fall * self.FLY_FALL_FORWARD_REDUCE)
	local side = self.FLY_SIDE_OUT + fall * self.FLY_LANDING_SPREAD
	return self:pose(t.up * lift + t.look * fwd + t.right * (self.sign * side), -t.up, 0)
end

function IKR6Arm:pose_pushed(t: TorsoData, m: MotionData, _sh: vector): (vector?, number)
	local ph = self.sway_phase * self.PUSHED_SWAY_FREQUENCY + self:phase()
	local sway = math.sin(ph) * self.PUSHED_SWAY
	local sp = vector.magnitude(m.horizontal)
	local lat = 0
	if sp > self.ARM_DIRECTION_EPSILON then
		lat = vector.dot(m.horizontal / sp, t.right) * self.PUSHED_VELOCITY_BIAS
	end
	return self:pose(
		t.look * self.PUSHED_FORWARD + t.up * (self.PUSHED_UP + sway) + t.right * (self.sign * self.PUSHED_SIDE + lat),
		-t.up,
		self.PUSHED_TWIST
	)
end

function IKR6Arm:pose_take(t: TorsoData, _m: MotionData, sh: vector): (vector?, number)
	local tg = self.take_target
	if not tg then
		return nil, 0
	end
	if not self:is_target_reachable(t, sh, tg, true) then
		return nil, 0
	end
	local d = tg - sh
	local l = vector.magnitude(d)
	if l <= self.ARM_DIRECTION_EPSILON then
		return nil, 0
	end
	return d / l, 0
end

function IKR6Arm:pose_hold(t: TorsoData, _m: MotionData, sh: vector): (vector?, number)
	local d = self.rig:compute_hold_hand_point(self, t, sh, true)
	if not d then
		return nil, 0
	end
	local v = d - sh
	local l = vector.magnitude(v)
	if l <= self.ARM_DIRECTION_EPSILON then
		return nil, 0
	end
	return v / l, 0
end

-- ==== IDLE SUBSTATE POSES ========================================
function IKR6Arm:sub_pose_crossed(t: TorsoData, _m: MotionData): (vector?, number)
	local rig = self.rig
	local layer = if self.side == "left" then self.IDLE_CROSSED_LAYER else -self.IDLE_CROSSED_LAYER
	local br = math.sin(rig.elapsed * self.IDLE_BREATH_FREQUENCY) * self.IDLE_BREATH_AMPLITUDE
	local d = -t.up * self.IDLE_CROSSED_DOWN
		+ t.up * (layer + br)
		+ t.look * self.IDLE_CROSSED_FORWARD
		+ self:inward(t) * self.IDLE_CROSSED_INWARD
	return self:pose(d, -t.up, self.IDLE_CROSSED_TWIST)
end

function IKR6Arm:sub_pose_behind(t: TorsoData, _m: MotionData): (vector?, number)
	local rig = self.rig
	local sw = rig.gait_swing * (if self.side == "left" then 1 else -1) * rig.gait_strength * self.IDLE_BEHIND_WALK_SWAY
	local d = -t.up * self.IDLE_BEHIND_DOWN
		- t.look * (self.IDLE_BEHIND_BACK - sw)
		+ self:inward(t) * self.IDLE_BEHIND_INWARD
	return self:pose(d, -t.up, self.IDLE_BEHIND_TWIST)
end

function IKR6Arm:sub_pose_action(t: TorsoData, m: MotionData): (vector?, number)
	local f = self["action_pose_" .. self.rig.idle_action]
	if f then
		return f(self, t, m)
	end
	return nil, 0
end

function IKR6Arm:action_pose_watch(t: TorsoData, _m: MotionData): (vector?, number)
	if self.side ~= self.rig.idle_side then
		return nil, 0
	end
	return self:pose(
		-t.up * self.IDLE_WATCH_DOWN + t.look * self.IDLE_WATCH_FORWARD + self:inward(t) * self.IDLE_WATCH_INWARD,
		-t.up,
		self.IDLE_WATCH_TWIST
	)
end

function IKR6Arm:action_pose_scratch(t: TorsoData, _m: MotionData): (vector?, number)
	local rig = self.rig
	if self.side ~= rig.idle_side then
		return nil, 0
	end
	local sway = math.sin(rig.elapsed * self.IDLE_SCRATCH_FREQUENCY) * self.IDLE_SCRATCH_SWAY
	return self:pose(
		t.up * self.IDLE_SCRATCH_UP
			+ t.look * (self.IDLE_SCRATCH_FORWARD + sway)
			+ self:inward(t) * self.IDLE_SCRATCH_INWARD,
		-t.up,
		0
	)
end

function IKR6Arm:action_pose_stretch(t: TorsoData, _m: MotionData): (vector?, number)
	local rig = self.rig
	local sway = math.sin(rig.elapsed * self.IDLE_STRETCH_FREQUENCY + self:phase()) * self.IDLE_STRETCH_SWAY
	return self:pose(
		t.up + t.right * (self.sign * (self.IDLE_STRETCH_SIDE + sway)) - t.look * self.IDLE_STRETCH_BACK,
		t.up,
		0
	)
end

-- ==== POSE BLEND =================================================
function IKR6Arm:state_pose(t: TorsoData, m: MotionData, sh: vector): (vector, number)
	local rig = self.rig
	local f = self["pose_" .. rig.state]
	if f then
		local d, tw = f(self, t, m, sh)
		if d then
			return d, tw
		end
	end
	local g = self["pose_" .. rig.auto_state]
	if g then
		local d, tw = g(self, t, m, sh)
		if d then
			return d, tw
		end
	end
	return -t.up, 0
end

function IKR6Arm:blended_pose(t: TorsoData, m: MotionData, sh: vector): (vector, number)
	local rig = self.rig
	local d, tw = self:state_pose(t, m, sh)
	local w = rig.idle_weight * rig:idle_envelope()
	if w > 0 then
		local f = self["sub_pose_" .. rig.idle_sub]
		if f then
			local sd, stw = f(self, t, m)
			if sd then
				d = self:nlerp(d, sd, w)
				tw = self:mix(tw, stw, w)
			end
		end
	end
	return d, tw
end

-- ==== ARM UPDATE =================================================
function IKR6Arm:update(t: TorsoData, m: MotionData, dt: number)
	if not self.part or not self.rig then
		return
	end
	local rig = self.rig
	local ss = self:speed_scale(m)
	self.sway_phase += dt * self:sway_rate(m)

	local sock_l = self:socket_local(t)
	local top_l = self:top_local(t)
	local top_w = t.position + self:to_world(t, top_l)

	self.collision_radius = self:damp(
		self.collision_radius,
		math.min(self.part.Size.X, self.part.Size.Z) * self.ARM_COLLISION_RADIUS_COEF,
		self.ARM_COLLISION_RADIUS_SMOOTH,
		dt
	)

	local dir, twist = self:blended_pose(t, m, top_w)
	dir = self:to_world(t, self:clamp_rotation(self:to_local(t, dir)))

	local off = self:dynamic_shoulder_offset(t, m, top_w)
	local geom = vector.magnitude(top_l - sock_l)
	local ref = math.max(geom, self.ARM_DIRECTION_EPSILON)

	local hard: number? = if self.ARM_SHOULDER_ROOT_DISTANCE > 0 then self.ARM_SHOULDER_ROOT_DISTANCE else nil

	local retracted = top_l + (sock_l - top_l) * self.shoulder_retract
	local target_sh_l = retracted + off
	if hard ~= nil then
		local rel = target_sh_l - sock_l
		local rl = vector.magnitude(rel)
		local allow = math.max(hard * (1 - self.shoulder_retract), 0)
		if rl > allow and rl > self.ARM_DIRECTION_EPSILON then
			target_sh_l = sock_l + rel / rl * allow
		end
	end

	local shoulder_speed = self.SHOULDER_SMOOTH * self:mix(1, ss, self.ARM_SHOULDER_SPEED_WEIGHT)
	self.smooth_shoulder_local = self:damp_vec(self.smooth_shoulder_local, target_sh_l, shoulder_speed, dt)
	local sh = t.position + self:to_world(t, self.smooth_shoulder_local)

	if rig.state == "take" and self.take_target and self:is_target_reachable(t, sh, self.take_target, true) then
		dir = self:norm_or(self.take_target - sh, dir)
		twist = 0
	elseif rig.state == "hold" and rig.hold_target and rig.hold_root then
		local hp = rig:compute_hold_hand_point(self, t, sh, true)
		if hp then
			dir = self:norm_or(hp - sh, dir)
			twist = 0
		end
	end

	dir = self:to_world(t, self:clamp_rotation(self:to_local(t, dir)))
	local intended = dir

	local coll_dir, hit_n, hit_s = self:resolve_collision(t, sh, dir)
	local wn, ws = self:query_side_wall(t, sh, coll_dir)
	if hit_n ~= nil then
		wn = hit_n
		ws = math.max(ws, hit_s)
	end
	coll_dir = self:apply_wall_constraint(t, coll_dir, wn, ws)

	-- отклонение только от коллизий (без IK-бленда и защиты корпуса),
	-- чтобы втягивание плеча не залипало после стены
	local vlen = self.part.Size.Y
	local dev_dot = math.clamp(vector.dot(intended, coll_dir), -1, 1)
	local dev_ang = math.acos(dev_dot)
	local dev_dist = vlen * math.sin(dev_ang)

	coll_dir = self:keep_direction_out_of_torso(t, sh, coll_dir)

	self.elbow_blend = self:damp(
		self.elbow_blend,
		self:mix(self.ARM_ELBOW_BASE_BLEND, self.ARM_ELBOW_RUN_BLEND, rig.run_blend),
		self.ARM_ELBOW_BLEND_SPEED,
		dt
	)

	local reach = self:reach_scale(m)
	local ik = self:solve_ik(t, sh, sh + coll_dir * (vlen * reach))
	local ik_dir = self:norm_or(self:nlerp(ik.upper_dir, ik.lower_dir, self.elbow_blend), coll_dir)
	local ew = math.clamp(self.ARM_ELBOW_DIRECTION_WEIGHT + rig.run_blend * self.ARM_ELBOW_RUN_DIRECTION_BOOST, 0, 1)
	local final_dir = self:norm_or(self:nlerp(coll_dir, ik_dir, ew), coll_dir)
	final_dir = self:to_world(t, self:clamp_rotation(self:to_local(t, final_dir)))
	local fix_dir = self:resolve_collision(t, sh, final_dir)
	fix_dir = self:apply_wall_constraint(t, fix_dir, wn, ws)
	final_dir = self:keep_direction_out_of_torso(t, sh, fix_dir)

	local wall_boost = if wn ~= nil then self.ARM_SHOULDER_RETRACT_WALL_BOOST * ws else 0

	local retract_ref = ref
	if hard ~= nil then
		retract_ref = math.max(hard, self.ARM_DIRECTION_EPSILON)
	end
	local retract_lim = 1
	if self.ARM_SHOULDER_RETRACT_MAX_DISTANCE > 0 then
		retract_lim = math.clamp(self.ARM_SHOULDER_RETRACT_MAX_DISTANCE / retract_ref, 0, 1)
	end
	local retract_t = math.clamp((dev_dist + wall_boost) / retract_ref, 0, retract_lim)
	self.shoulder_retract = self:damp(self.shoulder_retract, retract_t, self.ARM_SHOULDER_RETRACT_SPEED, dt)

	local fs = self:follow_speed(m)
	local sm = self:clamp_rotation(self:to_local(t, final_dir))
	self.smooth_local = self:damp_nlerp(self.smooth_local, sm, fs, dt)
	self.smooth_twist = self:damp(self.smooth_twist, twist, fs, dt)
	local d = self:to_world(t, self.smooth_local)
	local cf_ik = self:solve_ik(t, sh, sh + d * (vlen * reach))
	self.part.CFrame = self:cframe(t, sh, d, self.smooth_twist, cf_ik)
end

-- ==== IKR6Arms ===================================================
local IKR6Arms: Dict = setmetatable({}, { __index = Proto })
IKR6Arms.__index = IKR6Arms
IKR6Arms.Arm = IKR6Arm

IKR6Arms.defaults = {
	MAX_DELTA = 1 / 15,
	SEARCH_HUMANOID_ATTEMPTS = 3,
	ARM_VISUAL_SUFFIX = "_VIS",
	ARM_QUERY_REFRESH_TIME = 1,
	DESTROY_ON_DEATH = true,

	-- переходы состояний
	WALK_STATE_MIN_SPEED = 0.6,
	WALK_STATE_MIN_INPUT = 0.01,
	RUN_SPEED_REFERENCE = 32,
	RUN_LINEAR_ENTER_SPEED = 18,
	RUN_LINEAR_EXIT_SPEED = 15.5,
	RUN_BLEND_SPEED = 5,

	-- ТЕМП ПОХОДКИ ОТ СКОРОСТИ
	WALK_FREQUENCY_MIN = 4.2,
	WALK_FREQUENCY_MAX = 9.5,
	RUN_FREQUENCY_MIN = 9,
	RUN_FREQUENCY_MAX = 13,
	GAIT_TEMPO_SMOOTH = 4,
	GAIT_STRENGTH_SMOOTH = 6,
	GAIT_STRIDE_WALK = 10.5,
	GAIT_STRIDE_RUN = 14,
	GAIT_SPEED_TEMPO_WEIGHT = 1,
	GAIT_TEMPO_STRENGTH_FLOOR = 0.25,

	-- отброс
	PUSHED_HORIZONTAL_SPEED = 42,
	PUSHED_WALKSPEED_COEF = 1.75,
	PUSHED_LINEAR_SPEED = 75,
	PUSHED_FREEFALL_TIME = 1.2,
	PUSHED_FREEFALL_SPEED = 70,
	PUSHED_HOLD_TIME = 0.45,
	pushed_states = {
		[Enum.HumanoidStateType.FallingDown] = true,
		[Enum.HumanoidStateType.Ragdoll] = true,
		[Enum.HumanoidStateType.Physics] = true,
	},

	-- idle-подсостояния (планировщик)
	IDLE_SLOW_WALK_SPEED = 7,
	IDLE_SUBSTATE_DURATION_MIN = 6,
	IDLE_SUBSTATE_DURATION_MAX = 14,
	IDLE_SUBSTATE_COOLDOWN_MIN = 2.5,
	IDLE_SUBSTATE_COOLDOWN_MAX = 6,
	IDLE_SUBSTATE_BLEND_SPEED = 4,
	IDLE_SUBSTATE_REPICK_WEIGHT = 0.02,
	IDLE_ACTION_EASE = 0.25,

	sub_order = { "crossed", "behind", "action" },
	idle_actions = { "watch", "scratch", "stretch" },

	sub_min_time = {
		none = math.huge,
		crossed = 7,
		behind = 9,
		action = 4,
	},
	sub_weight = {
		none = 0,
		crossed = 1,
		behind = 1,
		action = 1.4,
	},
	sub_compat = {
		none = {},
		crossed = { idle = math.huge },
		behind = { idle = math.huge, walk = 7 },
		action = { idle = math.huge },
	},
	action_durations = {
		watch = 2.4,
		scratch = 1.8,
		stretch = 2.8,
	},

	-- удержание: дистанции кистей разаются рукам при сборке
	HOLD_RIGHT_HAND_DISTANCE = 0.15,
	HOLD_LEFT_HAND_DISTANCE = 0.95,

	valid_states = {
		idle = true,
		walk = true,
		run = true,
		jump = true,
		fly = true,
		pushed = true,
		take = true,
		hold = true,
	},
	valid_substates = { none = true, crossed = true, behind = true, action = true },
}

function IKR6Arms.new(character: Model, opts: Dict?): Dict
	local self: Dict = setmetatable({}, IKR6Arms) :: any
	self:apply_defaults(Proto.defaults)
	self:apply_defaults(IKR6Arms.defaults)
	self:configure(opts)

	local o: Dict = opts or {}
	self._arm_opts = self:clone_value(o.arm)
	self._left_opts = self:clone_value(o.left)
	self._right_opts = self:clone_value(o.right)

	self.character = character
	self.world = o.world or character:FindFirstAncestorOfClass("Workspace")
	self.humanoid = o.humanoid
	self.torso = o.torso
	self.rng = if o.seed ~= nil then Random.new(o.seed) else Random.new()

	self.left = nil
	self.right = nil
	self.supported = false
	self.destroyed = false
	self._build_attempts = 0

	self.state = "idle"
	self.auto_state = "idle"
	self.manual_state = nil
	self.state_time = 0
	self.elapsed = 0
	self.walk_phase = 0
	self.gait_frequency = self.WALK_FREQUENCY_MIN
	self.gait_strength = 0
	self.gait_swing = 0
	self.run_active = false
	self.run_blend = 0
	self.pushed_time = 0
	self.freefall_time = 0
	self.idle_time = 0
	self.idle_sub = "none"
	self.idle_active = false
	self.idle_sub_time = 0
	self.idle_sub_duration = 0
	self.idle_cooldown = 0
	self.idle_weight = 0
	self.idle_action = "watch"
	self.idle_side = "right"
	self.hold_target = nil
	self.hold_root = nil
	self.query_time = 0
	self.rayparams = nil
	self.overlap_params = nil

	self:build()
	return self
end

-- ==== BUILD / LIFETIME ===========================================
function IKR6Arms:find_limb(h: Humanoid, m: Model, limb: Enum.Limb): BasePart?
	local suffix = self.ARM_VISUAL_SUFFIX
	for _, v in m:GetChildren() do
		if v.Name:sub(-#suffix) == suffix then
			continue
		end
		if v:IsA("BasePart") and h:GetLimb(v) == limb then
			return v
		end
	end
	return nil
end

function IKR6Arms:build(): boolean
	if self.supported or self.destroyed then
		return self.supported
	end
	local c = self.character
	if not c or not c.Parent then
		return false
	end
	self._build_attempts += 1

	local h: Humanoid? = self.humanoid or c:FindFirstChildOfClass("Humanoid")
	if not h then
		return false
	end
	if h.RigType ~= Enum.HumanoidRigType.R6 then
		self._build_attempts = math.huge
		return false
	end

	local lo = self:find_limb(h, c, Enum.Limb.LeftArm)
	local ro = self:find_limb(h, c, Enum.Limb.RightArm)
	local tor = self.torso or self:find_limb(h, c, Enum.Limb.Torso)
	if not lo or not ro or not tor then
		return false
	end

	self.humanoid = h
	self.torso = tor

	local common = { ARM_VISUAL_SUFFIX = self.ARM_VISUAL_SUFFIX }
	self.left = IKR6Arm.new(
		lo,
		"left",
		-1,
		c,
		self:merged(common, { HOLD_HAND_DISTANCE = self.HOLD_LEFT_HAND_DISTANCE }, self._arm_opts, self._left_opts)
	)
	self.right = IKR6Arm.new(
		ro,
		"right",
		1,
		c,
		self:merged(common, { HOLD_HAND_DISTANCE = self.HOLD_RIGHT_HAND_DISTANCE }, self._arm_opts, self._right_opts)
	)
	self.left.rig = self
	self.right.rig = self

	local td = self:torso_data()
	self.left.smooth_shoulder_local = self.left:top_local(td)
	self.right.smooth_shoulder_local = self.right:top_local(td)

	self:refresh_queries()
	self.supported = true
	return true
end

function IKR6Arms:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.supported = false
	if self.left then
		self.left:destroy()
		self.left = nil
	end
	if self.right then
		self.right:destroy()
		self.right = nil
	end
	self.rayparams = nil
	self.overlap_params = nil
	self.hold_target = nil
	self.hold_root = nil
end

IKR6Arms.cleanup = IKR6Arms.destroy

function IKR6Arms:is_alive(): boolean
	local c, t, h = self.character, self.torso, self.humanoid
	if not c or not c.Parent or not t or not t.Parent or not h or not h.Parent then
		return false
	end
	if self.DESTROY_ON_DEATH and h.Health <= 0 then
		return false
	end
	return true
end

function IKR6Arms:set_world(world: any)
	self.world = world
	return self
end

function IKR6Arms:refresh_queries()
	self.query_time = 0
	local c = self.character
	local r = RaycastParams.new()
	r.FilterType = Enum.RaycastFilterType.Exclude
	r.RespectCanCollide = true
	r.BruteForceAllSlow = false
	r.IgnoreWater = true
	r.ExcludeInstances = c:GetDescendants()
	self.rayparams = r

	local p = OverlapParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.MaxParts = 64
	p.FilterDescendantsInstances = c:GetDescendants()
	self.overlap_params = p
	return self
end

-- ==== DATA =======================================================
function IKR6Arms:torso_data(): TorsoData
	local t = self.torso
	local cf, sz = t.CFrame, t.Size
	return {
		position = self:vec(cf.Position),
		right = self:vec(cf.RightVector),
		up = self:vec(cf.UpVector),
		look = self:vec(cf.LookVector),
		half_x = sz.X * self.left.SHOULDER_SIDE_COEF,
		half_y = sz.Y * self.left.SHOULDER_UP_COEF,
		half = vector.create(sz.X * 0.5, sz.Y * 0.5, sz.Z * 0.5),
	}
end

function IKR6Arms:motion_data(): MotionData
	local h = self.humanoid
	local root = h.RootPart
	local vel = if root then self:vec(root.AssemblyLinearVelocity) else vector.zero
	local hz = vector.create(vel.x, 0, vel.z)
	local sp = vector.magnitude(hz)
	local lin = vector.magnitude(vel)
	local ws = math.max(h.WalkSpeed, 0.001)
	local run_ref = math.max(self.RUN_SPEED_REFERENCE, self.RUN_LINEAR_ENTER_SPEED + 0.001)
	local run_range = math.max(run_ref - self.RUN_LINEAR_ENTER_SPEED, 0.001)
	return {
		velocity = vel,
		horizontal = hz,
		speed = sp,
		linear_speed = lin,
		walk_factor = math.clamp(sp / ws, 0, 1),
		run_factor = math.clamp((lin - self.RUN_LINEAR_ENTER_SPEED) / run_range, 0, 1),
		input = math.clamp(vector.magnitude(self:vec(h.MoveDirection)), 0, 1),
	}
end

-- ==== HOLD =======================================================
function IKR6Arms:compute_hold_hand_point(a: Dict, t: TorsoData, sh: vector, react: boolean): vector?
	local tg, root = self.hold_target, self.hold_root
	if not tg or not root then
		return nil
	end
	local aim = tg - root
	local al = vector.magnitude(aim)
	aim = if al <= self.ARM_DIRECTION_EPSILON then t.look else aim / al
	local d = root + aim * a.HOLD_HAND_DISTANCE
	local perp = t.right - aim * vector.dot(t.right, aim)
	local pl = vector.magnitude(perp)
	if pl <= self.ARM_DIRECTION_EPSILON then
		perp = t.up - aim * vector.dot(t.up, aim)
		pl = vector.magnitude(perp)
	end
	if pl > self.ARM_DIRECTION_EPSILON then
		d += (perp / pl) * (a.sign * a.HOLD_HAND_SIDE_SPREAD)
	end
	if not a:is_target_reachable(t, sh, d, false) then
		return nil
	end
	if react then
		local ph = self.elapsed * a.HOLD_REACTION_FREQUENCY + (if a.side == "left" then 0 else a.HOLD_REACTION_PHASE)
		d += t.right * (math.sin(ph) * a.HOLD_REACTION_SIDE) + t.up * (math.cos(ph) * a.HOLD_REACTION_UP)
	end
	return d
end

-- ==== STATES =====================================================
function IKR6Arms:is_pushed_now(m: MotionData, hs: Enum.HumanoidStateType): boolean
	if self.pushed_states[hs] == true then
		return true
	end
	if self.humanoid.Sit then
		return false
	end
	if hs == Enum.HumanoidStateType.Freefall then
		if self.freefall_time >= self.PUSHED_FREEFALL_TIME or -m.velocity.y >= self.PUSHED_FREEFALL_SPEED then
			return true
		end
	end
	local lim = math.max(self.PUSHED_HORIZONTAL_SPEED, self.humanoid.WalkSpeed * self.PUSHED_WALKSPEED_COEF)
	return m.speed >= lim or m.linear_speed >= self.PUSHED_LINEAR_SPEED
end

function IKR6Arms:update_pushed(m: MotionData, dt: number)
	local hs = self.humanoid:GetState()
	if hs == Enum.HumanoidStateType.Freefall then
		self.freefall_time += dt
	else
		self.freefall_time = 0
	end
	if self:is_pushed_now(m, hs) then
		self.pushed_time = self.PUSHED_HOLD_TIME
	else
		self.pushed_time = math.max(self.pushed_time - dt, 0)
	end
end

function IKR6Arms:update_run(m: MotionData)
	local sp = m.linear_speed
	if self.run_active and sp < self.RUN_LINEAR_EXIT_SPEED then
		self.run_active = false
	elseif not self.run_active and sp > self.RUN_LINEAR_ENTER_SPEED then
		self.run_active = true
	end
end

function IKR6Arms:detect_auto(m: MotionData): SolverState
	if self.pushed_time > 0 then
		return "pushed"
	end
	local hs = self.humanoid:GetState()
	if hs == Enum.HumanoidStateType.Flying then
		return "fly"
	end
	if hs == Enum.HumanoidStateType.Jumping or hs == Enum.HumanoidStateType.Freefall then
		return "jump"
	end
	if self.humanoid.FloorMaterial == Enum.Material.Air then
		return "jump"
	end
	local mv = self:vec(self.humanoid.MoveDirection)
	if vector.magnitude(mv) >= self.WALK_STATE_MIN_INPUT or m.speed >= self.WALK_STATE_MIN_SPEED then
		return if self.run_active then "run" else "walk"
	end
	return "idle"
end

function IKR6Arms:resolve_state(): SolverState
	if self.auto_state == "pushed" then
		return "pushed"
	end
	if self.manual_state then
		return self.manual_state
	end
	if self.hold_target and self.hold_root then
		return "hold"
	end
	if (self.left and self.left.take_target) or (self.right and self.right.take_target) then
		return "take"
	end
	return self.auto_state
end

-- ==== GAIT (темп от реальной скорости) ============================
function IKR6Arms:update_gait(m: MotionData, dt: number)
	local is_gait = self.state == "walk" or self.state == "run"
	local run_t = if self.state == "run" then 1 else 0
	local str_t = if is_gait then math.clamp(math.max(m.walk_factor, m.input * 0.35), 0, 1) else 0
	self.run_blend = self:damp(self.run_blend, run_t, self.RUN_BLEND_SPEED, dt)
	self.gait_strength = self:damp(self.gait_strength, str_t, self.GAIT_STRENGTH_SMOOTH, dt)

	local run = self.run_blend
	local fmin = self:mix(self.WALK_FREQUENCY_MIN, self.RUN_FREQUENCY_MIN, run)
	local fmax = self:mix(self.WALK_FREQUENCY_MAX, self.RUN_FREQUENCY_MAX, run)
	local stride = math.max(self:mix(self.GAIT_STRIDE_WALK, self.GAIT_STRIDE_RUN, run), self.ARM_DIRECTION_EPSILON)
	local speed_rate = (m.speed / stride) * math.pi * 2
	local factor_rate = self:mix(
		self:mix(self.WALK_FREQUENCY_MIN, self.WALK_FREQUENCY_MAX, m.walk_factor),
		self:mix(self.RUN_FREQUENCY_MIN, self.RUN_FREQUENCY_MAX, m.run_factor),
		run
	)
	local target =
		math.clamp(self:mix(factor_rate, speed_rate, math.clamp(self.GAIT_SPEED_TEMPO_WEIGHT, 0, 1)), fmin, fmax)
	self.gait_frequency = self:damp(self.gait_frequency, target, self.GAIT_TEMPO_SMOOTH, dt)

	if not is_gait then
		self.gait_swing = self:damp(self.gait_swing, 0, self.GAIT_STRENGTH_SMOOTH, dt)
		return
	end
	local floor = math.clamp(self.GAIT_TEMPO_STRENGTH_FLOOR, 0, 1)
	local ps = math.max(0, self.gait_frequency * (floor + (1 - floor) * self.gait_strength))
	self.walk_phase = (self.walk_phase + dt * ps) % (math.pi * 2)
	self.gait_swing = math.sin(self.walk_phase)
end

-- ==== IDLE SUBSTATES =============================================
function IKR6Arms:idle_envelope(): number
	if self.idle_sub ~= "action" then
		return 1
	end
	local p = math.clamp(self.idle_sub_time / math.max(self.idle_sub_duration, 0.001), 0, 1)
	return self:smoothstep(math.min(p, 1 - p) / math.max(self.IDLE_ACTION_EASE, 0.001))
end

function IKR6Arms:is_idle_compat(sub: IdleSubState, sp: number): boolean
	local lim = self.sub_compat[sub]
	if not lim then
		return false
	end
	local l = lim[self.state]
	return l ~= nil and sp <= l
end

function IKR6Arms:stop_sub()
	self.idle_active = false
	self.idle_cooldown = self.rng:NextNumber(self.IDLE_SUBSTATE_COOLDOWN_MIN, self.IDLE_SUBSTATE_COOLDOWN_MAX)
end

function IKR6Arms:start_sub(sub: IdleSubState)
	if sub == "none" then
		if self.idle_active then
			self:stop_sub()
		end
		return
	end
	self.idle_sub = sub
	self.idle_active = true
	self.idle_sub_time = 0
	self.idle_action = self.idle_actions[self.rng:NextInteger(1, #self.idle_actions)] or "watch"
	self.idle_side = if self.rng:NextNumber() < 0.5 then "left" else "right"
	self.idle_sub_duration = if sub == "action"
		then self.action_durations[self.idle_action]
		else self.rng:NextNumber(self.IDLE_SUBSTATE_DURATION_MIN, self.IDLE_SUBSTATE_DURATION_MAX)
end

function IKR6Arms:pick_sub(): IdleSubState
	local total = 0
	for _, s in self.sub_order do
		if self.idle_time >= (self.sub_min_time[s] or math.huge) then
			total += self.sub_weight[s] or 0
		end
	end
	if total <= 0 then
		return "none"
	end
	local roll = self.rng:NextNumber(0, total)
	for _, s in self.sub_order do
		if self.idle_time >= (self.sub_min_time[s] or math.huge) then
			roll -= self.sub_weight[s] or 0
			if roll <= 0 then
				return s
			end
		end
	end
	return "none"
end

function IKR6Arms:update_idle(m: MotionData, dt: number)
	local compat = self.idle_active and self:is_idle_compat(self.idle_sub, m.speed)
	if self.state == "idle" then
		self.idle_time += dt
	elseif not compat then
		self.idle_time = 0
	end
	if self.idle_active then
		self.idle_sub_time += dt
		if not compat or self.idle_sub_time >= self.idle_sub_duration then
			self:stop_sub()
		end
	else
		self.idle_cooldown = math.max(self.idle_cooldown - dt, 0)
		if
			self.state == "idle"
			and self.idle_cooldown <= 0
			and self.idle_weight <= self.IDLE_SUBSTATE_REPICK_WEIGHT
		then
			local s = self:pick_sub()
			if s ~= "none" then
				self:start_sub(s)
			end
		end
	end
	self.idle_weight =
		self:damp(self.idle_weight, if self.idle_active then 1 else 0, self.IDLE_SUBSTATE_BLEND_SPEED, dt)
	if not self.idle_active and self.idle_weight <= self.IDLE_SUBSTATE_REPICK_WEIGHT then
		self.idle_weight = 0
		self.idle_sub = "none"
	end
end

-- ==== TICK =======================================================
function IKR6Arms:update(dt: number)
	if self.destroyed then
		return
	end
	if not self.supported then
		if self._build_attempts < self.SEARCH_HUMANOID_ATTEMPTS then
			self:build()
		end
		if not self.supported then
			return
		end
	end
	if not self:is_alive() then
		self:destroy()
		return
	end
	if not self.world then
		self.world = self.character:FindFirstAncestorOfClass("Workspace")
	end

	local step = math.min(dt, self.MAX_DELTA)
	local m = self:motion_data()
	self.elapsed += step
	self.state_time += step
	self.query_time += step
	if self.query_time >= self.ARM_QUERY_REFRESH_TIME then
		self:refresh_queries()
	end

	self:update_pushed(m, step)
	self:update_run(m)
	self.auto_state = self:detect_auto(m)
	local ns = self:resolve_state()
	if ns ~= self.state then
		self.state = ns
		self.state_time = 0
	end

	local t = self:torso_data()
	self:update_gait(m, step)
	self:update_idle(m, step)
	self.left:update(t, m, step)
	self.right:update(t, m, step)
	return self
end

-- ==== PUBLIC API =================================================
function IKR6Arms:is_supported(): boolean
	return self.supported and not self.destroyed
end

function IKR6Arms:get_arm(side: ArmSide): Dict?
	if side == "left" then
		return self.left
	elseif side == "right" then
		return self.right
	end
	return nil
end

function IKR6Arms:set_state(name: string?)
	if not self.supported then
		return self
	end
	if name == nil then
		self.manual_state = nil
		return self
	end
	if not self.valid_states[name] then
		warn(`[IKR6Arms] unknown state "{name}"`)
		return self
	end
	self.manual_state = name
	return self
end

function IKR6Arms:get_state(): SolverState?
	if not self.supported then
		return nil
	end
	return self.state
end

function IKR6Arms:set_idle_substate(name: string)
	if not self.supported then
		return self
	end
	if not self.valid_substates[name] then
		warn(`[IKR6Arms] unknown idle substate "{name}"`)
		return self
	end
	self:start_sub(name :: IdleSubState)
	return self
end

function IKR6Arms:get_idle_substate(): IdleSubState?
	if not self.supported then
		return nil
	end
	return if self.idle_active then self.idle_sub else "none"
end

function IKR6Arms:set_take_target(side: ArmSide | string, target: vector)
	if not self.supported then
		return self
	end
	if side == "left" then
		self.left.take_target = target
	elseif side == "right" then
		self.right.take_target = target
	elseif side == "both" then
		self.left.take_target = target
		self.right.take_target = target
	else
		warn(`[IKR6Arms] unknown arm side "{side}"`)
	end
	return self
end

function IKR6Arms:clear_take_target(side: ArmSide | string)
	if not self.supported then
		return self
	end
	if side == "left" then
		self.left.take_target = nil
	elseif side == "right" then
		self.right.take_target = nil
	elseif side == "both" then
		self.left.take_target = nil
		self.right.take_target = nil
	else
		warn(`[IKR6Arms] unknown arm side "{side}"`)
	end
	return self
end

function IKR6Arms:clear_take_targets()
	if not self.supported then
		return self
	end
	self.left.take_target = nil
	self.right.take_target = nil
	return self
end

function IKR6Arms:set_hold_target(target: vector, target_root: vector)
	if not self.supported then
		return self
	end
	self.hold_target = target
	self.hold_root = target_root
	return self
end

function IKR6Arms:set_hold_target_local(target_offset: vector, target_root_offset: vector)
	if not self.supported then
		return self
	end
	local t = self:torso_data()
	self.hold_target = t.position + t.right * target_offset.x + t.up * target_offset.y + t.look * target_offset.z
	self.hold_root = t.position
		+ t.right * target_root_offset.x
		+ t.up * target_root_offset.y
		+ t.look * target_root_offset.z
	return self
end

function IKR6Arms:clear_hold_target()
	self.hold_target = nil
	self.hold_root = nil
	return self
end

return IKR6Arms
