extends AiBase
## Stall recovery striker. Speed is bought with altitude (potential energy); a
## glider that is both LOW and SLOW stalls and flails uselessly near the floor.
## Detect that state and climb out: aim UP and forward while boosting to trade
## thrust for altitude, then hand control back to the base striker once enough
## speed/altitude is recovered. Hysteresis (`_recovering`) prevents per-frame
## flip-flop between the two regimes.

## True while actively climbing out of a stall.
var _recovering: bool = false

## Enter recovery only on a GENUINE stall: pinned near the floor AND nearly
## stopped (so we don't yank the craft off the ball during normal low passes).
const STALL_Y: float = 6.0      # altitude (world y) below which we're "low"
const STALL_SPEED: float = 8.0  # speed below which we lack the energy to climb
## Exit as soon as we've regained a little energy or altitude (hysteresis gap
## vs entry) so recovery is a brief nudge, not a long detour out of play.
const SAFE_Y: float = 14.0
const SAFE_SPEED: float = 15.0
## How far above us to aim the climb waypoint (modest — just unstick, then play).
const CLIMB_HEIGHT: float = 28.0


func _update_recovery(ctx: Dictionary) -> void:
	var gp: Vector3 = ctx["gp"]
	var speed: float = ctx["speed"]
	if _recovering:
		# Stay in recovery until we've clearly regained energy or altitude.
		if speed > SAFE_SPEED or gp.y > SAFE_Y:
			_recovering = false
	else:
		if gp.y < STALL_Y and speed < STALL_SPEED:
			_recovering = true


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	_update_recovery(ctx)
	var base_aim: Vector3 = super._compute_aim(glider, ball, ctx)
	if not _recovering:
		return base_aim
	# Climb out: keep the base striker's HORIZONTAL target (so we stay on the
	# play) but lift the aim point UP so steering pitches the nose skyward to
	# convert the boost we add below into altitude/potential energy.
	var gp: Vector3 = ctx["gp"]
	base_aim.y = maxf(base_aim.y, gp.y + CLIMB_HEIGHT)
	return base_aim


func _decide_boost(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	# Boost hard during recovery to convert thrust into the altitude/energy we lack.
	if _recovering:
		return true
	return super._decide_boost(glider, ball, ctx, aim)
