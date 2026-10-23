--!strict
const Maybe = require("@class/common/gc/Maybe")
const IKR6Foot = require("@class/game/play/characters/ik/r6/IKR6Foot")
const IKR6Solver = require("@class/game/play/characters/ik/r6/IKR6Solver")
const IKR6Info = require("@class/struct/game/ik/IKR6Info")
const IKR6LegInfo = require("@class/struct/game/ik/IKR6LegInfo")
const Basis = require("@class/struct/geometry/Basis")
const tables = require("@declare/tables")
const ConnectionVariant = require("@enums/descriptor/ConnectionVariant")
const types = require("@declare/types")
const IKLimbMode = require("@enums/game/mode/IKLimbMode")
const ReferenceNotification = require("@enums/notification/ReferenceNotification")
const IKLegsState = require("@enums/state/IKLegsState")
const stdout = require("@extension/stdout")
const engine = require("@platform/roblox/engine")
const instance = require("@platform/roblox/instance")
const worldspace = require("@platform/roblox/worldspace")
const ctags = require("@static/ctags")
const ctype = require("@static/ctype")
const ftype = require("@static/ftype")

const private = {}
const class : ikr6legs = IKR6Solver:new {
    type = "ikr6legs",
    enabled = false,
    current_idle_time = 0,
    last_work_time = 0,

    get_left_leg = ftype:write(function (self: ikr6legs) : ikr6foot
        return private.maybe_left_legs:extract(self, private.create_left_ikr6foot)
    end, IKR6Foot.type, "ikr6legs"),

    get_right_leg = ftype:write(function (self: ikr6legs) : ikr6foot
        return private.maybe_right_legs:extract(self, private.create_right_ikr6foot)
    end, IKR6Foot.type, "ikr6legs"),

    get_active_cycle_leg_pair = ftype:write(function (self: ikr6legs) : (ikr6foot, ikr6foot)
        const left_leg = self:get_left_leg()
        const right_leg = self:get_right_leg()

        const left_ik = left_leg.mode == IKLimbMode.FakeIK
        const right_ik = right_leg.mode == IKLimbMode.FakeIK

        if left_ik ~= right_ik then
            return left_ik and left_leg or right_leg, left_ik and right_leg or left_leg
        end

        if left_leg.current then
            return left_leg, right_leg
        end
        if right_leg.current then
            return right_leg, left_leg
        end
        return left_leg, right_leg
    end, ftype:var(IKR6Foot.type), "ikr6legs"),

    is_initiated = ftype:write(function (self: ikr6legs) : boolean
        return private.maybe_left_legs:exist(self) and private.maybe_right_legs:exist(self)
    end, types.boolean, "ikr6legs"),

    is_active = ftype:write(function (self: ikr6legs) : boolean
        return private.active[self] or false
    end, types.boolean, "ikr6legs")
}

do
    type raw = {
        read torso: basis,
        read size: vector,
        read move_dir: vector,
        read linear_vel: vector,
        read horizont_linear_vel: vector,
        read walkspeed: number,
        read speed_factor: number,
        read is_moving: boolean
    }
	private.rayparams = RaycastParams.new()
	private.rayparams.FilterType = Enum.RaycastFilterType.Exclude
	private.rayparams.RespectCanCollide = true
	private.rayparams.BruteForceAllSlow = false
	private.rayparams.IgnoreWater = true
    private.rayparams.ExcludeInstances = {}
    private.default_ikr6info = IKR6Info:new()
    private.default_ikr6leginfo_left = IKR6LegInfo:new({limb_diff = -IKR6LegInfo.limb_diff})
    private.default_ikr6leginfo_right = IKR6LegInfo:new({limb_diff = IKR6LegInfo.limb_diff})
    private.list = setmetatable({} :: {ikr6legs}, tables.__mode_vs)
    private.active = setmetatable({} :: {[ikr6legs]: boolean?}, tables.__mode_ks)
    private.maybe_left_legs = Maybe:new() :: maybe<ikr6foot, ikr6legs>
    private.maybe_right_legs = Maybe:new() :: maybe<ikr6foot, ikr6legs>
    private.signal = engine.postphysic

    private.create_left_ikr6foot = function ()
        const new = IKR6Foot:new()
        new:set_info(private.default_ikr6leginfo_left)
        return new
    end

    private.create_right_ikr6foot = function ()
        const new = IKR6Foot:new()
        new:set_info(private.default_ikr6leginfo_right)
        return new
    end



    private.register_new = function (new: luaobject)
            const new = new:as <<ikr6legs>> (class.type)
            const humanoid_reference = new:get_humanoid()

            humanoid_reference:subscribe({ReferenceNotification.NewInstance, ReferenceNotification.ChangedInstance}, ConnectionVariant.Ever, function ()
                if not humanoid_reference:is_instance_exists() then return end
                const humanoid = humanoid_reference:get_instance() :: Humanoid

                if not new:get_info().prebuild_fake then return end

                const left_leg = new:get_left_leg()
                const left_limb_part = instance.humanoid.get_limb_of(humanoid, Enum.Limb.LeftLeg)
                left_leg:get_reference():set_instance(left_limb_part)

                if left_leg:is_initiated() then
                    left_leg:rebuild_fake()
                end

                const right_leg = new:get_right_leg()
                const right_limb_part = instance.humanoid.get_limb_of(humanoid, Enum.Limb.RightLeg)
                right_leg:get_reference():set_instance(right_limb_part)

                if right_leg:is_initiated() then
                    right_leg:rebuild_fake()
                end
            end
        )

        new:set_info(private.default_ikr6info)
        new:watch(private.free_legs)

        const left_leg =  new:get_left_leg()
        const right_leg = new:get_right_leg()

        const left_leg_state_machine = left_leg:get_states()
        const right_leg_state_machine = right_leg:get_states()

        left_leg_state_machine:set_state(true, IKLegsState.Planted)
        right_leg_state_machine:set_state(true, IKLegsState.Planted)

        left_leg.current = true

        private.signal:Once(function ()
            table.insert(private.list, new)
        end)
    end

    do -- global utility layer
        private.modify_params = function (with: Instance): ()
            private.rayparams.ExcludeInstances = {with}
        end

        private.mark_unactive = function (ikr6legs: ikr6legs)
            private.active[ikr6legs] = false
        end
        
        private.create_raw = function (torso: BasePart, humanoid: Humanoid) : raw
            const dir, lin, size = worldspace.to_vector(humanoid.MoveDirection, torso.AssemblyLinearVelocity, torso.Size)
            const hor_lin_vel = vector.create(lin.x, 0, lin.z)

            return table.freeze {
                torso = Basis:to_basis(torso.CFrame),
                move_dir = dir,
                linear_vel = lin,
                size = size,
                horizont_linear_vel = hor_lin_vel,
                walkspeed = humanoid.WalkSpeed,
                speed_factor = math.clamp(vector.magnitude(hor_lin_vel) / math.max(humanoid.WalkSpeed, 0.001), 0, 1),
                is_moving = vector.magnitude(dir) >= 0.01
            }
        end

        private.free_legs = function (related: disposable)
            const self = related:as <<ikr6legs>>(class.type)

            table.remove(private.list, table.find(private.list, self) or 0)

            if private.maybe_left_legs:exist(self) then
                self:get_left_leg():free()
            end

            if private.maybe_right_legs:exist(self) then
                self:get_right_leg():free()
            end
        end

    end







    do -- leg world checks layer
        private.get_step_raycast_data = function (raw: raw, info: ikr6leginfo, predicted: vector, state: enumitem_iklegs_state) : (vector, vector)
            const up = raw.torso.rotation.up
            const down = -up

            const move_length = vector.magnitude(raw.move_dir)

            local horizontal_direction: vector

            if move_length > 0.001 then
                horizontal_direction = raw.move_dir / move_length
            else
                horizontal_direction = raw.torso.rotation.front
            end

            const origin = predicted + up * info.leg_raycast_up       
            const forward = if state == IKLegsState.Stepping then info.leg_step_forward elseif state == IKLegsState.Planted then info.leg_stand_forward elseif state == IKLegsState.Settling then info.leg_idle_step_forward else 1     
            const direction = horizontal_direction * forward + down * (info.leg_raycast_up + info.leg_raycast_down)

            return origin, direction
        end

        private.is_step_blocked = function (raw: raw, foot: ikr6foot, info: ikr6leginfo, predicted: vector): boolean
            const move_length = vector.magnitude(raw.move_dir)
            if move_length <= 1e-5 then return false end

            const direction = raw.move_dir / move_length
            const up = raw.torso.rotation.up
            const obstacle_origin = predicted + up * info.leg_step_obstacle_height
            const obstacle = worldspace.raycast(obstacle_origin, direction * info.limb_block_distance, private.rayparams)
            if not obstacle then return false end

            const normal, position = worldspace.to_vector(obstacle.Normal, obstacle.Position)
            if math.abs(vector.dot(normal, up)) > 0.5 then return false end

            const top_origin = position + direction * (info.limb_size.z * 0.5 + 0.05) + up * (info.leg_step_max_height + 0.05)
            const top_result = worldspace.raycast(top_origin, -up * (info.leg_step_max_height + 0.15), private.rayparams)
            if not top_result then return true end

            const top_normal, top_position = worldspace.to_vector(top_result.Normal, top_result.Position)
            if vector.dot(top_normal, up) < 0.7 then return true end

            const height = vector.dot(top_position - predicted, up)
            return height > info.leg_step_max_height
        end
    end

    do -- leg utility layer
        private.is_valid = function (ikr6foot: ikr6foot): boolean
            const reference_to_origin = ikr6foot:get_reference()
            if not reference_to_origin:is_instance_exists() then
                --#if IKR6LEGS_PRINT_ACT
                stdout:outm("cannot process leg fallback, because origin does not exists")
                --#endif

                return false
            end

            const reference_to_fake = ikr6foot:get_fake()
            if not reference_to_fake:is_instance_exists() then
                --#if IKR6LEGS_PRINT_ACT
                    stdout:outm("cannot process leg fallback, because fake does not exists")
                --#endif

                return false
            end

            return true
        end

        private.foot_update = function (raw: raw, foot: ikr6foot, info: ikr6leginfo, raycast_result: RaycastResult)
            foot.hit_normal, foot.hit_position = worldspace.to_vector(raycast_result.Normal, raycast_result.Position)
            foot.up_direction = raw.torso.rotation.up

            const fake = foot:get_reference()
            if fake:is_instance_exists() then
                const fake_leg = fake:get_instance()
                foot.fallback_basis = Basis:to_basis(fake_leg.CFrame)
            else
                --#if IKR6LEGS_PRINT_ACT
                    stdout:outw("fake_leg does not exists, cannot create fallback basis, nothing to do")
                --#endif
            end

        end

        private.update_foot_anchor = function(raw: raw,foot: ikr6foot, info: ikr6leginfo)
            const previous_lateral_position = foot.lateral_position
            foot.from = raw.torso.position
            foot.lateral_position = raw.torso.position - raw.torso.rotation.up * (raw.size.y / 2) + raw.torso.rotation.right * info.limb_diff            
            
            const delta = foot.lateral_position - previous_lateral_position
            const up = raw.torso.rotation.up
            const planar_delta = delta - up * vector.dot(delta, up)
            
            foot.accumulated_distance += vector.magnitude(planar_delta)
        end

        private.should_step = function(raw: raw, foot: ikr6foot, info: ikr6leginfo): boolean
            const contact = foot:get_limb_contact()
            const up = raw.torso.rotation.up

            const error_scale = (foot.lateral_position - contact) - up * vector.dot((foot.lateral_position - contact), up)
            const error_distance = vector.magnitude(error_scale)

            return error_distance >= info.limb_distance_trigger_at or foot.accumulated_distance >= info.limb_distance_trigger_at
        end

        private.get_step_speed = function (raw: raw, info: ikr6leginfo): number
            return info.limb_movement_speed_min + (info.limb_movement_speed_max - info.limb_movement_speed_min) *
                math.clamp(
                    (vector.magnitude(raw.horizont_linear_vel) - info.limb_movement_velocity_min) / -- speed
                    math.max(info.limb_movement_velocity_max - info.limb_movement_velocity_min, 0.001), -- factor
                    0, 1
                )
        end

        private.get_settle_speed = function (raw: raw, info: ikr6leginfo) : number
            return info.limb_orientation_speed_min + (info.limb_orientation_speed_max - info.limb_orientation_speed_min) * raw.speed_factor
        end
    end

    do -- leg placement layer
        private.step = function (raw: raw, foot: ikr6foot, info: ikr6leginfo, override: enumitem_iklegs_state?): (basis?, boolean)
            const prediction_factor = raw.speed_factor ^ info.limb_prediction_curve
            const prediction_time = info.limb_prediction_time_min + (info.limb_prediction_time_max - info.limb_prediction_time_min) * prediction_factor
            const predicted_bottom = foot.lateral_position + raw.horizont_linear_vel * prediction_time

            if private.is_step_blocked(raw, foot, info, predicted_bottom) then
                return nil, true
            end

            const raycast_origin, raycast_direction = private.get_step_raycast_data(raw, info, predicted_bottom, override or IKLegsState.Stepping)
            const raycast_result = worldspace.raycast(raycast_origin, raycast_direction, private.rayparams)
            if not raycast_result then
                foot.fallback = true
                return nil, false
            else
                foot.fallback = false
            end

            private.foot_update(raw, foot, info, raycast_result)

            const face = foot:get_limb_facing(raw.move_dir,raw.torso.rotation.front)
            const knee = foot:get_limb_pole(face,raw.torso.rotation.front)

            return foot:get_limb_basis(raw.torso, knee, face), false
        end

        private.stand = function (raw: raw, foot: ikr6foot, info: ikr6leginfo, override: enumitem_iklegs_state?) : basis?
            const raycast_origin, raycast_direction = private.get_step_raycast_data(raw, info, foot.lateral_position, override or IKLegsState.Planted)
            const raycast_result = worldspace.raycast(raycast_origin, raycast_direction, private.rayparams)
            if not raycast_result then return nil end

            private.foot_update(raw, foot, info, raycast_result)

            const knee = foot:get_limb_pole(vector.zero, raw.torso.rotation.front)
            const foot_facing_direction = foot:get_limb_facing(vector.zero, raw.torso.rotation.front)
            const leg_placement = foot:get_limb_basis(raw.torso, knee, foot_facing_direction)

            return leg_placement
        end
    end


    do -- solver utility layer

        private.solver_begin_step = function (foot: ikr6foot, new_target: basis, info: ikr6leginfo)
            foot.fallback = false
            foot.target = new_target
            foot.hit_position = new_target.position - new_target.rotation.up * (info.limb_size.y * 0.5)

            const foot_state_machine = foot:get_states()
            foot_state_machine:set_state(false, IKLegsState.Planted, IKLegsState.Settling)
            foot_state_machine:set_state(true, IKLegsState.Stepping)
        end
                
        private.solver_begin_idle_step = function (raw: raw, ikr6: ikr6legs) : boolean
            const active, other = ikr6:get_active_cycle_leg_pair()
            const active_state_machine = active:get_states()

            if not active_state_machine:get_state(IKLegsState.Planted) then
                return false
            end

            const info = other:get_info()
            const target_basis = private.stand(raw, other, info, IKLegsState.Settling)
            if not target_basis then return false end

            private.solver_begin_step(other, target_basis, info)
            active.current = false
            other.current = true

            return true
        end

        private.solver_begin_leg_fallback = function (ikr6foot: ikr6foot) : ()
            ikr6foot.fallback = true

            const reference_to_origin = ikr6foot:get_reference()
            const reference_to_fake = ikr6foot:get_fake()
            if not private.is_valid(ikr6foot) then return end

            const origin: BasePart = reference_to_origin:get_instance()
            const fake_leg = reference_to_fake:get_instance()

            const fallback = origin.CFrame
            const fallback_basis = Basis:to_basis(fallback)

            const state_machine = ikr6foot:get_states()

            ikr6foot.fallback_basis = fallback_basis
            ikr6foot.target = fallback_basis
            ikr6foot.hit_position = ikr6foot:get_limb_contact()
            ikr6foot.hit_normal = fallback_basis.rotation.up

            fake_leg.CFrame = fallback

            state_machine:set_state(false, IKLegsState.Settling, IKLegsState.Stepping)
            state_machine:set_state(true, IKLegsState.Planted)
        end

        private.solver_independent_foot = function (raw: raw, foot: ikr6foot): ()
            if foot.fallback then return end

            const state_machine = foot:get_states()
            if not state_machine:get_state(IKLegsState.Planted) then return end

            const info = foot:get_info()
            if not private.should_step(raw, foot, info) then return end

            const target, blocked = private.step(raw, foot, info)
            if blocked then return end

            if target then
                private.solver_begin_step(foot, target, info)
                return
            end

            private.solver_begin_leg_fallback(foot)
        end

        private.solver_leg_fallback = function (ikr6foot: ikr6foot, info: ikr6leginfo, delta: number) : ()
            const reference_to_origin = ikr6foot:get_reference()
            const reference_to_fake = ikr6foot:get_fake()
            if not private.is_valid(ikr6foot) then return end

            const origin: BasePart = reference_to_origin:get_instance()
            const fake_leg = reference_to_fake:get_instance()

            const fallback = origin.CFrame
            const fallback_basis = Basis:to_basis(fallback)
            const state_machine = ikr6foot:get_states()

            state_machine:set_state(false, IKLegsState.Settling, IKLegsState.Stepping)
            state_machine:set_state(true, IKLegsState.Planted)

            ikr6foot.fallback_basis = fallback_basis
            ikr6foot.target = fallback_basis
            ikr6foot.hit_position = ikr6foot:get_limb_contact()

            fake_leg.CFrame = fake_leg.CFrame:Lerp(fallback, 1 - math.exp(-info.limb_fallback_speed * delta))
        end

        private.solver_recover_fallback = function (raw: raw,foot: ikr6foot): ()
            if not foot.fallback then return end

            const info = foot:get_info()
            if not private.should_step(raw, foot, info) then return end

            const target, blocked = private.step(raw, foot, info)
            if blocked then return end

            if target then
                private.solver_begin_step(foot, target, info)
            end
        end

        private.solver_foot_stepping = function (raw: raw, ikr6foot: ikr6foot, info: ikr6leginfo, fake_leg: BasePart, delta: number)
            const alpha = 1 - math.exp(-private.get_step_speed(raw, info) * delta)

            const current = Basis:to_basis(fake_leg.CFrame)
            const target = ikr6foot.target
            const next_basis = current:slerp(target, alpha)
            const offset = target.position - next_basis.position
            const horizontal = vector.create(offset.x, 0, offset.z)
            const distance = vector.magnitude(horizontal)
            const lift = math.min(distance, 1)
            const position = vector.create(next_basis.position.x, target.position.y + lift, next_basis.position.z)
            const new_basis = next_basis:clone({position = position})
            fake_leg.CFrame = Basis:to_cframe(new_basis)

            return
        end

        private.solver_foot_settling = function (raw: raw, ikr6foot: ikr6foot, info: ikr6leginfo, fake_leg: BasePart, delta: number)
            fake_leg.CFrame = fake_leg.CFrame:Lerp(Basis:to_cframe(ikr6foot.target), 1 - math.exp(-private.get_settle_speed(raw, info) * delta))
            return
        end

        private.solver_foot_realfk = function (raw: raw, foot: ikr6foot, delta: number)
            const info = foot:get_info()
            const reference_to_origin = foot:get_reference()
            const reference_to_fake = foot:get_fake()

            if not reference_to_fake:is_instance_exists() then
                --#if IKR6LEGS_PRINT_ACT
                stdout:outw("RealFK: fake does not exist")
                --#endif
                return
            end

            if not reference_to_origin:is_instance_exists() then
                if not foot.fallback then
                    foot.fallback = true
                    const sm = foot:get_states()

                    sm:set_state(false, IKLegsState.Settling, IKLegsState.Stepping)
                    sm:set_state(true, IKLegsState.Planted)
                end

                private.solver_leg_fallback(foot, info, delta)
                return
            end

            if foot.fallback then
                foot.fallback = false
            end

            const origin = reference_to_origin:get_instance()
            const target = Basis:to_basis(origin.CFrame)

            foot.target = target
            foot.fallback_basis = target
            foot.hit_position = target.position - target.rotation.up * (info.limb_size.y * 0.5)
            foot.hit_normal = target.rotation.up

            const fake_leg = reference_to_fake:get_instance()
            fake_leg.CFrame = fake_leg.CFrame:Lerp(
                Basis:to_cframe(target),
                1 - math.exp(-info.limb_planted_speed * delta)
            )
        end

        private.solver_foot = function (raw: raw, ikr6legs: ikr6legs, delta: number)
            for _, ikr6foot in {ikr6legs:get_left_leg(), ikr6legs:get_right_leg()} do
                if not ikr6foot.enabled then continue end

                if ikr6foot.mode == IKLimbMode.RealFK then
                    private.solver_foot_realfk(raw, ikr6foot, delta)
                    continue
                end

                const info = ikr6foot:get_info()
                const state_machine = ikr6foot:get_states()
                const fake = ikr6foot:get_fake()

                if not fake:is_instance_exists() then
                    --#if IKR6LEGS_PRINT_ACT
                        stdout:outw("cannot process null-reference fake-leg")
                    --#endif

                    continue
                end

                const fake_leg = fake:get_instance()

                private.update_foot_anchor(raw, ikr6foot, info)

                if state_machine:get_state(IKLegsState.Stepping) then
                    private.solver_foot_stepping(raw, ikr6foot, info, fake_leg, delta)
                    
                    if ikr6foot:is_moving_finished() then
                        state_machine:set_state(false, IKLegsState.Stepping)
                        state_machine:set_state(true, IKLegsState.Settling)
                    end

                    continue
                end

                if ikr6foot.fallback then
                    private.solver_leg_fallback(ikr6foot, info, delta)
                    continue
                end

                ikr6foot.target = ikr6foot:get_limb_target()

                if state_machine:get_state(IKLegsState.Settling) then
                    private.solver_foot_settling(raw, ikr6foot, info, fake_leg, delta)

                    if ikr6foot:is_orientation_finished() then
                        state_machine:set_state(false, IKLegsState.Settling, IKLegsState.Stepping)
                        state_machine:set_state(true, IKLegsState.Planted)

                        ikr6foot.accumulated_distance = 0
                    end

                    continue
                end

                fake_leg.CFrame = fake_leg.CFrame:Lerp(Basis:to_cframe(ikr6foot.target), 1 - math.exp(-info.limb_planted_speed * delta))
            end
        end
    end

    private.solver_to_idle = function (raw: raw, ikr6foot: ikr6foot)
        const state_machine = ikr6foot:get_states()
        const info = ikr6foot:get_info()

        if state_machine:get_state(IKLegsState.Planted) then
            const target = private.stand(raw, ikr6foot, info, IKLegsState.Planted)

            if target then
                ikr6foot.target = target
                ikr6foot.hit_position = ikr6foot:get_limb_contact()
            end
        end
    end

    private.world_solver  = function (delta: number)
        -- '__mode = "s"` gives the GC the right to reduce the size of the table,
        -- but this may cause optimization failures, so we cannot table.clear(private.active)
        for i, _ in private.active do
            private.active[i] = false
        end

        for _, ik in private.list do
            if not ik.enabled then
                private.mark_unactive(ik)

                continue
            end

            const info = ik:get_info()

            if info.ignore_hertz_limit then
                private.solver(ik, info, delta)
                continue
            end

            const hertz = math.max(info.update_hertz, 0.00001)
            const interval = 1 / hertz

            ik.last_work_time += delta
            if ik.last_work_time >= interval then
                const work_delta = ik.last_work_time
                ik.last_work_time -= interval

                private.solver(ik, info, work_delta)
            end
        end
    end

    private.solver = function (ik: ikr6legs, info: ikr6info, delta: number)
        const reference_to_humanoid = ik:get_humanoid()
        const reference_to_torso = ik:get_torso()

        if not reference_to_humanoid:is_instance_exists() then 
            private.mark_unactive(ik)

            --#if IKR6LEGS_PRINT_ACT
                stdout:outw ('this solver has no humanoid, skip')
            --#endif

            return
        end

        if not reference_to_torso:is_instance_exists() then
            private.mark_unactive(ik) 

            --#if IKR6LEGS_PRINT_ACT
            stdout:outw('this solver has no torso, skip')
            --#endif

            return
        end

        const humanoid = reference_to_humanoid:get_instance() :: Humanoid
        const torso = reference_to_torso:get_instance() :: BasePart


        private.active[ik] = true
        private.modify_params(torso.Parent or torso)
        const raw = private.create_raw(torso, humanoid)

        ik.current_idle_time = if raw.is_moving then 0 else ik.current_idle_time + delta

        private.solver_foot(raw, ik, delta)

        const left_leg = ik:get_left_leg()
        const right_leg = ik:get_right_leg()

        if left_leg.mode == IKLimbMode.FakeIK then
            private.solver_recover_fallback(raw, left_leg)
        end
        if right_leg.mode == IKLimbMode.FakeIK then
            private.solver_recover_fallback(raw, right_leg)
        end

        if not raw.is_moving and ik.current_idle_time >= info.idle_time then
            if left_leg.mode == IKLimbMode.FakeIK then
                private.solver_to_idle(raw, left_leg)
            end
            if right_leg.mode == IKLimbMode.FakeIK then
                private.solver_to_idle(raw, right_leg)
            end
        end

        if left_leg.mode ~= IKLimbMode.FakeIK or right_leg.mode ~= IKLimbMode.FakeIK then
            return
        end

        const left_fallback = left_leg.fallback
        const right_fallback = right_leg.fallback

        if left_fallback and right_fallback then
            return
        end

        if left_fallback ~= right_fallback then
            const independent = if left_fallback then right_leg else left_leg
            const fallback = if left_fallback then left_leg else right_leg

            independent.current = true
            fallback.current = false

            private.solver_independent_foot(raw, independent)
            return
        end

        const active, other = ik:get_active_cycle_leg_pair()
        if not active:get_states():get_state(IKLegsState.Planted) then return end

        const other_info = other:get_info()
        if not private.should_step(raw, other, other_info) then return end

        const target, blocked = private.step(raw, other, other_info)

        if blocked then
            private.solver_begin_idle_step(raw, ik)
            return
        end

        if not target then
            private.solver_begin_leg_fallback(other)
            return
        end

        private.solver_begin_step(other, target, other_info)

        active.current = false
        other.current = true
    end

    private.signal:Connect(private.world_solver)

    ctype:read(class):write_tag(ctags.immersiveness, ctags.inverse_kinematic, ctags.solver, ctags.class, ctags.game)
    class:host(private.register_new)

    --#if LUAOBJECT_SELF_REG
    private.register_new(class)
    --#endif   
end

return class