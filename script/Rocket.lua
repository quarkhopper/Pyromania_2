#include "Utils.lua"
#include "Defs.lua"

rockets = {}
launch_sound = LoadSound("MOD/snd/rocket_launch.ogg")
rocket_boom_sound = LoadSound("MOD/snd/rocket_boom.ogg")

function inst_rocket(body, dir)
    local inst = {}
    inst.body = body
    inst.trans = GetBodyTransform(inst.body)
    inst.dir = dir
    inst.speed = 1
    inst.dist_left = 100
    inst.fuse = -1
    return inst
end

function fire_rocket()
    local camera = GetPlayerCameraTransform()
	local gun_end = TransformToParentPoint(camera, Vec(0.2, -0.2, -2))
    local forward = TransformToParentPoint(camera, Vec(0, 0, -10))
    local rocket_rot = QuatLookAt(gun_end, forward)
    local rocket_body = Spawn("MOD/prefab/pyro_rocket.xml", Transform(gun_end, rocket_rot))[1]
    local rocket_dir = VecNormalize(VecSub(forward, camera.pos))
    local rocket = inst_rocket(rocket_body, rocket_dir)
    rocket.speed = TOOL.ROCKET.speed.value
    rocket.dist_left = TOOL.ROCKET.max_dist.value
    table.insert(rockets, rocket)
    PlaySound(launch_sound, gun_end, 10)
end

function rocket_tick(dt)
    local rockets_next_tick = {}
    for i = 1, #rockets do
        local rocket = rockets[i]
        local hit, dist = QueryRaycast(rocket.trans.pos, rocket.dir, rocket.speed, 0.025)
        if hit then 
            if not DEBUG_MODE then 
                -- break a hole and on the next tick explode
                for i = 1, rocket.speed * 10 do
                    local offset = i * 0.1
                    MakeHole(VecAdd(rocket.trans.pos, VecScale(rocket.dir, offset)), 1, 1, 1)
                end
                local puff_spokes = 12
                local puff_size_start = 0.6
                local puff_size_end = 0.1
                local puff_steps = 15
                local puff_color_value = 0.8
                for k = 1, puff_spokes do
                    local puff_dist = math.random(2, 8)
                    local puff_dir = VecAdd(VecScale(rocket.dir, -1), random_vec(0.5))
                    for j = 1, puff_steps do
                        local puff_rad = (puff_dist * j) / puff_steps
                        local puff_pos = VecAdd(rocket.trans.pos, VecScale(puff_dir, puff_rad))
                        ParticleReset()
                        ParticleType("smoke")
                        ParticleRadius(fraction_to_range_value(j/puff_steps, puff_size_start, puff_size_end))
                        local smoke_color = VecScale(Vec(1,1,1), puff_color_value)
                        ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
                        SpawnParticle(puff_pos, Vec(), 2)                    
                    end
                end
            end
            -- check again in case we're hitting the ground
            local hit, dist = QueryRaycast(rocket.trans.pos, rocket.dir, rocket.speed, 0.025)
            if hit then 
                -- just blow the charge. You can't bust this.
                rocket.fuse = 0
            elseif rocket.fuse == -1 then
                -- fuse to allow penetration    
                rocket.fuse = 2
            end
        end
        if rocket.fuse == 0 then 
            SetBodyDynamic(rocket, true)
            if not DEBUG_MODE then Explosion(rocket.trans.pos, 1) else Delete(rocket.body) end

            local force_mag = 10000 -- TOOL.ROCKET.pyro.ff.f_max
            local fireball_rad = TOOL.ROCKET.explosion_fireball_radius.value
            local explosion_seeds =  TOOL.ROCKET.explosion_seeds.value
            local pos = rocket.trans.pos
            for i = 1, explosion_seeds do
                local spawn_dir = VecNormalize(random_vec(1))
                local spawn_offset = VecScale(spawn_dir, fireball_rad)
                local point_position = VecAdd(pos, spawn_offset)
                local force_dir = VecNormalize(VecSub(point_position, pos))
                local hit, dist, normal, shape = QueryRaycast(pos, force_dir, fireball_rad + 0.1, 0.025)
                if hit then
                    local hit_point = VecAdd(pos, VecScale(force_dir, dist)) 
                    local force_dir = normal
                end
                local point_force = VecScale(force_dir, force_mag)
                apply_force(TOOL.ROCKET.pyro.ff, point_position, point_force)
            end
            PlaySound(rocket_boom_sound, bomb_pos, 100)
        elseif rocket.dist_left <= 0 then 
            -- ran out of fuel
            Explosion(rocket.trans.pos, 1)
        else
            local advance = VecScale(rocket.dir, rocket.speed)
            rocket.trans.pos = VecAdd(rocket.trans.pos, advance)
            SetBodyTransform(rocket.body, rocket.trans)
            SetBodyDynamic(rocket.body, false)
            rocket.dist_left = rocket.dist_left - rocket.speed
            table.insert(rockets_next_tick, rocket)
            if not DEBUG_MODE then 
                local light_point = TransformToParentPoint(rocket.trans, Vec(0, 0, 2))
                for i = 1, 10 do
                    ParticleReset()
                    ParticleType("smoke")
                    ParticleAlpha(0.5, 0.9, "linear", 0.05, 0.5)
                    ParticleRadius(0.2, 0.5)
                    ParticleTile(5)
                    local smoke_color = HSVToRGB(Vec(0, 0, 0.4))
                    ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
                    local smoke_point = VecAdd(rocket.trans.pos, VecScale(rocket.dir, -1 * (rocket.speed / i)))
                    SpawnParticle(smoke_point, Vec(), 3)
                end
                PointLight(light_point, 1, 0, 0, 0.1)
            end
            rocket.fuse = math.max(rocket.fuse - 1, -1)
        end
    end
    rockets = rockets_next_tick
end

function fire_charge(rocket)
       
end