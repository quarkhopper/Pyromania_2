#include "ForceField.lua"
#include "Utils.lua"

PYRO = {}
PYRO.MAX_FLAMES = 500
PYRO.RAINBOW = Vec(0, 1, 0.8)

function inst_pyro()
    local inst = {}
    inst.tick_interval = 3
    inst.tick_count = inst.tick_interval
    inst.flames = {}
    inst.flames_per_spawn = 5
    inst.flame_light_intensity = 3
    inst.flame_dead_force = 0.2
    inst.max_smoke_size = 1
    inst.min_smoke_size = 0.3
    inst.smoke_life = 3
    inst.impulse_const = 70
    inst.impulse_radius = 5
    inst.fire_ignition_radius = 1
    inst.fire_density = 1
    inst.hole_punch_scale = 0.2
    inst.max_player_hurt = 0.5
    inst.gravity = 1
    inst.rainbow_mode = on_off.off
    inst.color_cool = Vec(7.7, 1, 0.8)
    inst.color_hot = Vec(7.7, 1, 0.8)

    inst.ff = inst_force_field_ff()

    return inst
end

function inst_flame(pos)
    local inst = {}
    inst.pos = pos
    inst.life_n = 1
    inst.parent = nil
    inst.motion_vec = Vec()
    return inst
end

function make_flame_effect(pyro, flame, dt)
    flame.life_n = math.min(1, range_value_to_fraction(flame.parent.mag, pyro.flame_dead_force, pyro.ff.f_max))
    local color = Vec()
    local intensity = pyro.flame_light_intensity
    if pyro.rainbow_mode == on_off.on then
        PYRO.RAINBOW[1] = cycle_value(PYRO.RAINBOW[1], dt, 0, 359)
        color = HSVToRGB(PYRO.RAINBOW)
        intensity = 0.5
    else
        if flame.life_n >= 0 then 
            color = HSVToRGB(blend_color(flame.life_n^2, pyro.color_cool, pyro.color_hot))
        else
            color = HSVToRGB(pyro.color_cool)
        end
    end
    if flame.life_n < 0 then 
        intensity = range_value_to_fraction(flame.parent.mag, pyro.ff.f_dead, pyro.flame_dead_force) * 0.8
    end
    PointLight(flame.pos, color[1], color[2], color[3], intensity)
    -- fire puff
    ParticleReset()
    ParticleType("smoke")
    local smoke_size = 0
    ParticleAlpha(1, 0, "easeout", 0, 0.5)
    if flame.life_n >= 0 then
        smoke_size = fraction_to_range_value((1 - flame.life_n), pyro.min_smoke_size, pyro.max_smoke_size)
    else
        smoke_size = range_value_to_fraction(flame.parent.mag, pyro.ff.f_dead, pyro.flame_dead_force) + 0.1
        flame.pos = VecAdd(flame.pos, random_vec(pyro.ff.resolution))
    end
    ParticleDrag(0.25)
    ParticleRadius(smoke_size)
    local smoke_color = HSVToRGB(Vec(0, 0, 1))
    ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
    ParticleGravity(pyro.gravity)
    SpawnParticle(flame.pos, Vec(), 1)

    if math.random(1, 10) == 1 then
            -- smoke puff
            ParticleReset()
            ParticleType("smoke")
            ParticleDrag(0.5)
            ParticleAlpha(0.5, 0.9, "linear", 0.05, 0.5)
            ParticleRadius(smoke_size)
            if pyro.rainbow_mode == on_off.on then
                smoke_color = PYRO.RAINBOW
                smoke_color[3] = 1
                smoke_color = HSVToRGB(smoke_color)
            else
                smoke_color = HSVToRGB(Vec(0, 0, 0.1))
            end
            ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
            ParticleGravity(pyro.gravity)
            SpawnParticle(VecAdd(flame.pos, random_vec(0.1)), Vec(), pyro.smoke_life)
    end
end

function burn_fx(pyro)
    local points = flatten(pyro.ff.metafield)
    local num_fires = round((pyro.fire_density / pyro.fire_ignition_radius)^3)
    for i = 1, #points do
        local point = points[i]
        for i = 1, num_fires do
            SpawnFire(VecAdd(point.pos, random_vec(pyro.fire_ignition_radius)))
        end
    end
end

function make_flame_effects(pyro, dt)
    for i = 1, #pyro.flames do
        local flame = pyro.flames[i]
        make_flame_effect(pyro, flame, dt)
    end
end

function spawn_flames(pyro)
    local new_flames = {}
    local points = flatten(pyro.ff.field)
    for i = 1, #points do
        local point = points[i]
        spawn_flame_group(pyro, point, new_flames)
    end
    table.sort(new_flames, function (f1, f2) return f1.life_n < f2.life_n end )
    while #new_flames > PYRO.MAX_FLAMES do
        table.remove(new_flames, math.random(#new_flames))
    end
    pyro.flames = new_flames
end

function spawn_flame_group(pyro, point, flame_table)
    for i = 1, pyro.flames_per_spawn do
        local offset_dir = VecNormalize(random_vec(1))
        local flame_pos = VecAdd(point.pos, VecScale(pyro.ff.resolution, offset_dir))
        local flame = inst_flame(point.pos)
        flame.parent = point
        flame.motion_vec = point.vec
        table.insert(flame_table, flame)
    end
end

function impulse_fx(pyro)
    local points = flatten(pyro.ff.metafield)
    for i = 1, #points do
        local point = points[i]
        -- apply impulse
        local box = box_vec(point.pos, pyro.impulse_radius)
        local push_bodies = QueryAabbBodies(box[1], box[2])
        for i = 1, #push_bodies do
            local push_body = push_bodies[i]
            local body_center = TransformToParentPoint(GetBodyTransform(push_body), GetBodyCenterOfMass(push_body))
            local force_mag = VecLength(point.vec)
            local force_dir = VecNormalize(point.vec)
            local force_n = force_mag / pyro.ff.f_max
            local hit = QueryRaycast(point.pos, force_dir, pyro.impulse_radius, 0.025)
            if hit then 
                ApplyBodyImpulse(push_body, body_center, VecScale(force_dir, force_n * pyro.impulse_const))
            end
        end
    end
end

function check_hurt_player(pyro)
    local player_trans = GetPlayerTransform()
    local player_pos = player_trans.pos
    local points = flatten(pyro.ff.metafield)
    for i = 1, #points do
        local point = points[i]
        -- hurt player
        local vec_to_player = VecSub(point.pos, player_pos)
        local dist_to_player = VecLength(vec_to_player)
        if dist_to_player < pyro.impulse_radius then
            local hit = QueryRaycast(point.pos, VecNormalize(vec_to_player), dist_to_player, 0.025)
            if not hit then             
                local factor = 1 - (dist_to_player / pyro.impulse_radius)
                factor = factor * (VecLength(point.vec) / pyro.ff.f_max)
                hurt_player(factor * pyro.max_player_hurt)
            end
        end
    end
end

function collision_fx(pyro)
    for i = 1, #pyro.ff.contacts do
        local contact = pyro.ff.contacts[i]
        local force_n = range_value_to_fraction(VecLength(contact.point.vec), pyro.flame_dead_force, pyro.ff.f_max)
        -- make holes
        local voxels = force_n * pyro.hole_punch_scale
        MakeHole(contact.hit_point, voxels * 10, voxels * 5, voxels, true)
    end
end

function flame_tick(pyro, dt)
    pyro.tick_count = pyro.tick_count - 1
    if pyro.tick_count == 0 then pyro.tick_count = pyro.tick_interval end
    force_field_ff_tick(pyro.ff, dt)
    spawn_flames(pyro)
    make_flame_effects(pyro, dt)

    if (pyro.tick_count + 2) % 3 == 0 then 
        collision_fx(pyro)
        pyro.ff.contacts = {}
    elseif (pyro.tick_count + 1) % 3 == 0 then 
        impulse_fx(pyro)
    elseif pyro.tick_count % 3 == 0 then 
        burn_fx(pyro)
        check_hurt_player(pyro)
    end
end
