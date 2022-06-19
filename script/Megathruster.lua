#include "Defs.lua"

P_BOMB = {}
P_BOMB.MAX_DELAY = 0

thruster = nil
ingnition = false
-- boom_sound = LoadSound("MOD/snd/toiletBoom.ogg")

function inst_thruster(trans)
    local inst = {}
    inst.trans = trans
    inst.body = Spawn("MOD/prefab/pyro_megathruster.xml", Transform(inst.trans))[2]
    inst.pos = trans.pos
    inst.rot = trans.rot
    inst.ignition = false
    return inst
end

function launch(thruster)
    thruster.ignition = true
end

function thruster_tick(dt)
end


