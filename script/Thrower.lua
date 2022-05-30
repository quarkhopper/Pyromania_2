#include "Utils.lua"
#include "Defs.lua"

fireballs = {}

function inst_fireball(pos, dir)
    local inst = {}
    inst.pos = pos
    inst.dir = dir
    inst.speed = TOOL.THROWER.speed.value
    inst.dist_left = TOOL.THROWER.max_dist.value
    inst.splits_remaining = 4
    return inst
end

function shoot_thrower()
    local camera = GetPlayerCameraTransform()
	local gun_end = TransformToParentPoint(camera, Vec(0.2, -0.6, -2.2))
    local forward = TransformToParentPoint(camera, Vec(0, 0, -10))
    local fireball_dir = VecNormalize(VecSub(forward, camera.pos))
    local fireball = inst_fireball(gun_end, fireball_dir)
    table.insert(fireballs, fireball)
	SpawnFire(gun_end)
end

function thrower_tick(dt)
    local fireballs_next_tick = {}
    for i = 1, #fireballs do
        local fireball = fireballs[i]
		if fireball.dist_left > 0 then 
			local hit, dist, normal = QueryRaycast(fireball.pos, fireball.dir, fireball.speed + 0.1, 0.025)
            if hit then 
                -- hit something - break apart
                local new_dirs = radiate(fireball.dir, 45, fireball.splits_remaining)
                for j = 1, #new_dirs do
                    local new_fireball = inst_fireball(fireball.pos, new_dirs[j])
                    new_fireball.dist_left = 2
                    new_fireball.speed = 0.5
                    new_fireball.splits_remaining = fireball.splits_remaining - 1
                    table.insert(fireballs_next_tick, new_fireball) 
                    -- apply_force(TOOL.THROWER.pyro.ff, fireball.pos, VecScale(new_dirs[j], TOOL.THROWER.pyro.ff.f_max))
                end
            else
                -- continued flight
                fireball.dir = VecNormalize(VecAdd(fireball.dir, Vec(0, -TOOL.THROWER.gravity.value, 0)))
                local advance = VecScale(fireball.dir, fireball.speed)
                fireball.pos = VecAdd(fireball.pos, advance)
                fireball.dist_left = fireball.dist_left - fireball.speed
                local point_force = VecScale(fireball.dir,  TOOL.THROWER.pyro.ff.f_max) 
                apply_force(TOOL.THROWER.pyro.ff, fireball.pos, point_force)
                -- DebugCross(fireball.pos)
                -- DebugLine(fireball.pos, VecAdd(fireball.pos, VecScale(fireball.dir, fireball.speed)))
                table.insert(fireballs_next_tick, fireball)
            end
		end
    end
    fireballs = fireballs_next_tick
end
