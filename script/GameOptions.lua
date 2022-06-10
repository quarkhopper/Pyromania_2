#include "ForceField.lua"

function create_option_set()
	local inst = {}
	inst.name = "Unnamed"
	inst.display_name = "Unnamed option set"
	inst.version = CURRENT_VERSION
	inst.options = {}

	return inst
end

function option_set_to_string(inst)
	local ser_parts = {inst.name, inst.display_name, inst.version}
	for i = 1, #inst.options do
		ser_parts[#ser_parts + 1] = mode_option_to_string(inst.options[i])
	end
	return join_strings(ser_parts, DELIM.OPTION_SET)
end

function save_option_set(inst)
	if inst.name == "" or inst.name == nil then return end
	SetString(REG.PREFIX_TOOL_OPTIONS.."."..inst.name, option_set_to_string(inst))
end

function load_option_set(name, create_if_not_found)
	local ser = GetString(REG.PREFIX_TOOL_OPTIONS.."."..name)
	if ser == "" then
		if create_if_not_found then
			local test = create_option_set_by_name(name)
			return test
		else 
			return nil
		end
	end
	ser = migrate_option_set(ser)
	local options = option_set_from_string(ser)
	options.name = name
	return options
end

function option_set_from_string(ser)
	local options = create_option_set()
	options.options = {}
	local option_sers = split_string(ser, DELIM.OPTION_SET)
	options.name = option_sers[1]
	options.display_name = option_sers[2]
	options.version = option_sers[3]
	local parse_start_index = 4
	for i = parse_start_index, #option_sers do
		local option_ser = option_sers[i]
		local option = mode_option_from_string(option_ser)
		options[option.key] = option
		table.insert(options.options, option)
	end
	return options
end

function option_set_reset(name)
	ClearKey(REG.PREFIX_TOOL_OPTIONS.."."..name)
end

function create_mode_option(o_type, value, key, friendly_name)
	local inst = {}
	inst.type = o_type or option_type.numeric
	inst.value = value
	inst.range = {}
	inst.range.upper = 1
	inst.range.lower = 0
	inst.step = 1
	inst.accepted_values = {}
	inst.key = key or "unnamed_option"
	inst.friendly_name = friendly_name or "Unnamed option"

	return inst
end

function mode_option_to_string(inst)
	local parts = {}
	parts[1] = tostring(inst.type)
	if inst.type == option_type.color then
		parts[2] = vec_to_string(inst.value)
	else
		parts[2] = inst.value
	end
	parts[3] = tostring(inst.range.lower)
	parts[4] = tostring(inst.range.upper)
	parts[5] = tostring(inst.step)
	parts[6] = enum_to_string(inst.accepted_values)
	parts[7] = inst.key
	parts[8] = inst.friendly_name

	return join_strings(parts, DELIM.OPTION)
end

function mode_option_set_value(inst, value)
	if inst.type == option_type.numeric then
		inst.value = bracket_value(value, inst.range.upper, inst.range.lower) or 0
	else
		inst.value = value
	end
end

function mode_option_from_string(ser)
	local option = create_mode_option()
	local parts = split_string(ser, DELIM.OPTION)
	option.type = tonumber(parts[1])
	if option.type == option_type.bool then
		option.value = string_to_boolean[parts[2]]
	elseif option.type == option_type.color then
		option.value = string_to_vec(parts[2])
	else
		option.value = tonumber(parts[2])
	end
	
	if parts[3] ~= nil then
		option.range.lower = tonumber(parts[3])
	end
	if parts[4] ~= nil then
		option.range.upper = tonumber(parts[4])
	end
	if parts[5] ~= nil then
		option.step = tonumber(parts[5])
	end
	if parts[6] ~= nil then 
		option.accepted_values = string_to_enum(parts[6])
	end
	option.key = parts[7]
	option.friendly_name = parts[8]
	return option
end

function create_general_option_set()
    local oSet = create_option_set()
    oSet.name = "general"
	oSet.display_name = "General"
    oSet.version = CURRENT_VERSION

	oSet.max_flames = create_mode_option(
		option_type.numeric, 
		500,
		"max_flames",
		"Max flames to render")
	oSet.max_flames.range.lower = 1
	oSet.max_flames.range.upper = 1000
	oSet.max_flames.step = 1
	oSet.options[#oSet.options + 1] = oSet.max_flames

	oSet.simulation_points = create_mode_option(
		option_type.numeric, 
		200,
		"simulation_points",
		"Max field points")
	oSet.simulation_points.range.lower = 1
	oSet.simulation_points.range.upper = 1000
	oSet.simulation_points.step = 1
	oSet.options[#oSet.options + 1] = oSet.simulation_points

	oSet.visible_shock_waves = create_mode_option(
		option_type.enum,
		on_off.on,
		"visible_shock_waves",
		"Visible shock waves")
	oSet.visible_shock_waves.accepted_values = on_off
	oSet.options[#oSet.options + 1] = oSet.visible_shock_waves

	return oSet
end

function create_mode_option_set(name, display_name)
    local oSet = create_option_set()
    oSet.name = name
	oSet.display_name = display_name
    oSet.version = CURRENT_VERSION
	oSet.options = {}

	oSet.max_force = create_mode_option(
		option_type.numeric, 
		1000,
		"max_force",
		"Imparted force per point")
	oSet.max_force.range.lower = 1
	oSet.max_force.range.upper = 100000
	oSet.max_force.step = 10
	oSet.options[#oSet.options + 1] = oSet.max_force

	oSet.dead_threshold = create_mode_option(
		option_type.numeric, 
		0.1,
		"dead_threshold",
		"Dead force")
	oSet.dead_threshold.range.lower = 0.001
	oSet.dead_threshold.range.upper = 1
	oSet.dead_threshold.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.dead_threshold
	
	oSet.flame_dead_threshold = create_mode_option(
		option_type.numeric, 
		10,
		"flame_dead_threshold",
		"Flame dead force")
	oSet.flame_dead_threshold.range.lower = 0
	oSet.flame_dead_threshold.range.upper = 10
	oSet.flame_dead_threshold.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.flame_dead_threshold

	oSet.bias_gain = create_mode_option(
		option_type.numeric, 
		0.01,
		"bias_gain",
		"Directional bias gain")
	oSet.bias_gain.range.lower = 0
	oSet.bias_gain.range.upper = 1
	oSet.bias_gain.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.bias_gain

	oSet.heat_rise = create_mode_option(
		option_type.numeric, 
		0.2,
		"heat_rise",
		"Upward directional bias")
	oSet.heat_rise.range.lower = 0
	oSet.heat_rise.range.upper = 1
	oSet.heat_rise.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.heat_rise

	oSet.dir_jitter = create_mode_option(
		option_type.numeric, 
		0,
		"dir_jitter",
		"Directional instability")
	oSet.dir_jitter.range.lower = 0
	oSet.dir_jitter.range.upper = 10
	oSet.dir_jitter.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.dir_jitter

	oSet.field_resolution = create_mode_option(
		option_type.numeric, 
		0.5,
		"field_resolution",
		"Field resolution")
	oSet.field_resolution.range.lower = 0.1
	oSet.field_resolution.range.upper = 10
	oSet.field_resolution.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.field_resolution

	oSet.meta_resolution = create_mode_option(
		option_type.numeric, 
		2,
		"meta_resolution",
		"Metafield resolution")
	oSet.meta_resolution.range.lower = 0.1
	oSet.meta_resolution.range.upper = 10
	oSet.meta_resolution.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.meta_resolution

	oSet.flames_per_point = create_mode_option(
		option_type.numeric, 
		5,
		"flames_per_point",
		"Flames spawn per field point")
	oSet.flames_per_point.range.lower = 1
	oSet.flames_per_point.range.upper = 100
	oSet.flames_per_point.step = 1
	oSet.options[#oSet.options + 1] = oSet.flames_per_point

	oSet.flame_light_intensity = create_mode_option(
		option_type.numeric, 
		3,
		"flame_light_intensity",
		"Flame light intensity")
	oSet.flame_light_intensity.range.lower = 0.1
	oSet.flame_light_intensity.range.upper = 10
	oSet.flame_light_intensity.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.flame_light_intensity

    oSet.flame_color_hot = create_mode_option(
		option_type.color,
		Vec(7.6, 0.6, 0.9),
		"flame_color_hot",
		"Hot flame color")
	oSet.options[#oSet.options + 1] = oSet.flame_color_hot

    oSet.flame_color_cool = create_mode_option(
		option_type.color,
		CONSTS.FLAME_COLOR_DEFAULT,
		"flame_color_cool",
		"Cool flame color")
	oSet.options[#oSet.options + 1] = oSet.flame_color_cool

	oSet.rainbow_mode = create_mode_option(
		option_type.enum,
		on_off.off,
		"rainbow_mode",
		"Rainbow mode")
	oSet.rainbow_mode.accepted_values = on_off
	oSet.options[#oSet.options + 1] = oSet.rainbow_mode

	oSet.smoke_life = create_mode_option(
		option_type.numeric, 
		2,
		"smoke_life",
		"Lifetime of smoke particles")
	oSet.smoke_life.range.lower = 0
	oSet.smoke_life.range.upper = 5
	oSet.smoke_life.step = 0.5
	oSet.options[#oSet.options + 1] = oSet.smoke_life

	oSet.smoke_amount = create_mode_option(
		option_type.numeric, 
		0.1,
		"smoke_amount",
		"Relative smoke per flame")
	oSet.smoke_amount.range.lower = 0
	oSet.smoke_amount.range.upper = 1
	oSet.smoke_amount.step = 0.01
	oSet.options[#oSet.options + 1] = oSet.smoke_amount

	oSet.impulse_scale = create_mode_option(
		option_type.numeric, 
		1,
		"impulse_scale",
		"Impulse (pushing) scale")
	oSet.impulse_scale.range.lower = 0
	oSet.impulse_scale.range.upper = 1
	oSet.impulse_scale.step = 0.01
	oSet.options[#oSet.options + 1] = oSet.impulse_scale

	oSet.impulse_radius = create_mode_option(
		option_type.numeric, 
		5,
		"impulse_radius",
		"Impulse (pushing) radius")
	oSet.impulse_radius.range.lower = 0
	oSet.impulse_radius.range.upper = 100
	oSet.impulse_radius.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.impulse_radius

	oSet.fire_ignition_radius = create_mode_option(
		option_type.numeric, 
		1.5,
		"fire_ignition_radius",
		"Fire ignition radius")
	oSet.fire_ignition_radius.range.lower = 0
	oSet.fire_ignition_radius.range.upper = 100
	oSet.fire_ignition_radius.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.fire_ignition_radius

	oSet.fire_density = create_mode_option(
		option_type.numeric, 
		4,
		"fire_density",
		"Fire density")
	oSet.fire_density.range.lower = 0
	oSet.fire_density.range.upper = 10
	oSet.fire_density.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.fire_density

	oSet.contact_damage_scale = create_mode_option(
		option_type.numeric, 
		1,
		"contact_damage_scale",
		"Field contact damage scale")
	oSet.contact_damage_scale.range.lower = 0
	oSet.contact_damage_scale.range.upper = 1
	oSet.contact_damage_scale.step = 0.01
	oSet.options[#oSet.options + 1] = oSet.contact_damage_scale

	oSet.max_player_hurt = create_mode_option(
		option_type.numeric, 
		0.55,
		"max_player_hurt",
		"Maximum player damage per tick")
	oSet.max_player_hurt.range.lower = 0
	oSet.max_player_hurt.range.upper = 1
	oSet.max_player_hurt.step = 0.01
	oSet.options[#oSet.options + 1] = oSet.max_player_hurt

    return oSet
end	

function create_bomb_option_set()
	local oSet = create_mode_option_set("bomb", "Bomb settings")

	oSet.explosion_fireball_radius = create_mode_option(
		option_type.numeric, 
		0.5,
		"explosion_fireball_radius",
		"Explosion fireball radius")
	oSet.explosion_fireball_radius.range.lower = 0
	oSet.explosion_fireball_radius.range.upper = 10
	oSet.explosion_fireball_radius.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.explosion_fireball_radius	

	oSet.explosion_seeds = create_mode_option(
		option_type.numeric, 
		10,
		"explosion_seeds",
		"Explosion seed points")
	oSet.explosion_seeds.range.lower = 10
	oSet.explosion_seeds.range.upper = 100
	oSet.explosion_seeds.step = 1
	oSet.options[#oSet.options + 1] = oSet.explosion_seeds	

	oSet.min_random_radius = create_mode_option(
		option_type.numeric, 
		15,
		"min_random_radius",
		"Minimum radius of random explosions")
	oSet.min_random_radius.range.lower = 0
	oSet.min_random_radius.range.upper = 100
	oSet.min_random_radius.step = 1
	oSet.options[#oSet.options + 1] = oSet.min_random_radius
	
	oSet.max_random_radius = create_mode_option(
		option_type.numeric, 
		30,
		"max_random_radius",
		"Maximum radius of random explosions")
	oSet.max_random_radius.range.lower = 0
	oSet.max_random_radius.range.upper = 100
	oSet.max_random_radius.step = 1
	oSet.options[#oSet.options + 1] = oSet.max_random_radius

	-- default values
	oSet.max_force.value = 1000
	oSet.bias_gain.value = 0.4
	oSet.heat_rise.value = 0.1
	oSet.dir_jitter.value = 0
	oSet.field_resolution.value = 0.8
	oSet.meta_resolution.value = 2
	oSet.flames_per_point.value = 4
	oSet.flame_light_intensity.value = 3
	oSet.smoke_life.value = 2
	oSet.smoke_amount.value = 0.3
	oSet.impulse_scale.value = 0.8
	oSet.impulse_radius.value = 5
	oSet.fire_ignition_radius.value = 5
	oSet.fire_density.value = 8
	oSet.contact_damage_scale.value = 0.1
	oSet.max_player_hurt.value = 0.55
	oSet.explosion_fireball_radius.value = 0.5
	oSet.explosion_seeds.value = 100

	return oSet
end

function create_rocket_option_set()
	local oSet = create_mode_option_set("rocket", "Rocket settings")

	oSet.explosion_fireball_radius = create_mode_option(
		option_type.numeric, 
		0.5,
		"explosion_fireball_radius",
		"Explosion fireball radius")
	oSet.explosion_fireball_radius.range.lower = 0
	oSet.explosion_fireball_radius.range.upper = 10
	oSet.explosion_fireball_radius.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.explosion_fireball_radius	

	oSet.explosion_seeds = create_mode_option(
		option_type.numeric, 
		10,
		"explosion_seeds",
		"Explosion seed points")
	oSet.explosion_seeds.range.lower = 10
	oSet.explosion_seeds.range.upper = 100
	oSet.explosion_seeds.step = 1
	oSet.options[#oSet.options + 1] = oSet.explosion_seeds	

	oSet.rate_of_fire = create_mode_option(
		option_type.numeric, 
		1,
		"rate_of_fire",
		"Rate of fire")
	oSet.rate_of_fire.range.lower = 0.1
	oSet.rate_of_fire.range.upper = 1
	oSet.rate_of_fire.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.rate_of_fire	

	oSet.speed = create_mode_option(
		option_type.numeric, 
		2,
		"speed",
		"Speed")
	oSet.speed.range.lower = 0.1
	oSet.speed.range.upper = 10
	oSet.speed.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.speed	

	oSet.max_dist = create_mode_option(
		option_type.numeric, 
		200,
		"max_dist",
		"Max flight distance")
	oSet.max_dist.range.lower = 10
	oSet.max_dist.range.upper = 500
	oSet.max_dist.step = 1
	oSet.options[#oSet.options + 1] = oSet.max_dist	

	-- default values
	oSet.max_force.value = 1000
	oSet.bias_gain.value = 0.25
	oSet.heat_rise.value = 0.1
	oSet.dir_jitter.value = 0
	oSet.field_resolution.value = 0.5
	oSet.meta_resolution.value = 2
	oSet.flames_per_point.value = 4
	oSet.flame_light_intensity.value = 3
	oSet.smoke_life.value = 1
	oSet.smoke_amount.value = 0.1
	oSet.impulse_scale.value = 0.28
	oSet.impulse_radius.value = 5
	oSet.fire_ignition_radius.value = 5
	oSet.fire_density.value = 8
	oSet.contact_damage_scale.value = 0.1
	oSet.max_player_hurt.value = 0.55
	oSet.explosion_fireball_radius.value = 0.1
	oSet.explosion_seeds.value = 50

	return oSet
end

function create_thrower_option_set()
	local oSet = create_mode_option_set("thrower", "Thrower settings")

	oSet.rate_of_fire = create_mode_option(
		option_type.numeric, 
		0.05,
		"rate_of_fire",
		"Rate of fire")
	oSet.rate_of_fire.range.lower = 0.01
	oSet.rate_of_fire.range.upper = 1
	oSet.rate_of_fire.step = 0.01
	oSet.options[#oSet.options + 1] = oSet.rate_of_fire	

	oSet.speed = create_mode_option(
		option_type.numeric, 
		1,
		"speed",
		"Spray velocity")
	oSet.speed.range.lower = 0.1
	oSet.speed.range.upper = 10
	oSet.speed.step = 0.1
	oSet.options[#oSet.options + 1] = oSet.speed

	oSet.max_dist = create_mode_option(
		option_type.numeric, 
		50,
		"max_dist",
		"Max distance")
	oSet.max_dist.range.lower = 10
	oSet.max_dist.range.upper = 500
	oSet.max_dist.step = 1
	oSet.options[#oSet.options + 1] = oSet.max_dist	

	oSet.gravity = create_mode_option(
		option_type.numeric, 
		0.01,
		"gravity",
		"Gravity dir adjust")
	oSet.gravity.range.lower = 0
	oSet.gravity.range.upper = 0.05
	oSet.gravity.step = 0.001
	oSet.options[#oSet.options + 1] = oSet.gravity	

	-- default values
	oSet.max_force.value = 500
	oSet.bias_gain.value = 0.7
	oSet.heat_rise.value = 0.8
	oSet.dir_jitter.value = 0.1
	oSet.field_resolution.value = 0.1
	oSet.meta_resolution.value = 0.5
	oSet.flames_per_point.value = 1
	oSet.flame_light_intensity.value = 1
	oSet.flame_color_hot.value = Vec(7.5, 0.9, 0.6)
	oSet.smoke_life.value = 1
	oSet.smoke_amount.value = 0.1
	oSet.impulse_scale.value = 0.01
	oSet.impulse_radius.value = 0.2
	oSet.fire_ignition_radius.value = 1
	oSet.fire_density.value = 10
	oSet.contact_damage_scale.value = 0.01
	oSet.max_player_hurt.value = 0.1
	oSet.speed.value = 0.6
	
	return oSet
end

function create_option_set_by_name(name)
	if name == "general" then
		return create_general_option_set()		
	elseif name == "bomb" then 
		return create_bomb_option_set()
	elseif name == "rocket" then 
		return create_rocket_option_set()
	elseif name == "thrower" then 
		return create_thrower_option_set()
	end
end

option_type = enum {
	"numeric",
	"enum",
	"bool",
	"color"
}

on_off = enum {
	"off",
	"on"
}

