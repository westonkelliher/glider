extends AiBase
## Smart-boost striker: keep energy/field-presence high like the base, but
## spend it where it actually buys goals and cut it where it's wasted.
##
## Inherits the base aim/steer/brake/slow; only `_decide_boost` is overridden.
##
## The base boosts whenever (slow OR far) AND nose-dot(aim) > 0.3. That keeps
## speed up (speed == energy == reach + manoeuvrability) but it also (a) burns
## boost mid-turn at 0.3 alignment, flinging the craft off line, and (b) tops
## up when already fast and right on top of the aim.
##
## This variant:
##   * BOOSTS HARD on a committed strike (well behind the ball AND nose tightly
##     on the aim line) for maximum shot power.
##   * Otherwise keeps a base-like "boost when slow or far" floor so we still
##     reach the ball and don't stall — BUT
##   * REFUSES to boost when poorly aligned (mid-turn: turn first, then boost)
##     and when already fast AND close to the aim (energy would be wasted).


func _decide_boost(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var desired: Vector3 = aim - glider.global_position
	var desired_len: float = desired.length()
	if desired_len < 0.001:
		return false
	var aim_dir: Vector3 = desired / desired_len
	var nose: Vector3 = ctx["nose"]
	var facing: float = nose.dot(aim_dir)
	var behindness: float = ctx["behindness"]
	var speed: float = ctx["speed"]

	# 1) COMMITTED STRIKE: lined up behind the ball AND nose tightly on the aim
	# line. This is where energy turns into shot power, so spend it freely — a
	# harder, more committed strike scores from worse angles. (Base backs off
	# here once "fast enough"; we keep punching to load the shot...
	if behindness > 0.5 and facing > 0.78:
		# ...except in the very last instant of contact, when we're already
		# fast and right on the ball: the hit is happening regardless, and more
		# throttle just plows us through/past it. Let momentum do the work.
		return not (speed > 30.0 and desired_len < 10.0)

	# Mid-turn / badly-aligned repositioning: boosting here just flings the
	# craft off the line and wastes energy. Let it turn first, THEN boost.
	if facing < 0.4:
		return false

	# Already fast AND right on top of the aim: extra speed buys nothing and
	# risks overrunning the ball. This is the one spot the base wastes boost.
	if speed > 28.0 and desired_len < 18.0:
		return false

	# Otherwise keep speed (== reach + manoeuvrability + energy to not stall)
	# high whenever slow or far and pointed forward. Facing gate is a touch
	# tighter than base's 0.3 so we don't burn boost while still swinging onto
	# line, but loose enough to maintain the field presence base relies on.
	var slow_or_far: bool = speed < 27.0 or desired_len > 38.0
	return slow_or_far and facing > 0.4
