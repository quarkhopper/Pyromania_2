#include "PyroField.lua"

TOOL = {}
TOOL.GENERAL = {}
TOOL.BOMB = {}
TOOL.ROCKET = {}
TOOL.THROWER = {}

function save_option_sets()
	save_option_set(TOOL.GENERAL)
	save_option_set(TOOL.BOMB)
	save_option_set(TOOL.ROCKET)
	save_option_set(TOOL.THROWER)
end

function load_option_sets()
	TOOL.GENERAL = load_option_set("general", true)
	TOOL.BOMB = load_option_set("bomb", true)
    init_pyro(TOOL.BOMB)
	TOOL.ROCKET = load_option_set("rocket", true)
    init_pyro(TOOL.ROCKET)
	TOOL.THROWER = load_option_set("thrower", true)
    init_pyro(TOOL.THROWER)
    all_option_sets = {TOOL.BOMB, TOOL.ROCKET, TOOL.THROWER, TOOL.GENERAL}
end

function init_pyro(tool)
    local pyro = inst_pyro()
    pyro.flames_per_spawn = tool.flames_per_point.value
    pyro.flame_light_intensity = tool.flame_light_intensity.value
    pyro.flame_dead_force = tool.flame_dead_force.value
    pyro.max_smoke_size = tool.max_smoke_size.value
    pyro.min_smoke_size = tool.min_smoke_size.value
    pyro.smoke_life = tool.smoke_life.value
    pyro.impulse_const = tool.impulse_const.value
    pyro.impulse_radius = tool.impulse_radius.value
    pyro.fire_ignition_radius = tool.fire_ignition_radius.value
    pyro.fire_density = tool.fire_density.value
    pyro.hole_punch_scale = tool.contact_damage_scale.value
    pyro.max_player_hurt = tool.max_player_hurt.value
    pyro.rainbow_mode = tool.rainbow_mode.value
    pyro.color_cool = tool.flame_color_cool.value
    pyro.color_hot = tool.flame_color_hot.value
    pyro.ff.resolution = tool.field_resolution.value
    pyro.ff.meta_resolution = tool.meta_resolution.value
    pyro.ff.f_max = tool.f_max.value
    pyro.ff.f_dead = tool.dead_force.value
    pyro.ff.decay = tool.decay.value
    pyro.ff.prop_decay = tool.prop_decay.value
    pyro.ff.heat_rise = tool.heat_rise.value
    pyro.ff.point_split = tool.point_split.value
    pyro.ff.extend_spread = tool.extend_spread.value
    tool.pyro = pyro
end