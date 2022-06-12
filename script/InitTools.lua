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
    pyro.smoke_life = tool.smoke_life.value
    pyro.smoke_amount_n = tool.smoke_amount.value
    pyro.impulse_scale = tool.impulse_scale.value
    pyro.fire_density = tool.fire_density.value
    pyro.contact_damage_scale = tool.contact_damage_scale.value
    pyro.max_player_hurt = tool.max_player_hurt.value
    pyro.rainbow_mode = tool.rainbow_mode.value
    pyro.color_cool = tool.flame_color_cool.value
    pyro.color_hot = tool.flame_color_hot.value

    -- These options are not configurable through the options modal or saved in
    -- the save file. 
    if tool == TOOL.BOMB then 

        tool.explosion_seeds = 100
        tool.explosion_fireball_radius = 0.5

        pyro.fade_threshold = 0.1
        pyro.hot_particle_size = 0.2
        pyro.cool_particle_size = 0.4
        pyro.impulse_radius = 5
        pyro.fire_ignition_radius = 5
        pyro.flame_jitter = 0.5

        pyro.ff.bias = Vec(0, 1, 0)
        pyro.ff.bias_gain = 0.01
        pyro.ff.resolution = 0.5
        pyro.ff.meta_resolution = 2

        pyro.ff.graph.max_force = 10000 
        pyro.ff.graph.hot_transfer = 10
        pyro.ff.graph.cool_transfer = 2
        pyro.ff.graph.hot_prop_split = 2
        pyro.ff.graph.cool_prop_split = 2
        pyro.ff.graph.hot_prop_angle = 20
        pyro.ff.graph.cool_prop_angle = 45
        pyro.ff.graph.hot_extend_scale = 1.5
        pyro.ff.graph.cool_extend_scale = 1.5

    elseif tool == TOOL.ROCKET then 
        tool.explosion_seeds = 50
        tool.explosion_fireball_radius = 0.5

        pyro.fade_threshold = 0.1
        pyro.hot_particle_size = 0.2
        pyro.cool_particle_size = 0.4
        pyro.impulse_radius = 5
        pyro.fire_ignition_radius = 5

        pyro.ff.bias = Vec(0, 1, 0)
        pyro.ff.bias_gain = 0
        pyro.ff.resolution = 0.5
        pyro.ff.meta_resolution = 2

        pyro.ff.graph.max_force = 1000 
        pyro.ff.graph.hot_transfer = 10
        pyro.ff.graph.cool_transfer = 2
        pyro.ff.graph.hot_prop_split = 3
        pyro.ff.graph.cool_prop_split = 1
        pyro.ff.graph.hot_prop_angle = 30
        pyro.ff.graph.cool_prop_angle = 5
        pyro.ff.graph.hot_extend_scale = 1.5
        pyro.ff.graph.cool_extend_scale = 2

    elseif tool == TOOL.THROWER then 
        tool.gravity = 0.01

        pyro.fade_threshold = 0.1
        pyro.hot_particle_size = 0.1
        pyro.cool_particle_size = 0.3
        pyro.impulse_radius = 0.5
        pyro.fire_ignition_radius = 1

        pyro.ff.bias = Vec(0, 1, 0)
        pyro.ff.bias_gain = 0
        pyro.ff.resolution = 0.1
        pyro.ff.meta_resolution = 1

        pyro.ff.graph.max_force = 500 
        pyro.ff.graph.hot_transfer = 0.25
        pyro.ff.graph.cool_transfer = 0.8
        pyro.ff.graph.hot_prop_split = 1
        pyro.ff.graph.cool_prop_split = 5
        pyro.ff.graph.hot_prop_angle = 10
        pyro.ff.graph.cool_prop_angle = 30
        pyro.ff.graph.hot_extend_scale = 2
        pyro.ff.graph.cool_extend_scale = 1
    end

    tool.pyro = pyro
end

function init_shock_field()
    -- special parameters that make a shock wave field work
    local pyro = inst_pyro()
    pyro.flames_per_spawn = 5
    pyro.flame_light_intensity = 0
    pyro.cool_particle_size = 1
    pyro.hot_particle_size = 1
    pyro.smoke_life = 0
    pyro.smoke_amount_n = 0
    pyro.flame_puff_life = 0.5
    pyro.flame_jitter = 2
    pyro.flame_tile = 0
    pyro.flame_opacity = 1
    pyro.impulse_scale = 1
    pyro.impulse_radius = 10
    pyro.fire_ignition_radius = 0
    pyro.fire_density = 0
    pyro.contact_damage_scale = 0.1
    pyro.max_player_hurt = 0.01
    pyro.rainbow_mode = false
    pyro.ff.resolution = 2.5
    pyro.ff.meta_resolution = 3
    pyro.ff.graph.max_force = 10000
    pyro.ff.bias = Vec()
    pyro.ff.bias_gain = 0
    pyro.ff.dir_jitter = 10
    pyro.ff.graph.hot_transfer = 1
    pyro.ff.graph.cool_transfer = 1
    pyro.ff.graph.hot_prop_split = 4
    pyro.ff.graph.cool_prop_split = 4
    pyro.ff.graph.hot_prop_angle = 45
    pyro.ff.graph.cool_prop_angle = 45
    pyro.ff.graph.hot_extend_scale = 2
    pyro.ff.graph.cool_extend_scale = 2
    SHOCK_FIELD = pyro
end