#include "ForceField.lua"
#include "Utils.lua"
--[[
    This script is a wrapper for ForceField.lua. Where ForceField.lua covers the 
    "physics" of the forces moving around, this covers the fire and SFX and wraps
    that field. 
]]--


PYRO = {} -- Static PyroField options
PYRO.MAX_FLAMES = 500 -- default maximum number of flames to render
-- If the pyro field is in rainbow mode, this one color will be cycled and 
-- coordinates the color of all flames and smoke particules generated. 
PYRO.RAINBOW = Vec(0, 1, 0.8)
PYRO.MIN_PLAYER_PUSH = 1
PYRO.MAX_PLAYER_PUSH = 5
PYRO.MIN_IMPULSE = 50
PYRO.MAX_IMPULSE = 10000
PYRO.MIN_HOLE_VOXELS = 0.1
PYRO.MAX_HOLE_VOXELS = 5
PYRO.GRAVITY = 0.5

function inst_pyro()
    local inst = {}
    -- Like the force field, this coordinates the staggering of 
    -- activities on different ticks for performance reasons. 
    inst.tick_interval = 3
    inst.tick_count = inst.tick_interval
    -- Table of objects that represent one point of light in the explosion shrouded by 
    -- smoke to give it some diffusion. 
    inst.flames = {}
    -- If conditions are met to spawn flames on a force field point, this is the number 
    -- of flames that will be spawned based on that world coordinate (may be staggered or
    -- varied in some other way)
    inst.flames_per_spawn = 5
    -- Intensity of a flame light point in its puff. Customization of this should be
    -- controlled through the HSV color rather than this value which function more 
    -- of a gain.
    inst.flame_light_intensity = 3
    -- When considering the base force field vector point, any vector below this magnitude
    -- changes the flame rendering mode from normal rules to "ember" rules. Ember rules will
    -- have the flame point light decreasing in intensity and the puff getting smaller and 
    -- jittering as it flutters away. 
    inst.cool_particle_size = 1
    inst.hot_particle_size = 0.3
    -- The lifetime of black smoke that spawns behind the flames.
    inst.smoke_life = 3
    -- Normalized smoke amount. Calculated by math.random() < value
    inst.smoke_amount_n = 0.2
    -- True if rendering flames. If this is false then only the flame "puffs" will be shown 
    -- and no black smoke will be generated. This is false when using the pyro Max field for
    -- shock wave effects.
    inst.render_flames = true
    -- The lifetime of flame diffusing smoke puffs.
    inst.flame_puff_life = 1
    -- Jitter applied to the flame as the maximum magnitude of vector components
    -- added to the position of the flame.
    inst.flame_jitter = 0
    -- Built-in Teardown tile to use for the flame. 
    inst.flame_tile = 0
    -- Opacity of flame puffs. 
    inst.flame_opacity = 1
    inst.impulse_scale = 1
    -- Effective radius that a force field vector can interact with a world body to apply
    -- impulse to it. 
    inst.impulse_radius = 5
    -- Radius from a force field vector point that flames can arise.
    inst.fire_ignition_radius = 1
    -- Number of flames per LINEAR world unit to attempt to spawn AS THOUGH a value of 1 equates to
    -- a volume of a 1x1x1 cube of voxels having only 1^3 (or 1) fire spawn. A value of 2 
    -- yields 2^3 or 8 fire spawns. The reality is that this number of fires is calculated and then
    -- than many attempts to cast out from a central point in a random direction a distance of 
    -- fire_ignition_radius away are made. If that cast hits something, a fire is started.
    inst.fire_density = 1
    inst.contact_damage_scale = 1
    -- The gretest proportion of player health that can be taken away in a tick
    inst.max_player_hurt = 0.5
    -- Why did you guys ask for this? If set to "on" will cause all flame effects to rotate 
    -- colors in sync and new smoke particules to spawn in that color. 
    inst.rainbow_mode = on_off.off
    -- The flame color when based on a force field vector point just above dead force.
    inst.color_cool = Vec(7.7, 1, 0.8)
    -- The flame color when based on a force field vector point at maximum magnitude.
    inst.color_hot = Vec(7.7, 1, 0.8)

    -- The force field wrapped by this pyro field.
    inst.ff = inst_force_field_ff()

    return inst
end

function inst_flame(pos)
    -- A flame object is rendered as a point light in a diffusing smoke particle.
    local inst = {}
    inst.pos = pos
    -- Parent FORCE FIELD POINT that this flame was spawned for.
    inst.parent = nil
    return inst
end

function make_flame_effect(pyro, flame, dt)
    -- Render effects for one flame instance.
    local life_n =  bracket_value(range_value_to_fraction(flame.parent.life_timer, pyro.ff.graph.burnout_time, pyro.ff.graph.life_time), 1, 0)
    local afterlife_n = bracket_value(range_value_to_fraction(flame.parent.life_timer, 0, pyro.ff.graph.burnout_time), 1, 0)
    local color = Vec()
    local intensity = pyro.flame_light_intensity
    if pyro.rainbow_mode == on_off.on then
        -- Rainbow mode just cycles one color for the entire field and uses that color 
        -- for all fire effects universally
        PYRO.RAINBOW[1] = cycle_value(PYRO.RAINBOW[1], dt, 0, 359)
        color = HSVToRGB(PYRO.RAINBOW)
        -- intensity is set to a hardcoded value that works well for displaying colors. Too high
        -- and the colors are washed out.
        intensity = 0.5
    else
        -- when not in rainbow mode...
        if life_n > 0 then 
            color = HSVToRGB(blend_color(life_n ^ 2, pyro.color_cool, pyro.color_hot))
        else
            color = HSVToRGB(pyro.color_cool)
        end
    end

    local particle_size = 0
    local puff_color_value = 1
    if life_n > 0 then 
        -- normal mode
        particle_size = fraction_to_range_value(life_n ^ 0.5, pyro.cool_particle_size, pyro.hot_particle_size)
    else
        -- ember mode
        puff_color_value = afterlife_n
        particle_size = fraction_to_range_value(afterlife_n, 0.2, pyro.cool_particle_size)
        intensity = fraction_to_range_value(afterlife_n, 0.2, intensity)
        -- Jitter is added to an ember to simulate flutter. this prevents the smaller sized particules from 
        -- exposing the field grid too much. 
        local jitter = random_vec(pyro.ff.resolution)
        flame.pos = VecAdd(flame.pos, jitter)
    end
    -- Put the light source in the middle of where the diffusing flame puff will be
    PointLight(flame.pos, color[1], color[2], color[3], intensity)
    -- fire puff smoke particle generation
    ParticleReset()
    ParticleType("smoke")
    ParticleAlpha(pyro.flame_opacity, 0, "easeout", 0, 0.5)
    -- ParticleDrag(0.25)
    ParticleRadius(particle_size)
    local smoke_color = HSVToRGB(Vec(0, 0, puff_color_value))
    ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
    ParticleGravity(PYRO.GRAVITY)
    ParticleTile(pyro.flame_tile)
    -- Apply a little random jitter if specified by the options, for the specified lifetime
    -- in options.
    SpawnParticle(VecAdd(flame.pos, random_vec(pyro.flame_jitter)), Vec(), pyro.flame_puff_life)

    -- if black smoke amount is set above 0, we're not in ember mode, and chance favors it...
    if math.random() < pyro.smoke_amount_n then
        -- Set up a smoke puff
        ParticleReset()
        ParticleType("smoke")
        -- ParticleDrag(0)
        ParticleAlpha(0.5, 0.9, "linear", 0.05, 0.5)
        ParticleRadius(particle_size)
        if pyro.rainbow_mode == on_off.on then
            -- Rainbow mode: smoke puff is the universal color of the tick
            smoke_color = PYRO.RAINBOW
            smoke_color[3] = 1
            smoke_color = HSVToRGB(smoke_color)
        else
            -- Normal mode: smoke color is a hard-coded dingy value
            smoke_color = HSVToRGB(Vec(0, 0, 0.1))
        end
        ParticleColor(smoke_color[1], smoke_color[2], smoke_color[3])
        ParticleGravity(PYRO.GRAVITY)
        -- apply a little random jitter to the smoke puff based on the flame position,
        -- for the specified lifetime of the particle.
        SpawnParticle(VecAdd(flame.pos, random_vec(0.1)), Vec(), pyro.smoke_life)
    end
end

function burn_fx(pyro)
    -- Start fires throught the native Teardown mechanism. Base these effects on the
    -- lower resolution metafield for better performance. 
    local points = flatten(pyro.ff.metafield)
    local num_fires = round((pyro.fire_density / pyro.fire_ignition_radius)^3)
    for i = 1, #points do
        local point = points[i]
        for j = 1, num_fires do
            local random_dir = random_vec(1)
            -- cast in some random dir and start a fire if you hit something. 
            local hit, dist = QueryRaycast(point.pos, random_dir, pyro.fire_ignition_radius)
            if hit then 
                local burn_at = VecAdd(point.pos, VecScale(random_dir, dist))
                SpawnFire(burn_at)
            end
        end
    end
end

function make_flame_effects(pyro, dt)
    -- for every flame instance, make the appropriate effect
    for i = 1, #pyro.flames do
        local flame = pyro.flames[i]
        make_flame_effect(pyro, flame, dt)
    end
end

function spawn_flames(pyro)
    -- Spawn flame instances to render based on the underlying base force field vectors.
    local new_flames = {}
    local points = flatten(pyro.ff.field)
    for i = 1, #points do
        local point = points[i]
        spawn_flame_group(pyro, point, new_flames)
    end
    while #new_flames > PYRO.MAX_FLAMES do
        table.remove(new_flames, math.random(#new_flames))
    end
    pyro.flames = new_flames
end

function spawn_flame_group(pyro, point, flame_table)
    for i = 1, pyro.flames_per_spawn do
        local offset_dir = VecNormalize(random_vec(1))
        local flame_pos = VecAdd(point.pos, VecScale(offset_dir, pyro.ff.resolution))
        local flame = inst_flame(point.pos)
        flame.parent = point
        table.insert(flame_table, flame)
    end
end

function impulse_fx(pyro)
    local points = flatten(pyro.ff.metafield)
    local player_trans = GetPlayerTransform()
    for i = 1, #points do
        local point = points[i]
        -- apply impulse
        local box = box_vec(point.pos, pyro.impulse_radius)
        local push_bodies = QueryAabbBodies(box[1], box[2])
        local force_mag = VecLength(point.vec)
        local force_dir = VecNormalize(point.vec)
        local force_n = force_mag / pyro.ff.graph.max_force
        for i = 1, #push_bodies do
            local push_body = push_bodies[i]
            local body_center = TransformToParentPoint(GetBodyTransform(push_body), GetBodyCenterOfMass(push_body))
            local hit = QueryRaycast(point.pos, force_dir, pyro.impulse_radius, 0.025)
            if hit then 
                local impulse_mag = fraction_to_range_value(force_n ^ 0.5, PYRO.MIN_IMPULSE, PYRO.MAX_IMPULSE) * pyro.impulse_scale
                ApplyBodyImpulse(push_body, body_center, VecScale(force_dir, impulse_mag))
            end
        end
        if VecLength(VecSub(player_trans.pos, point.pos)) <= pyro.impulse_radius then
            local push_mag = fraction_to_range_value(force_n^2, PYRO.MIN_PLAYER_PUSH, PYRO.MAX_PLAYER_PUSH) * pyro.impulse_scale
            SetPlayerVelocity(VecAdd(GetPlayerVelocity(), VecScale(force_dir, push_mag)))
        end
    end
end

function collision_fx(pyro)
    for i = 1, #pyro.ff.contacts do
        local contact = pyro.ff.contacts[i]
        local force_n = range_value_to_fraction(VecLength(contact.point.vec), 0, pyro.ff.graph.max_force)
        -- make holes
        local voxels = fraction_to_range_value(force_n ^ 0.5, PYRO.MIN_HOLE_VOXELS, PYRO.MAX_HOLE_VOXELS) * pyro.contact_damage_scale
        if voxels > 0.1 then 
            MakeHole(contact.hit_point, voxels * 10, voxels * 5, voxels, true)
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
                factor = factor * (VecLength(point.vec) / pyro.ff.graph.max_force) + 0.01
                hurt_player(factor * pyro.max_player_hurt)
            end
        end
    end
end

function flame_tick(pyro, dt)
    pyro.tick_count = pyro.tick_count - 1
    if pyro.tick_count == 0 then pyro.tick_count = pyro.tick_interval end
    force_field_ff_tick(pyro.ff, dt)
    
    if pyro.render_flames then 
        spawn_flames(pyro)
        make_flame_effects(pyro, dt)
    end

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
