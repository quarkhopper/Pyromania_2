function random_float_in_range(low, high)
    return (math.random() * (high - low)) + low
end

function get_variation_term(fraction, value)
    local variation = fraction * value
    return random_float_in_range(-variation, variation)
end

function split_string(input_string, separator)
    if input_string == nil or input_string == "" then
        return {}
    end
    if separator == nil then
        separator = "%s"
    end
    local t = {}
    for str in string.gmatch(input_string, "([^" .. separator .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function join_strings(input_table, delimeter)
    if input_table == nil or #input_table == 0 then
        return ""
    end
    if #input_table == 1 then
        return tostring(input_table[1])
    end

    local concat_string = tostring(input_table[1])
    for i = 2, #input_table do
        concat_string = concat_string .. delimeter .. tostring(input_table[i])
    end

    return concat_string
end

function vec_to_string(vec)
    return vec[1] .. DELIM.VEC .. vec[2] .. DELIM.VEC .. vec[3]
end

function string_to_vec(vec_string)
    local parts = split_string(vec_string, DELIM.VEC)
    return Vec(parts[1], parts[2], parts[3])
end

function box_vec(pos, size)
    local vecA = VecSub(pos, Vec(size/2, size/2, size/2))
    local vecB = VecAdd(pos, Vec(size/2, size/2, size/2))
    return {vecA, vecB}
end

function random_vec(magnitude)
    return Vec(random_vec_component(magnitude), random_vec_component(magnitude), random_vec_component(magnitude))
end

function random_vec_component(magnitude)
    return (math.random() * magnitude * 2) - magnitude
end

function reflection_vector(vec, normal)
	local u = VecScale((VecDot(vec, normal) / VecDot(normal, normal)), normal)
	local w = VecSub(vec, u)
	return VecSub(w, u)
end

function vecs_equal(vec_a, vec_b)
    return vec_a[1] == vec_b[1] and
        vec_a[2] == vec_b[2] and
        vec_a[3] == vec_b[3]
end

function radiate(center_vec, spread_angle, count, offset)
    -- returns unit radiations from a center vec
    offset = offset or 0
    local dir = VecNormalize(center_vec)
    local t = Transform(Vec(), QuatLookAt(Vec(), VecAdd(Vec(), center_vec)))
	local delta = 360/count

    local radiations = {}
	for i = 1, count do
		local a = QuatRotateQuat(QuatEuler(0, 0, (i * delta) + offset), QuatEuler(spread_angle, 0, 0))
		local v = QuatRotateVec(a, FF.FORWARD)
		table.insert(radiations, TransformToParentPoint(t, v))
	end
    return radiations
end

function round_vec(vec)
    return Vec(
        round(vec[1]),
        round(vec[2]),
        round(vec[3])
    )
end

function random_float(min, max)
    local range = max - min
    return (math.random() * range) + min
end

function random_value_per_ratio(value_table, ratios)
	local winner = 1
    local high = 0
    for i = 1, #value_table do
		if ratios[i] ~= 0 then
			local value = math.random(0, ratios[i])
			if value >= high then
				winner = i
				high = value
			end
		end
    end

    return value_table[winner]
end

function fraction_to_range_value(fraction, min, max)
    local range = max - min
    return (range * fraction) + min
end

function range_value_to_fraction(value, min, max)
    local frac = (value - min) / (max - min)
    return frac
end

function get_keys_and_values(t)
    local keys = {}
    local values = {}
    for k, v in pairs(t) do
        table.insert(keys, k)
        table.insert(values, v)
    end
    return keys, values
end

function bracket_value(value, max, min)
    return math.max(math.min(max, value), min)
end

function round_to_interval(value, interval)
    return math.floor((value + (interval/2)) / interval) * interval
end

function round_to_place(value, place)
	local multiplier = math.pow(10, place)
	local rounded = math.floor(value * multiplier)
	return rounded / multiplier
end

function round(value)
    return math.floor(value + 0.5)
end

function is_number(value)
    if tonumber(value) ~= nil then
        return true
    end
    return false
end

string_to_boolean = {
    ["true"] = true,
    ["false"] = false
}

function shallow_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function remove_by_value(tab, value)
    local index = nil
    for i = 1, #tab do
        if tab[i] == value then 
            index = i
            break
        end
    end
    if index ~= nil then 
        table.remove(tab, index)
    end
end

function enum(source)
    local enum_table = {}
    for i = 1, #source do
        local value = source[i]
        enum_table[value] = i
    end

    return enum_table
end

function enum_to_string(source)
    if source == nil then
        return ""
    end
    local key_table = {}
    local value_table = {}
    for k, v in pairs(source) do
        key_table[#key_table + 1] = k
        value_table[#value_table + 1] = v
    end

    return join_strings(key_table, DELIM.STRINGS) .. DELIM.ENUM_PAIR ..
               join_strings(value_table, DELIM.STRINGS)
end

function string_to_enum(source)
    if source == nil or source == "" then
        return {}
    end
    local parts = split_string(source, DELIM.ENUM_PAIR)
    local keys = split_string(parts[1], DELIM.STRINGS)
    local values = split_string(parts[2], DELIM.STRINGS)

    local enum_table = {}
    for i = 1, #keys do
        enum_table[keys[i]] = tonumber(values[i])
    end

    return enum_table
end

function get_enum_key(value, enumTable)
    for k, v in pairs(enumTable) do
        if v == value then
            return k
        end
    end
end

function cycle_value(value, step, min, max)
    step = step or 1
    value = value + step
    if value > max then
        value = min
    end
    return value
end

function hurt_player(amount)
    local health = GetPlayerHealth()
    SetPlayerHealth(health - amount)
end

function blend_color(fraction, color_a, color_b)
    local a = fraction_to_range_value(fraction, color_a[1], color_b[1])
    local b = fraction_to_range_value(fraction, color_a[2], color_b[2])
    local c = fraction_to_range_value(fraction, color_a[3], color_b[3])
    local color = Vec(a, b, c)
    return color
end
