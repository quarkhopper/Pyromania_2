#include "Utils.lua"

FF = {} -- library constants
FF.FORWARD = Vec(0, 0, -1)
FF.MAX_SIM_POINTS = 200

function inst_force_field_ff()
    local inst = {}
    inst.tick_reset = 2
    inst.tick_count = inst.tick_reset

    inst.field = {}
    inst.metafield = {}
    inst.contacts = {}

    inst.resolution = 0.5
    inst.meta_resolution = 2
    inst.f_max = 2
    inst.f_dead = 0.1
    inst.decay = 0.02
    inst.point_split = 6
    inst.extend_spread = 45

    return inst
end

function reset_ff(ff)
    ff.field = {}
    ff.metafield = {}
    ff.contacts = {}
end

function inst_field_contact(point, hit_point, normal, shape)
    local inst = {}
    inst.point = point
    inst.hit_point = hit_point
    inst.normal = normal
    inst.shape = shape
    return inst
end

function inst_field_point(coord, resolution)
    local inst = {}
    inst.resolution = resolution
    inst.coord = coord
    local half_res = resolution/2
    inst.pos = VecAdd(VecScale(coord, inst.resolution), VecScale(Vec(1,1,1), half_res))
    inst.dir = Vec(0,1,0)
    inst.mag = 1
    inst.vec = Vec(0,1,0)
    inst.edge = false
    inst.type = point_type.base
    return inst
end

function set_point_vec(point, vec)
    point.vec = vec
    point.dir = VecNormalize(vec)
    point.mag = VecLength(vec)
end

function set_point_dir_mag(point, dir, mag)
    point.dir = dir
    point.mag = mag
    point.vec = VecScale(dir, mag)
end

function apply_force(ff, pos, force)
    local coord = pos_to_coord(pos, ff.resolution)
    local point = field_get(ff.field, coord)
    if point == nil then 
        point = inst_field_point(coord, ff.resolution)
        point.edge = true
        field_put(ff.field, point, point.coord)
    end
    set_point_vec(point, VecAdd(point.vec, force))
end

function extend_field(ff)
    ff.contacts = {}
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        if point.edge then 
            extend_point(ff, point)
            local extend_dirs = radiate(point.vec, ff.extend_spread, ff.point_split)
            for i = 1, #extend_dirs do
                -- create a temporary point to act as the parent to the potential 
                -- extension
                local extend_dir = extend_dirs[i]
                local temp_point = inst_field_point(point.coord, ff.resolution)
                set_point_vec(temp_point, VecScale(extend_dir, point.mag))
                extend_point(ff, temp_point)
            end   
            point.edge = false 
        end
    end
end

function extend_point(ff, point, new_extensions)
    local extend_dir = point.dir
    local extend_coord = round_vec(VecAdd(point.coord, extend_dir))
    local extension_point = field_get(ff.field, extend_coord)
    -- only put a point where there isn't one already
    if extension_point == nil then 
        -- check if we're hitting something on the way to extending
        local hit, dist, normal, shape = QueryRaycast(point.pos, extend_dir, 2 * ff.resolution, 0.025)
        if hit then 
            -- log the contact, don't create a new extension
            local hit_point = VecAdd(point.pos, VecScale(extend_dir, dist))
            table.insert(ff.contacts, inst_field_contact(point, hit_point, normal, shape))
        else 
            -- extend into the new space
            extension_point = inst_field_point(extend_coord, ff.resolution)
            set_point_vec(extension_point, point.vec)
            extension_point.edge = true
            field_put(ff.field, extension_point, extension_point.coord)
        end
    end
end

function propagate_field_forces(ff)
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        propagate_point_force(ff, point)
        local prop_dirs = radiate(point.vec, ff.extend_spread, ff.point_split)
        for i = 1, #prop_dirs do
            local prop_dir = prop_dirs[i]
            local temp_point = inst_field_point(point.coord, ff.resolution)
            set_point_vec(temp_point, VecScale(prop_dir, point.mag))
            propagate_point_force(ff, temp_point)
        end
    end
end

function propagate_point_force(ff, point)
    local force_dir = point.dir
    local coord_prime = round_vec(VecAdd(point.coord, force_dir))
    local point_prime = field_get(ff.field, coord_prime)
    if point_prime ~= nil then 
        local dir = VecAdd(point_prime.vec, point.vec)
        dir = VecAdd(dir, Vec(0, ff.heat_rise, 0))
        dir = VecNormalize(dir)
        local mag = (point_prime.mag + point.mag) / 2
        set_point_vec(point, VecScale(point.vec, (1 - ff.decay))) 
        set_point_dir_mag(point_prime, dir, mag)
    end
end

function normalize_field(ff)
    local points = flatten(ff.field)
    if #points > FF.MAX_SIM_POINTS then
        table.sort(points, function (p1, p2) return p1.mag < p2.mag end )
        while #points > FF.MAX_SIM_POINTS do
            local index = math.ceil((1.6 * math.random() - 1)^2 * #points)
            if index ~= 0 then 
                local remove_point = points[index]
                field_put(ff.field, nil, remove_point.coord)
                table.remove(points, index)
            end
        end
    end
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        set_point_vec(point, VecScale(point.vec, (1 - ff.decay)))
        if point.mag > ff.f_max then 
            set_point_vec(point, VecScale(point.dir, ff.f_max))
        elseif point.mag < ff.f_dead then 
            field_put(ff.field, nil, point.coord)
        end
    end
end

function refresh_metafield(ff)
    local new_metafield = {}
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        local meta_coord = Vec(
            math.floor(point.pos[1] / ff.meta_resolution),
            math.floor(point.pos[2] / ff.meta_resolution),
            math.floor(point.pos[3] / ff.meta_resolution))
        local meta_point = field_get(new_metafield, meta_coord)
        if meta_point == nil then 
            meta_point = inst_field_point(meta_coord, ff.meta_resolution)
            meta_point.type = point_type.meta
            meta_point.vec = point.vec
            field_put(new_metafield, meta_point, meta_point.coord)
        else
            set_point_vec(meta_point, VecScale(VecAdd(meta_point.vec, point.vec), 0.5))
        end
    end
    ff.metafield = new_metafield
end

function pos_to_coord(pos, resolution)
    return Vec(
        math.floor(pos[1] / resolution),
        math.floor(pos[2] / resolution),
        math.floor(pos[3] / resolution))
end

function field_put(field, value, coord)
    -- field["points"] is a cache of the flattened
    -- multidimensional array. Clearing it forces
    -- regeneration.

    local xk = tostring(coord[1])
    local yk = tostring(coord[2])
    local zk = tostring(coord[3])

    -- allocate
    if field[xk] == nil then
        field[xk] = {}
    end

    if field[xk][yk] == nil then
        field[xk][yk] = {}
    end

    if field[xk][yk][zk] == nil then 
        field["points"] = nil
    end

    -- set
    field[xk][yk][zk] = value

    -- deallocate
    if value == nil then 
        field["points"] = nil
        local count = pairs(field[xk][yk])
        if count == 0 then 
            field[xk][yk] = nil
        end

        count = pairs(field[xk])
        if count == 0 then 
            field[xk] = nil
        end
    end
end

function field_get(field, coord)
    local xk = tostring(coord[1])
    local yk = tostring(coord[2])
    local zk = tostring(coord[3])
    if field[xk] == nil then
        return nil
    end
    if field[xk][yk] == nil then
        return nil
    end
    if field[xk][yk][zk] == nil then
        return nil
    end
    return field[xk][yk][zk]
end

function flatten(field)
    if field["points"] == nil then 
        local points = {}
        for x, yt in pairs(field) do
            for y, zt in pairs(yt) do
                for z, point in pairs (zt) do
                    table.insert(points, point)
                end
            end
        end
        field["points"] = points
    end

    return shallow_copy(field["points"])
end

function debug_field(field)
    local points = flatten(field)
    for i = 1, #points do
        local point = points[i]
        local color = debug_color(point)
        DebugCross(point.pos, color[1], color[2], color[3])
        DebugLine(point.pos, VecAdd(point.pos, point.vec), color[1], color[2], color[3])
    end
    -- DebugPrint("points="..#points)
end

function debug_color(ff, point)
    local mag = VecLength(point.vec)
    local r = mag / ff.f_max
    local b = 1 - r
    return Vec(r, 0, b)
end

function force_field_ff_tick(ff, dt)
    -- debug_field(ff.field)
    if ff.tick_count == 0 then ff.tick_count = ff.tick_reset end
    if (ff.tick_count + 1) % 2 == 0 then 
        propagate_field_forces(ff)
        normalize_field(ff)
        refresh_metafield(ff)
    elseif ff.tick_count % 2 == 0 then 
        extend_field(ff)
    end
    ff.tick_count = ff.tick_count - 1
end

point_type = enum {
	"base",
	"meta"
}
