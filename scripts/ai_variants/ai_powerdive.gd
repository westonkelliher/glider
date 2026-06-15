extends AiBase
## Power dive striker.
##
## Speed comes from POTENTIAL ENERGY (altitude). A low, slow glider hits weakly,
## and base shots drift wide. This variant trades a little setup time for a
## committed, high-energy strike: when it is NOT already lined up for a strike
## it CLIMBS to a high waypoint above/behind the ball (banking altitude/energy),
## then DIVES through the ball toward our goal for a fast, flat, centred hit.
##
## Anti-stall: climbing is capped (by a ceiling and by a commit timer) so it
## never climbs forever; once high enough OR lined up it commits to the dive.

## How much higher than the ball we try to get before diving (energy bank).
const CLIMB_OVER_BALL := 40.0
## Don't climb past this world altitude (avoid runaway / ceiling stalls).
const CLIMB_CEILING := 95.0
## Altitude above the ball that counts as "energy banked, go dive".
const ENERGY_READY := 28.0
## Below this altitude we're too low/slow to strike well -> prefer climbing.
const LOW_ALT := 25.0
## Behindness needed to treat the approach as a committed strike.
const COMMIT_BEHIND := 0.5

## Frames spent climbing on the current attempt; forces a commit if it drags on.
var _climb_frames: int = 0
## Max frames to climb before committing regardless (keeps it from stalling).
const CLIMB_FRAMES_CAP: int = 240


func _is_committed(ctx: Dictionary) -> bool:
	var behindness: float = ctx["behindness"]
	var dist: float = ctx["dist"]
	return behindness > COMMIT_BEHIND and dist < 34.0


## Should we still be climbing to bank energy?
func _wants_climb(glider: Glider, ctx: Dictionary) -> bool:
	if _is_committed(ctx):
		return false
	var gp: Vector3 = ctx["gp"]
	var bp: Vector3 = ctx["bp"]
	var dist: float = ctx["dist"]
	var ball_vel: Vector3 = ctx["ball_vel"]
	# Never climb away from a close ball, especially a stalled / wall-pinned one:
	# go dislodge it instead of orbiting above it forever.
	if dist < 22.0:
		return false
	if ball_vel.length() < 3.0 and dist < 45.0:
		return false
	if gp.y >= CLIMB_CEILING:
		return false
	if _climb_frames >= CLIMB_FRAMES_CAP:
		return false  # been climbing too long: commit instead
	# Enough energy banked already (well above the ball)? then stop climbing.
	if gp.y - bp.y >= ENERGY_READY and gp.y > LOW_ALT:
		return false
	# Climb when we're low, or simply haven't banked enough height yet.
	return gp.y < LOW_ALT or gp.y - bp.y < ENERGY_READY


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	var committed: bool = _is_committed(ctx)
	if _wants_climb(glider, ctx):
		_climb_frames += 1
		# High waypoint above & slightly behind the ball: gain altitude/energy
		# while drifting toward the shooting line so the dive is already aligned.
		var target_y: float = minf(bp.y + CLIMB_OVER_BALL, CLIMB_CEILING)
		var aim: Vector3 = bp - shoot_dir * 8.0
		aim.y = target_y
		return aim
	# Not climbing: strike. Reset the climb timer for the next attempt.
	_climb_frames = 0
	if committed:
		# Dive THROUGH the ball toward goal, aiming low/flat so the high-energy
		# nose drives the ball forward and centred rather than lofting it wide.
		var aim: Vector3 = bp + shoot_dir * 26.0
		aim.y = bp.y - 6.0
		return aim
	# Have energy but not yet lined up: swoop down behind the ball to set up,
	# converting altitude into the speed that will carry the strike.
	var setup: Vector3 = bp - shoot_dir * 12.0
	setup.y = bp.y - 4.0
	return setup


func _decide_boost(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return false
	var facing: float = ctx["nose"].dot(desired.normalized())
	if facing <= 0.2:
		return false  # don't waste boost when not pointed at the target
	# Boost hard while climbing (banks pot_height) ...
	if _wants_climb(glider, ctx):
		return true
	# ... and during the committed dive, to maximise strike speed.
	if _is_committed(ctx):
		return true
	# Otherwise fall back to the base "speed up if slow/far" logic.
	return super._decide_boost(glider, ball, ctx, aim)
