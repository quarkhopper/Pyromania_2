# Options for Pyromania
## Brief introduction to the physics system
The Pyromania engine uses a 3D vector grid, a meta-grid that averages those values on a larger resolution, and a library for controlling fire and physics effects that wraps those vector fields. Vector fields automatically propagate, extend, and cull based on parameters set by the player in the options menu. Operations are staggered somewhat to help with performance. Each subtool (bomb, rocket, and flamethrower) uses its own separate field. 

Certain effects such as the appearance of flames (points of light in smoke particles), and contact damage (holes) are tied directly to the base vector field, while other effects, such as impulse (push) and spawning fires are tied to the meta-field for performance reasons. Flame particles spawn when vector field constraints are met, such as reaching a minimum vector (force) magnitude, while other aspects are tied to the normalized value of the force, such as the magnitude of damage and the color/intensity of flame particles.

PyroField.lua is encapsulated and can be exported with ForceField.lua and Utils.lua to other projects for reuse. Logic related to mod-specific weapons, UI, and settings reside above this level. 

## Suggested settings 
(this will be updated whenever I come across an interesting variation)
### Rocket
#### Gutter
Punches in and rips apart from inside
- Max force per point = 5
- Min force per point = 0.2
- Whole field decay = 0.1
- Field prop decay = 0.2
- Field prop splits = 1
- Angle = 55
- Flame dead force = 0.3
- Field contact damage scale = 0.35
#### Punch through
This type of explosion pushes forward in mostly the direction the rocket was traveling, braking more interior walls in the same direction.
- Max force per point = 10
- Min force per point = 015
- Whole field decay = 0.045
- Field prop decay = 0.18
- Field prop splits = 2
- Angle = 10
- Flame dead force = 0.6
- Field contact damage scale = 0.5
## Options controlling the engine
### General options
#### Max flames to render (max_flames)
Limit on the total number of flame particles (point light in smoke particles) that can be spawned per tool. Above this limit flames will be randomly culled. 
#### Max field points (simulation_points)
Limit on the maximum number of vector field points that can be spawned per tool by the mod. Above this limit field points will be randomly culled.  
#### Visible shock waves (visible_shock_waves)
Turns visibly rendered shock waves on and off. Shock effects will still occur but there won't be an overpressure condensation wave. Turning this off may improve performance. 
### Common tool options
#### Max field force per point (f_max)
The maximum magnitude of a vector in the vector field. The fraction of this maximum is commonly used in calculations throughout the mod. This is the force that is added to the field array when a flame effect is triggered and propagates away from that point. This value, with the decay, dead_force, and flame_dead_force parameters determine the length and intensity of flame effects. 
#### Minimum field force per point (dead_force)
A vector below this magnitude will be culled from the simulation. Setting this higher will result in shorter flame effects.  
#### Whole field decay per tick (decay)
A universal amount subtracted from the magnitude of all vectors in the field per tick. Setting this higher will result in shorter flame effects.
#### Field propagation decay per tick (prop_decay)
The amount of decay applied to a vector point when it propagates force to a child. Setting this higher will result in a less volumous explosion with a thinner front.
#### Field heat rise dir adjust (heat_rise)
An upward-pointing vector of this magnitude is added to the unit vector of all points in the field per tick. Setting this higher will result in flame effects that rise faster. Note: This is in the ForceField module for convenience even though it is technically specific to fire effects.
#### Field propagation splits (point_split)
Force propagates through the vector field by radiating in evenly spaced “spokes” at a set angle (extend_spread) from the parent vector. This setting controls the number of “spokes”. Setting this higher will result in more round, billowy flames. Too low and force will propagate in lines in the field and will generally look strange on larger field resolutions. 
#### Field propagation angle of spread (extend_spread)
As mentioned in point_split above, this setting determines the angle that field propagation splits at. Smaller angles will cause the flames to propagate in more compact jets, and larger angles cause the flames to billow and boil more. Use angles above 30 degrees for flames to effectively “navigate” through confined spaces, such as hallways. 
#### Field resolution (field_resolution)
Game units to vector coordinates. One game unit = 10 voxels, so a field resolution of 0.1 means that each voxel has an individual vector. This effectively sets the scale of flame effects, with larger resolution numbers producing a larger (but more crude looking) effect field. 
#### Metafield resolution (meta_resolution)
Game units to metafield vector coordinates. This value should be higher than the base field resolution for performance reasons. This field is an averaging of base field vectors in a the metafield coordinate frame, producing a smaller field to iterate over when considering certain effects. A larger metafield resolution will result in better performance but some effects, such as impulse (push), fire spawning, and player damage will not match as closely to the actual fire effects. 
#### Flame dead force (flame_dead_force)
Full fire effects will only appear above this vector field magnitude, and when the magnitude falls below this the flames will turn to embers. Setting this higher will result in fewer flame effect (though other effects, such as impulse, fire spawning, and player damage will still continue beyond the extent of the visible flames). This should generally remain close to, if only slightly higher, than the dead_force.
#### Flames spawn per field point (flames_per_point)
The pyro field will spawn this many flame particles per base vector field point, above the flame_dead_force.
#### Flame light intensity (flame_light_intensity)
The light intensity of point lights use in flame particles. Larger values produce brighter flames. This should be thought of as a gain control only - actual flame brightness should be controlled through the flame_color_hot and flame_color_cool. 
#### Hot flame color (flame_color_hot)
The HSV color of a flame when the controlling vector field force is at its maximum and blends towards flame_color_cool linearly as the vector force falls to flame_dead_force.
#### Cool flame color (flame_color_cool)
The HSV color of a flame when the controlling vector field force is at its minimum (flame_dead_force).
#### Rainbow mode (rainbow_mode)
All flames and resulting smoke particles in the pyro field cycle hue values. 
#### Hot smoke particle size (min_smoke_size)
The size of smoke particles when the underlying vector force magnitude is at its maximum. NOTE: calling this “min” assumes that hot flame particles are smaller, but there’s nothing stopping you from setting this larger than max_smoke_size and seeing particles shrink. 
#### Cool smoke particle size (max_smoke_size)
The size of smoke particles when the underlying vector force magnitude is at flame_dead_force.
#### Lifetime of smoke particles (smoke_life)
How long black, lingering smoke particles remain (seconds).
#### Relative smoke per flame (smoke_amount)
The relative amount of smoke to spawn per flame spawn. 0 is no black smoke. 1 is a smoke particle per flame spawn (very smokey). Turn this down if you want less black smoke in your explosions or to increase performance.
#### Impulse (pushing) constant (impulse_const)
A constant multiplied by the normalized metafield vector force magnitude to push something dynamic when it is inside the impulse_radius of a metafield vector point. Setting this higher will push things more when they get near effects. 
#### Impulse (pushing) radius (impulse_radius)
The maximum range of influence from a metafield vector point that will be affected through impulse (pushing). Setting this higher will push entities from longer distances from the effects.
#### Fire ignition radius (fire_ignition_radius)
The radius of effect for spawning native teardown fire. A higher value means that fires can start further from flame effects.  
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
#### Explosion fireball radius (explosion_fireball_radius)
Bomb explosions are seeded with a number of force points that kick off vector field propagation waves. This parameter controls the distance those points are around the explosion point. Setting this number larger will result in a blast that starts instantaneously larger, but will require more points to fill out. Setting it to zero will spawn all seeds from a single point. 
#### Explosion seed points (explosion_seeds)
The number of seed sparks that set up effect propagation. Setting this smaller will result in more uneven explosions. Setting it large than the default will produce a more even fireball at the start of the explosion, but not much practical effect.
Rocket tool options
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
#### Gravity dir adjust (gravity)
How much gravity pulls down on the spray. 








