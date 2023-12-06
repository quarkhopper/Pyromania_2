#include "Defs.lua"

P_BOMB = {}
P_BOMB.MAX_DELAY = 0

bombs = {}
boom_sound = LoadSound("MOD/snd/toiletBoom.ogg")

function detonate_all()
    for i = 1, #bombs do
        local bomb = bombs[i]
        detonate(bomb)
    end
    bombs = {}
end

function detonate(bomb)
    local bomb_trans = GetShapeWorldTransform(bomb)
    local bomb_pos = VecAdd(bomb_trans.pos, Vec(0.2, 0.2, 0.2))
    blast_at(bomb_pos)
end

function blast_at(pos)
    local force_mag = random_float_in_range(TOOL.BOMB.pyro.fade_magnitude, TOOL.BOMB.pyro.ff.graph.max_force)
	local fireball_rad = TOOL.BOMB.explosion_fireball_radius
	local explosion_seeds = TOOL.BOMB.explosion_seeds
    for i = 1, explosion_seeds do
        local spawn_dir = VecNormalize(Vec(random_vec_component(10), random_float_in_range(0, 10), random_vec_component(10)))
        local spark_offset = VecScale(spawn_dir, random_float_in_range(0, fireball_rad))
        local spark_pos = VecAdd(pos, spark_offset)
        local force_dir = VecNormalize(VecSub(spark_pos, pos))
        local hit, dist = QueryRaycast(pos, force_dir, spark_offset, 0.025)
        if hit then
            local spark_pos = VecAdd(pos, VecScale(force_dir, dist - 0.1)) 
		end
        local spark_vec = VecScale(force_dir, force_mag)
        apply_force(TOOL.BOMB.pyro.ff, spark_pos, spark_vec)
    end
    for i = 1, 100 do
        SpawnFire(VecAdd(pos, random_vec(1)))
    end
    MakeHole(pos, 0.2, 0.2, 0.2, true)
    if TOOL.BOMB.shockwaves.value == on_off.on then
        local scale = 0.5
        if TOOL.BOMB.fireball_scale ~= nil then scale = TOOL.BOMB.fireball_scale.value end
        shock_at(pos, scale)
    end
    PlaySound(boom_sound, pos, 100)
    PlaySound(rumble_sound, pos, 100)
end

function bomb_tick(dt)
    local new_bombs = {}
    for i = 1, #bombs do
        local bomb = bombs[i]
        if IsBodyBroken(GetShapeBody(bomb)) then
            if TOOL.BOMB["impact_explode"] and 
            TOOL.BOMB.impact_explode.value == on_off.on then
                detonate(bomb)
            end
        else
            table.insert(new_bombs, bomb)
        end
	end
    bombs = new_bombs
end

