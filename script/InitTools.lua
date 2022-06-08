#include "PyroField.lua"

-- Stores an instance of a tool (or mode) option set. 
TOOL = {}
-- The general option set for all tools
TOOL.GENERAL = {}
-- The option set for the bomb tool
TOOL.BOMB = {}
-- The option set for the rocket tool
TOOL.ROCKET = {}
-- The option set for the flamethrower tool
TOOL.THROWER = {}

-- Stores a special pyro field for shock wave effects
SHOCK_FIELD = {}

function save_option_sets()
    -- Save the option sets from memory to the savegame.xml file
	save_option_set(TOOL.GENERAL)
	save_option_set(TOOL.BOMB)
	save_option_set(TOOL.ROCKET)
	save_option_set(TOOL.THROWER)
end

function load_option_sets()
    -- Load (or create from defaults) all option sets. Option sets
    -- are collection of values with parameters that determine how they are
    -- constrained, what values are valid and how the option control
    -- is presented to the user.
	TOOL.GENERAL = load_option_set("general", true)
    PYRO.MAX_FLAMES = TOOL.GENERAL.max_flames.value
    FF.MAX_SIM_POINTS = TOOL.GENERAL.simulation_points.value
	TOOL.BOMB = load_option_set("bomb", true)
    init_pyro(TOOL.BOMB)
	TOOL.ROCKET = load_option_set("rocket", true)
    init_pyro(TOOL.ROCKET)
	TOOL.THROWER = load_option_set("thrower", true)
    init_pyro(TOOL.THROWER)
    all_option_sets = {TOOL.BOMB, TOOL.ROCKET, TOOL.THROWER, TOOL.GENERAL}
end

function init_pyro(tool)
    -- Initialize the tool's pyro and force fields with the parameters set
    -- in the mode option set.
    local pyro = inst_pyro()
    pyro.flames_per_spawn = tool.flames_per_point.value
    pyro.flame_light_intensity = tool.flame_light_intensity.value
    pyro.flame_dead_force = tool.flame_dead_force.value
    pyro.max_smoke_size = tool.max_smoke_size.value
    pyro.min_smoke_size = tool.min_smoke_size.value
    pyro.smoke_life = tool.smoke_life.value
    pyro.smoke_amount_n = tool.smoke_amount.value
    pyro.impulse_scale = tool.impulse_scale.value
    pyro.impulse_radius = tool.impulse_radius.value
    pyro.fire_ignition_radius = tool.fire_ignition_radius.value
    pyro.fire_density = tool.fire_density.value
    pyro.contact_damage_scale = tool.contact_damage_scale.value
    pyro.max_player_hurt = tool.max_player_hurt.value
    pyro.rainbow_mode = tool.rainbow_mode.value
    pyro.color_cool = tool.flame_color_cool.value
    pyro.color_hot = tool.flame_color_hot.value
    pyro.ff.resolution = tool.field_resolution.value
    pyro.ff.meta_resolution = tool.meta_resolution.value
    pyro.ff.f_max = tool.f_max.value
    pyro.ff.f_dead = tool.f_dead.value
    pyro.ff.bias = Vec(0, tool.heat_rise.value, 0)
    pyro.ff.prop_split = tool.prop_split.value
    -- pyro.ff.prop_angle = tool.prop_angle.value
    pyro.ff.extend_scale = tool.extend_scale.value
    pyro.ff.trans_gain = tool.trans_gain.value
    pyro.ff.bias_gain = tool.bias_gain.value
    tool.pyro = pyro
end

function init_shock_field()
    -- special parameters that make a shock wave field work
    local pyro = inst_pyro()
    pyro.flames_per_spawn = 5
    pyro.flame_light_intensity = 0
    pyro.flame_dead_force = 0
    pyro.max_smoke_size = 1
    pyro.min_smoke_size = 1
    pyro.smoke_life = 0
    pyro.smoke_amount_n = 0
    pyro.flame_puff_life = 0.5
    pyro.flame_jitter = 2
    pyro.flame_tile = 0
    pyro.flame_opacity = 1s
    pyro.impulse_scale = 1
    pyro.impulse_radius = 10
    pyro.fire_ignition_radius = 0
    pyro.fire_density = 0
    pyro.contact_damage_scale = 0.1
    pyro.max_player_hurt = 0.01
    pyro.rainbow_mode = false
    pyro.ff.resolution = 2.5
    pyro.ff.meta_resolution = 3
    pyro.ff.f_max = 1000
    pyro.ff.f_dead = 1
    pyro.ff.bias = Vec()
    pyro.ff.prop_split = 4
    -- pyro.ff.prop_angle = 55
    pyro.extend_scale = 3
    pyro.ff.dir_jitter = 10
    pyro.ff.trans_gain = 0.8
    pyro.ff.bias_gain = 0
    SHOCK_FIELD = pyro
end