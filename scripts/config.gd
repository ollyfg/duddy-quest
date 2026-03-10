## GameConfig — central home for all gameplay-tuning constants.
## Edit this file to adjust any numeric value without grepping the codebase.
## All constants are grouped by system and documented inline.

class_name GameConfig

# ---------------------------------------------------------------------------
# Grid / movement
# ---------------------------------------------------------------------------

## Size of each grid cell in pixels.  All grid-aligned movement uses this.
const GRID_SIZE: int = 16

# ---------------------------------------------------------------------------
# Melee
# ---------------------------------------------------------------------------

## Distance (px) from the player centre at which the MeleeArea is placed.
const MELEE_RANGE: float = 24.0

## Seconds the MeleeArea stays active (hitbox-on duration) per swing.
const MELEE_ACTIVE_DURATION: float = 0.15

# ---------------------------------------------------------------------------
# Knockback
## Player and NPC knockback speeds are intentionally different:
##   • The player is lighter / more responsive — a lower speed keeps the
##     game feel snappy without flinging the player across the room.
##   • Enemies are heavier — a higher speed gives satisfying hit-stop and
##     creates clear "throw" distance so the player can read their strike.
# ---------------------------------------------------------------------------

## Initial speed (px/s) applied to the player when hit.
const PLAYER_KNOCKBACK_SPEED: float = 300.0

## Initial speed (px/s) applied to an NPC when hit.
const NPC_KNOCKBACK_SPEED: float = 400.0

## Each frame, knockback velocity is reduced by speed × delta × this factor.
## Shared by both player and NPC so decay *feel* is consistent.
const KNOCKBACK_DECAY_MULTIPLIER: float = 6.0

# ---------------------------------------------------------------------------
# Rage AoE
# ---------------------------------------------------------------------------

## Radius (px) of the physics-shape query used for the rage AoE attack.
const RAGE_AOE_RADIUS: float = 64.0

# ---------------------------------------------------------------------------
# NPC wander
# ---------------------------------------------------------------------------

## Probability [0, 1] that a wander tick picks a new direction vs stopping.
const WANDER_PROBABILITY: float = 0.6

## NPC move_speed multiplier applied during wander (keeps wander slower than chase).
const WANDER_SPEED_FACTOR: float = 0.5

# ---------------------------------------------------------------------------
# NPC patrol
# ---------------------------------------------------------------------------

## Distance (px) below which a patrol waypoint is considered reached.
const PATROL_ARRIVAL_THRESHOLD: float = 8.0

# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

## Sentinel camera limit used to allow free camera movement during pan steps.
const UNLIMITED_CAMERA_LIMIT: int = 100000

## Height (viewport-logical pixels) of the mobile on-screen controls overlay.
## Used by mobile_controls.gd and dev_tools.gd to compute the camera offset.
const MOBILE_CONTROLS_HEIGHT: float = 290.0
