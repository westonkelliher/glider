extends AiBase
## Handbrake striker. Uses the HANDBRAKE (air-friction cut -> sharp pivot) to
## snap the nose around when badly misaligned at speed, and the analog slow to
## bleed energy when arriving at the ball poorly lined up (about to overshoot),
## so it re-sets a clean strike instead of flying a wide arc. Aim/boost = base.


## True when the craft is moving fast but its nose points well off where it
## wants to go: handbrake-pivot toward the aim. False once roughly aligned.
func _decide_brake(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var speed: float = ctx["speed"]
	if speed < 15.0:
		return false  # too slow: braking would just stall us
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return false
	var facing: float = ctx["nose"].dot(desired.normalized())
	# Small jittered threshold (~0.3) keeps play stochastic.
	var threshold: float = 0.3 + rng.randf_range(-0.05, 0.05)
	return facing < threshold


## Positive decel when CLOSE to the ball but poorly lined up to shoot: shed
## speed so we don't blow past, then re-set behind the ball. 0 otherwise.
func _decide_slow(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	var dist: float = ctx["dist"]
	var behindness: float = ctx["behindness"]
	var speed: float = ctx["speed"]
	# Only meaningful when we're near the ball and carrying real speed.
	if dist > 16.0 or speed < 12.0:
		return 0.0
	# behindness ~1 means well lined up behind the ball to shoot; low/negative
	# means we're coming in from a bad angle and likely to overshoot.
	if behindness > 0.5:
		return 0.0
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return 0.0
	var facing: float = ctx["nose"].dot(desired.normalized())
	if facing > 0.6:
		return 0.0  # already pointed where we want; no need to bleed speed
	var amount: float = 0.6 + rng.randf_range(-0.15, 0.15)
	return clampf(amount, 0.0, 1.0)
