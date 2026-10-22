class_name MoveTuning
extends RefCounted
## Every number that shapes how CHAOS moves, in one place, with units. The player keeps one
## of these (Player.tune); tests and the debug panel read it. Speeds are multiplied by the
## gun's mobility (Player.mobility) where it says "× mobility".
##
## The model: the player's velocity is the only truth. States (ground, air, slide, wall run)
## never overwrite it with a fixed speed; they apply accelerations, friction and drag to it,
## and each state has its own speed limit:
##   ground   friction pulls you back to run/sprint speed; faster than that bleeds off
##            linearly (overspeed_drag), and not at all for land_grace after a fast landing
##   slide    low drag that rises after slide_settle; slopes add gravity; soft cap
##   air      no drag until air_soft_cap; input steers (rotates) the velocity at a rate that
##            falls with speed, pushes you up to air_speed, and brakes when held backwards
##   wall run accelerates toward wallrun_speed, keeps more, bleeds above wallrun_max
## hard_cap is a safety net only: hitting it is logged as a bug in the debug panel.

# --- Ground ---------------------------------------------------------------------------
var gravity := 21.0              # m/s²
var run_speed := 6.4             # m/s × mobility
var sprint_speed := 8.4          # m/s × mobility
var crouch_speed := 3.2          # m/s × mobility
var ground_accel := 11.0         # Quake units: target speed gained per second (×target)
var friction := 7.0              # 1/s (Quake friction)
var stop_speed := 2.5            # m/s: friction acts as if at least this fast
var overspeed_drag := 9.0        # m/s²: above target speed, holding a direction along it
var ground_turn := 300.0         # deg/s: turning while over target speed on the ground
var land_grace := 0.22           # s: no friction after landing faster than sprint speed

# --- Jump and input windows -----------------------------------------------------------
var jump_speed := 7.3            # m/s up × sqrt(mobility)
var slide_jump_mult := 0.94      # slide jumps leave a little lower
var coyote := 0.12               # s: jump still allowed after walking off a ledge
var jump_buffer := 0.15          # s: a jump pressed this early still happens on contact
var crouch_buffer := 0.18        # s: a crouch pressed this early still starts a slide
var terminal_fall := 45.0        # m/s

# --- Air ------------------------------------------------------------------------------
var air_speed := 4.6             # m/s × mobility: input can push you up to this
var air_accel := 10.0            # m/s²
var air_turn := 105.0            # deg/s: steering rate at or below air_turn_ref
var air_turn_ref := 7.0          # m/s: above this the turn rate falls as 1/speed
var air_turn_min := 0.42         # never below this share of air_turn
var air_turn_max_angle := 115.0  # deg: input further back than this brakes instead
var air_brake := 6.0             # m/s²
var air_strafe_gain := 1.5       # m/s²: speed gained while steering (bunny-hop skill)
var air_strafe_cap := 10.5       # m/s × mobility: no strafe gain above this
var air_soft_cap := 17.0         # m/s: above this the excess bleeds
var air_soft_drag := 0.8         # 1/s on the excess
var hard_cap := 32.0             # m/s: safety only

# --- Slide ----------------------------------------------------------------------------
var slide_min := 5.8             # m/s × mobility to start a slide on the ground
var slide_land_min := 5.0        # m/s × mobility to land into a slide
var slide_boost := 3.2           # m/s × mobility, once per slide_cooldown
var slide_boost_fade := 15.0     # m/s: entry speed where the boost has faded to 0
var slide_cooldown := 1.4        # s: between boosts (sliding itself is always allowed)
var slide_decel := 2.0           # m/s²
var slide_friction := 0.22       # 1/s
var slide_settle := 1.0          # s: after this, the slide winds down
var slide_settle_decel := 7.0    # m/s² extra once fully wound down (0.5 s ramp)
var slide_exit := 4.0            # m/s: on flat ground the slide ends below this
var slide_turn := 45.0           # deg/s
var slide_slope := 1.0           # share of gravity along the slope
var slide_downhill_friction := 0.1  # 1/s while going downhill (instead of slide_friction)
var slide_soft_cap := 19.0       # m/s
var slam_pitch := -40.0          # deg: crouch in the air only slams when looking this far down
var slam_min_height := 2.4       # m

# --- Wall run, wall jump, wall kick ---------------------------------------------------
var wallrun_min := 4.5           # m/s along the wall to start
var wallrun_speed := 9.2         # m/s × mobility: the run accelerates toward this
var wallrun_accel := 10.0        # m/s²
var wallrun_max := 16.0          # m/s: above this the excess bleeds
var wallrun_time := 1.75         # s × mobility
var wallrun_gravity := 3.0       # m/s² early in the run
var wallrun_gravity_late := 11.0 # m/s² at the end of the run
var wallrun_min_height := 0.6    # m above the ground
var wallrun_angle := 0.8         # max |direction · wall normal| to start (0 = parallel)
var wall_reach := 0.7            # m past the capsule to catch a wall
var wall_reach_hold := 0.95      # m past the capsule to keep a wall (hysteresis)
var wall_grace := 0.1            # s: losing the wall this briefly doesn't end the run
var wall_release := 0.15         # s: letting go of the input this long ends the run
var wall_coyote := 0.15          # s: wall jump still allowed after leaving a run
var wall_rearm := 1.2            # s: the same wall can be run again after this (or floor/other wall)
var wall_jump_out := 5.6         # m/s × mobility off the wall
var wall_jump_input := 1.8       # m/s extra when the input points away from the wall
var wall_jump_up := 7.0          # m/s × sqrt(mobility)
var wall_jump_keep := 0.95       # share of the speed along the wall kept
var wall_kick_out := 6.4         # m/s × mobility
var wall_kick_up := 7.2          # m/s × sqrt(mobility)
var wall_kick_keep := 0.9
var wall_kicks := 3              # per air time (fewer with heavy guns)

# --- Climb, mantle, dash ------------------------------------------------------------------
var climb_speed := 6.2           # m/s × sqrt(mobility)
var climb_time := 0.6            # s × mobility
var climb_time_marked := 1.15    # s × mobility on marked climb faces
var mantle_max := 2.3            # m
var mantle_time := 0.24          # s
var mantle_exit := 4.5           # m/s × mobility, at least
var mantle_keep := 0.75          # share of the speed you came in with
var dash_speed := 14.0           # m/s × mobility
var dash_time := 0.15            # s
var dash_recharge := 3.2         # s ÷ mobility
