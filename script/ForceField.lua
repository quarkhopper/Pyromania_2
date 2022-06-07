#include "Utils.lua"

FF = {} -- library constants
FF.FORWARD = Vec(0, 0, -1)
FF.MAX_SIM_POINTS = 200
FF.BIAS_CONST = 100
FF.MIN_PROP_ANGLE = 10
FF.MAX_PROP_ANGLE = 30

function inst_force_field_ff()
    -- create a force field instance.
    local inst = {}
    -- The field is a hashed multidim array for fast location searching
    inst.field = {}
    -- the metafield is a lower resolution array that's an average of a 
    -- block of adjacent vectors. Can be operated on instead of the base
    -- field for performance, such as to drive effects that don't require
    -- high resolution.
    inst.metafield = {}
    -- These are "hit" events when a vector force tries to propagate into 
    -- a shape. This list is cleared before every propagation. This field is 
    -- regenerated regularly from the base field.
    inst.contacts = {}

    -- Resolution of the base field. How many world units per force vector. (actually the reverse of an 
    -- actual resolution  number)
    inst.resolution = 0.5
    -- Resolution of the metafield
    inst.meta_resolution = 2
    -- The maximum force assignable to a vector. It's clamped below this number.
    inst.f_max = 500
    -- The force below which vectors are culled from the field
    inst.f_dead = 0.1
    -- Field propagation produces this many spokes radiating out from the parent
    -- vector into other field coordinates. That may combine with existing vectors in those
    -- coordinates or extend the field into new coordinates (adding to the field)
    inst.prop_split = 6
    -- The angle in degrees that spokes are produced from the center parent vector when 
    -- propagating. 
    -- inst.prop_angle = 45
    -- directional variation added on propagation.
    inst.dir_jitter = 0
    -- directional bias to apply over time, such as for heat rise or gravity. Does not affect force magnitude.
    inst.bias = Vec()
    -- debug total energy
    inst.energy = 0
    -- the radius in coordinate space that propagation reaches. Larger values than 1.5 may skip coordinates to
    -- propagate. Effectively this lets the field grow faster dimensionally.
    inst.extend_scale = 1.5
    inst.trans_gain = 0.01
    inst.bias_gain = 0.8
    return inst
end

function reset_ff(ff)
    ff.field = {}
    ff.metafield = {}
    ff.contacts = {}
end

function inst_field_contact(point, hit_point, normal, shape)
    -- A contact is a record of any time a force is propagated into a coordinates
    -- that is occupied by shape voxels. This is interpreted as a "hit" event by 
    -- the force. No new vector is created to occupy that coordinate, though if 
    -- a hole is created by a higher level process the force may be able to spread
    -- into the unnoccupied coordinate in the next tick.
    local inst = {}
    inst.point = point
    inst.hit_point = hit_point
    inst.normal = normal
    inst.shape = shape
    return inst
end

function inst_field_point(coord, resolution)
    -- One vector in the field. There's a static for setting either the position
    -- or the dir/mag combo to keep them consistent for efficiency so this doesn't
    -- have to be recalculated over and over. (I would love it if OOP was allowed in 
    -- the quickloaded code for the game so I could just make that a method...)
    local inst = {}
    inst.resolution = resolution
    inst.coord = coord
    local half_res = resolution/2
    inst.pos = VecAdd(VecScale(coord, inst.resolution), VecScale(Vec(1,1,1), half_res))
    inst.dir = Vec()
    inst.mag = 0
    inst.vec = Vec()
    inst.type = point_type.base
    inst.cull = false
    inst.hit = false
    return inst
end

function set_point_vec(point, vec)
    -- Sets the force vector of a point and updates the 
    -- dir/mag attributes
    point.vec = vec
    point.dir = VecNormalize(vec)
    local new_mag = VecLength(vec)
    point.mag = new_mag
end

function set_point_dir_mag(point, dir, mag)
    -- sets the dir/mag of the field point and updates the
    -- vector
    point.dir = dir
    point.mag = mag
    point.vec = VecScale(dir, mag)
end

function apply_force(ff, pos, force)
    -- This is an interface function that sparks a force propagation through
    -- through the field. 
    local coord = pos_to_coord(pos, ff.resolution)
    local point = field_get(ff.field, coord)
    -- if this point doesn't exist yet in the coord of the field, we
    -- have a couple things to do
    if point == nil then 
        point = inst_field_point(coord, ff.resolution)
        -- insert a point into the field
        field_put(ff.field, point, point.coord)
    end
    set_point_vec(point, VecAdd(point.vec, force))
end

function propagate_field_forces(ff, dt)
    if ff.trans_gain == 0 or ff.extend_scale == 0 then return end
    -- propagate the force outside of each point into the coord its pointing at 
    -- and average the vectors, reducing the parent mag by a proportion. 
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        -- points start the cycle with the call flag set to true. If the propagation cycle ends
        -- and the cull flag has not been set to false then the point will be culled 
        -- in the normalization phase this cycle.
        point.cull = true
        local trans_mag = (point.mag/(ff.prop_split + 1)) * fraction_to_range_value(ff.trans_gain, 0, 1/dt) * dt
        propagate_point_force(ff, point, point.dir, trans_mag, dt)
        -- propagate the force in a spread to other vectors around the direction it's pointing.
        -- See extension method above for details about radiate(). 
        local force_n = math.max(0, range_value_to_fraction(point.mag, ff.f_dead, ff.f_max))
        local prop_angle = fraction_to_range_value(math.sqrt(force_n), FF.MAX_PROP_ANGLE, FF.MIN_PROP_ANGLE)
        local prop_dirs = radiate(point.vec, prop_angle, ff.prop_split, math.random() * 360)
        for i = 1, #prop_dirs do
            -- propagate the force in the direction of radiation spokes
            local prop_dir = prop_dirs[i]
            propagate_point_force(ff, point, prop_dir, trans_mag, dt)
        end
        if point.mag > ff.f_dead then point.cull = false end
    end
end

function propagate_point_force(ff, point, trans_dir, trans_mag, dt)
    -- propagate force to a vector in a target coordinate given a parent vector.
    local jitter_mag = fraction_to_range_value(ff.dir_jitter/10, 0, 1)
    trans_dir = VecNormalize(VecAdd(trans_dir, jitter_mag))
    local trans_vec = VecScale(trans_dir, trans_mag)
    local coord_prime = round_vec(VecAdd(point.coord, VecScale(trans_dir, random_float_in_range(1, ff.extend_scale))))
    if not vecs_equal(coord_prime, point.coord) then 
        local point_prime = field_get(ff.field, coord_prime)
        if point_prime == nil then
            -- check if we're hitting something on the way to extending
            local hit, dist, normal, shape = QueryRaycast(point.pos, trans_dir, 2 * ff.resolution * ff.extend_scale, 0.025)
            if hit then 

                -- log the contact, don't create a new extension
                local hit_point = VecAdd(point.pos, VecScale(trans_dir, dist))
                table.insert(ff.contacts, inst_field_contact(point, hit_point, normal, shape))
                -- redirect a vector parallel to the surface
                -- when directly opposed to the normal of the impacted surface the 
                -- abs value dot product (for unit vectors) will be 1. This is when 
                -- the force vector will be directly annihilated. parallel to the
                -- surface will be 0, and the force vector is not redirected at all 
                local redirection_factor = math.abs(VecDot(normal, trans_dir))
                -- fun note! When I first made this calculation I did an oopsy and 
                -- scaled the normal by the distance to the hit point (instead of, at max,
                -- the magnitude of the force). When a force impacted
                -- a surface at shallower than right angles this ADDED energy, and 
                -- caused fire to spread out and crawl over everything in the map.
                -- it looked really cool but looking really cool as your application 
                -- terminates upsets people, I GUESS.
                local new_vec =  VecAdd(point.vec, VecScale(normal, point.mag * redirection_factor))
                -- readjust as this sometimes results in added energy. 
                local new_vec = VecScale(VecNormalize(new_vec), math.min(point.mag, VecLength(new_vec)))
                set_point_vec(point, new_vec)
                point.hit = true
            elseif point.mag > ff.f_dead then 
                -- create the point in the new space
                point_prime = inst_field_point(coord_prime, ff.resolution)
                set_point_dir_mag(point_prime, trans_dir, trans_mag)
                field_put(ff.field, point_prime, point_prime.coord)
                -- do not cull a new point or a point that has extended the field
                point_prime.cull = false
                point.cull = false
            end
        else
            local new_dir = VecNormalize(VecAdd(point_prime.dir, trans_dir))
            if point.mag > point_prime.mag then 
                -- if there is a significant transfer of force then do not call
                point_prime.cull = false
                point.cull = false
            end
            set_point_dir_mag(point_prime, new_dir, point_prime.mag + trans_mag)

        end
        set_point_dir_mag(point, point.dir, math.max(0, point.mag - trans_mag))
    end
end

function normalize_field(ff, dt)
    -- Remove points above the set limit of points to simulate in the field. 
    -- Go through all points, clamp the field vector magnitudes to the max
    -- and cull the field vectors that fall below dead magnitude. 

    -- remove points until we're under the sim limit
    local points = flatten(ff.field)
    if #points > FF.MAX_SIM_POINTS then
        while #points > FF.MAX_SIM_POINTS do
            local index = math.random(#points)
            if index ~= 0 then 
                local remove_point = points[index]
                field_put(ff.field, nil, remove_point.coord)
                table.remove(points, index)
            end
        end
    end

    -- If any point magnitude is above max then it will be clamped to the maximum magnitude allowed.
    ff.energy = 0
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        if point.mag > ff.f_max then 
            set_point_dir_mag(point, point.dir, ff.f_max)
            ff.energy = ff.energy + ff.f_max
        elseif point.cull then 
            -- judgement day. I see the truth of your cull flags and 
            -- I say to you, vector point: you shall not be spared on that
            -- day!
            field_put(ff.field, nil, point.coord)
        else
            ff.energy = ff.energy + point.mag
        end
    end
end

function apply_bias(ff, dt)
    if ff.bias == 0 then return end
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        local new_dir = VecNormalize(VecAdd(point.dir, VecScale(ff.bias, ff.bias_gain * FF.BIAS_CONST * dt)))
        set_point_dir_mag(point, new_dir, point.mag)
    end
end

function refresh_metafield(ff)
    -- Rebuild the metafield by averaging the points of the base field in 
    -- the coordinates of the lower resolution metafield. The result is a 
    -- metafield that is smaller and summarizes what's gpoing on in larger 
    -- blocks.
    local new_metafield = {}
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        -- find the meta-coordinate for this base field point. It will belong 
        -- to the same meta-coord as several other base field points and be 
        -- combined (if the resolution of the metafield is lower)
        local meta_coord = Vec(
            math.floor(point.pos[1] / ff.meta_resolution),
            math.floor(point.pos[2] / ff.meta_resolution),
            math.floor(point.pos[3] / ff.meta_resolution))
        local meta_point = field_get(new_metafield, meta_coord)
        -- first base field point in this metafield coordinate, so make a new
        -- point. 
        if meta_point == nil then 
            meta_point = inst_field_point(meta_coord, ff.meta_resolution)
            meta_point.type = point_type.meta
            set_point_vec(meta_point, point.vec)
            field_put(new_metafield, meta_point, meta_point.coord)
        else
            -- Average the base field point into the existing metafield point.
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
    -- Puts a value into a field at a coordinate.
    -- Fields are a hashed multidim array. They automatically allocate when 
    -- needed and will automatically deallocate when elements are set to nil.
    -- Optimized for fast access.

    -- field["points"] is a cache of the flattened
    -- multidimensional array. Clearing it forces
    -- regeneration. This is cleared whenever the field changes. 

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
    -- Get a value from a field coordinate.
    -- See field_put() for description of what a field is and how it
    -- operates.
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
    -- flatten the entire field into a list of points (values at coordinates).
    -- Will return a cached list unless that list is nil.
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

function debug_field(ff)
    -- debug the field by showing vector line indicators
    local points = flatten(ff.field)
    for i = 1, #points do
        local point = points[i]
        debug_point(ff, point)
    end
end

function debug_point(ff, point)
    local color = debug_color(ff, point)
    DebugCross(point.pos, color[1], color[2], color[3])
    local mag = point.mag
    if point.mag > 10 then
        mag = math.log10(point.mag) 
    end
    DebugLine(point.pos, VecAdd(point.pos, VecScale(point.dir, mag)), color[1], color[2], color[3])
end

function debug_color(ff, point)
    -- color code the debug vector line by the proportion 
    -- of maximum force it is. 
    local r = point.mag / ff.f_max
    local b = 1 - r
    return Vec(r, 0, b)
end


function force_field_ff_tick(ff, dt)

    if DEBUG_MODE then
        debug_field(ff)
    end

    propagate_field_forces(ff, dt)
    apply_bias(ff, dt)
    normalize_field(ff, dt)
    refresh_metafield(ff)
end

point_type = enum {
	"base",
	"meta"
}
