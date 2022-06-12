# Options for Pyromania
## Brief introduction to the physics system
The Pyromania engine uses a 3D vector grid, a meta-grid that averages those values on a larger resolution, and a library for controlling fire and physics effects that wraps those vector fields. Vector fields automatically propagate, extend, and cull based on parameters set by the player in the options menu. Operations are staggered somewhat to help with performance. Each subtool (bomb, rocket, and flamethrower) uses its own separate field. 

Certain effects such as the appearance of flames (points of light in smoke particles), and contact damage (holes) are tied directly to the base vector field, while other effects, such as impulse (push) and spawning fires are tied to the meta-field for performance reasons. Flame particles spawn when vector field constraints are met, such as reaching a minimum vector (force) magnitude, while other aspects are tied to the normalized value of the force, such as the magnitude of damage and the color/intensity of flame particles.

PyroField.lua is encapsulated and can be exported with ForceField.lua and Utils.lua to other projects for reuse. Logic related to mod-specific weapons, UI, and settings reside above this level. 

## Options controlling the engine
### General options
#### Max flames to render (max_flames)
Limit on the total number of flame particles (point light in smoke particles) that can be spawned per tool. Above this limit flames will be randomly culled. 
#### Max field points (simulation_points)
Limit on the maximum number of vector field points that can be spawned per tool by the mod. Above this limit field points will be randomly culled.  
#### Visible shock waves (visible_shock_waves)
Turns visibly rendered shock waves on and off. Shock effects will still occur but there won't be an overpressure condensation wave. Turning this off may improve performance. 
### Common tool options
#### Flames spawn per field point (flames_per_point)
The pyro field will spawn this many flame particles per base vector field point. Turn this down to help performance.
#### Flame light intensity (flame_light_intensity)
The light intensity of point lights use in flame particles. Larger values produce brighter flames. This should be thought of as a gain control only - actual flame brightness should be controlled through the flame_color_hot and flame_color_cool. 
#### Hot flame color (flame_color_hot)
The HSV color of a flame when the controlling vector field force is at its maximum and blends towards flame_color_cool linearly as the vector force falls to flame_dead_force.
#### Cool flame color (flame_color_cool)
The HSV color of a flame when the controlling vector field force is at its minimum (flame_dead_force).
#### Rainbow mode (rainbow_mode)
All flames and resulting smoke particles in the pyro field cycle hue values. 
#### Lifetime of smoke particles (smoke_life)
How long black, lingering smoke particles remain (seconds).
#### Relative smoke per flame (smoke_amount)
The relative amount of smoke to spawn per flame spawn. 0 is no black smoke added. 1 is an added smoke particle per flame spawn (very smokey). Turn this down if you want less black smoke in your explosions or to increase performance.
#### Impulse (pushing) constant (impulse_const)
A constant multiplied by the normalized metafield vector force magnitude to push something dynamic when it is inside the impulse_radius of a metafield vector point. Setting this higher will push things more when they get near effects. 
#### Fire density (fire_density)
The density of fire particles per game unit. In a 1x1x1 cube, this translates to fire_density^3 attempts to spawn fire. Fires are spawned in a cube of 2 x fire_ignition_radius centered on a metafield point.
#### Field contact damage scale (contact_damage_scale)
When a vector field point propagates into a shape, rather than extending to a new point it logs a “contact” at that location. After all forces are propagated in the field, this list of contacts results in holes being made in material at those contact points. The size of those holes is governed by this:
        value = normalized_forc * contact_damage_scale
        MakeHole(contact.hit_point, value * 10, value * 5, value, true)
Setting this value higher means flames break things more when they touch things. 
#### Maximum player damage per tick (max_player_hurt)
The maximum fraction of a player’s health that can be taken away when they are in range of flame effects. This scales as a fraction of the normalized metafield vector force at that coordinate. Setting this higher will hurt the player more when they are near flame effects. 
### Bomb tool options
#### Maximum radius of random explosions (max_random_radius)
Sets a bounding box for where a random explosion can spawn to a box centered on the player with sides this far from the player.
#### Minimum radius of random explosions (min_random_radius)
The minimum distance from the player that a random explosion can spawn. 
### Rocket options
#### Rate of fire (rate_of_fire)
The pause (in seconds) between when the player can fire rockets. Setting this lower will result in more rapid fire. 
#### Speed (speed)
The speed that a rocket flies. Setting this higher will result in a faster rocket. NOTE: in order for rockets to properly penetrate the outer surface of an object, a minimum speed of 1 should be used. Slower than that and most rocket detonations will occur at the surface of objects. Higher than the default will result in rockets penetrating deeper into them before detonating.
#### Max flight distance (max_dist)
The maximum distance the rocket can travel before it self-destructs.
### Flamethrower tool options
#### Rate of fire (rate_of_fire)
The pause between spray being fired. A higher value will result in small fireball-puffs being emitted instead of a steady stream. Could be interesting… with the right flame settings…
#### Spray velocity (speed)
How fast spray particles fly. Higher values result in faster spray.
#### Max distance (max_dist)
How far spray flies before it stops. 








