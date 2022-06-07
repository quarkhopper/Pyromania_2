#include "Defs.lua"

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
    local bomb_pos = VecAdd(bomb_trans.pos, Vec(0.1, 0.1, 0.1))
    blast_at(bomb_pos)
end

function blast_at(pos)

    Explosion(pos, 0.5)
    for i = 1, 100 do
        SpawnFire(VecAdd(pos, random_vec(1)))
    end
    local force_mag = TOOL.BOMB.pyro.ff.f_max
	local fireball_rad = TOOL.BOMB.explosion_fireball_radius.value
	local explosion_seeds = TOOL.BOMB.explosion_seeds.value
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
        apply_force(TOOL.BOMB.pyro.ff, point_position, point_force)
    end
    create_shock(pos, 1)
    PlaySound(boom_sound, pos, 100)
    PlaySound(rumble_sound, pos, 100)
end