extends AiBase
## GENERALIZATION BRAIN — a single parametric striker that subsumes the variant
## zoo (base/center/goalside/defense/prediction/powerdive/stallrec/...). Nothing
## here is a behaviour switch; instead EVERY value the AI produces — both the
## high-level decision/priority scalars and the low-level control inputs — is
## computed the same way:
##
##     value = deterministic_programmatic_component  +  ( weights · features )
##
## A hand-coded baseline keeps it flying sanely with all weights at zero; the
## weight rows are the (large) fine-tuning surface layered on top. No single
## weight equals a control input — each output is a linear combination of many
## tuned coefficients against shared geometric features.
##
## FEATURES are raw geometry/physics in the glider's LOCAL frame (so steering
## stays orientation-relative): direction & distance to ball / own goal / other
## goal / opponent, ball velocity, own speed/altitude/energy, alignment, etc.
## TWO matrices: Tier-1 (decisions) reads features; Tier-2 (controls) reads
## features PLUS the Tier-1 decisions, so priorities modulate the ailerons.

const TWO_GOAL_Z := 205.0   # |z| of either goal (own goal mirrors target_goal.z)

# Scales that map raw world quantities into a roughly [-1,1] feature range so
# every weight is comparable in magnitude regardless of the unit it multiplies.
const POS_SCALE := 1.0 / 50.0
const VEL_SCALE := 1.0 / 20.0


# ---------------------------------------------------------------------------
# TIER-1 weight rows: decision/priority scalars. Each row is {feature: weight};
# the value is its deterministic baseline + Σ weight·feature, clamped to [0,1].
# ---------------------------------------------------------------------------
var w_attack := {}
var w_commit := {}
var w_center := {}
var w_defend := {}
var w_climb := {}
var w_recover := {}
var w_intercept := {}

# ---------------------------------------------------------------------------
# TIER-2 weight rows: low-level controls. Inputs include the Tier-1 decisions
# (keys prefixed "d_"). Pitch/roll/yaw clamp to [-1,1]; boost/brake threshold at
# 0.5; slow clamps to [0,1].
# ---------------------------------------------------------------------------
var w_pitch := {}
var w_roll  := {}
var w_yaw   := {}
var w_boost := {}
var w_slow  := {}
var w_brake := {}


## Optionally load the whole weight set from a JSON file named by the
## BRAIN_WEIGHTS env var (the evolutionary driver writes one genome per file).
## JSON shape: {"w_pitch": {"feature": weight, ...}, ...}. Missing rows/features
## simply stay at their built-in default (0), so partial genomes are fine.
## The evolutionary driver overrides this per-candidate via BRAIN_WEIGHTS; in
## normal play (F5) we fall back to the committed champion next to this script.
const DEFAULT_WEIGHTS := "res://scripts/ai_variants/ai_brain_weights.json"
const ROWS := ["w_attack", "w_commit", "w_center", "w_defend", "w_climb",
	"w_recover", "w_intercept", "w_pitch", "w_roll", "w_yaw", "w_boost",
	"w_slow", "w_brake"]


func _init() -> void:
	var path := OS.get_environment("BRAIN_WEIGHTS")
	if path == "" and FileAccess.file_exists(DEFAULT_WEIGHTS):
		path = DEFAULT_WEIGHTS
	if path == "" or not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY:
		apply_weights(data)


## Replace the whole weight set from a parsed genome dict (authoritative: rows
## absent from `data` reset to empty). Lets the batch harness re-weight one
## long-lived brain instance per candidate without restarting the engine.
func apply_weights(data: Dictionary) -> void:
	for row_name: String in ROWS:
		set(row_name, {} if not data.has(row_name) else data[row_name])


func sample(glider: Glider, _scheme: int) -> GliderControls:
	var ctl := GliderControls.new()
	var ball: Node3D = glider.get_tree().get_first_node_in_group("ball")
	if ball == null:
		return ctl
	var ctx: Dictionary = _context(glider, ball)

	var feats: Dictionary = _features(glider, ball, ctx)
	var dec: Dictionary = _decisions(feats)
	# Decisions become extra inputs to the control matrix.
	for k: String in dec:
		feats["d_" + k] = dec[k]

	# Deterministic aim: a priority-weighted blend of the candidate waypoints the
	# old variants each hard-coded. The Tier-1 decisions choose the mix.
	var aim: Vector3 = _aim(glider, ctx, dec)
	if aim_noise > 0.0:
		aim += Vector3(rng.randfn(0.0, aim_noise), rng.randfn(0.0, aim_noise), rng.randfn(0.0, aim_noise))

	# Steering baseline (same mapping the base striker uses), then add the
	# weighted fine-tuning layer and re-fold geometry features for context.
	var desired: Vector3 = aim - glider.global_position
	var steer: Vector3 = _steer(glider, aim)
	var turn_n: float = clampf(desired.normalized().angle_to(ctx["nose"]) / PI, 0.0, 1.0)
	feats["turn_n"] = turn_n

	ctl.targets = Vector3(
		clampf(_combine(steer.x, w_pitch, feats), -1.0, 1.0),
		clampf(_combine(steer.y, w_roll, feats), -1.0, 1.0),
		clampf(_combine(steer.z, w_yaw, feats), -1.0, 1.0))

	var facing: float = ctx["nose"].dot(desired.normalized()) if desired.length() > 0.01 else 0.0
	var boost_det: float = 0.0
	if facing > 0.2 and (ctx["speed"] < 26.0 or desired.length() > 40.0):
		boost_det = 0.6
	ctl.boost = _combine(boost_det, w_boost, feats) > 0.5 and facing > 0.1
	ctl.braked = _combine(0.0, w_brake, feats) > 0.5
	ctl.slow = clampf(_combine(0.0, w_slow, feats), 0.0, 1.0)
	return ctl


## value = deterministic baseline + Σ weight·feature.
func _combine(det: float, row: Dictionary, feats: Dictionary) -> float:
	var v: float = det
	for k: String in row:
		v += float(row[k]) * float(feats.get(k, 0.0))
	return v


func _own_goal(glider: Glider) -> Vector3:
	return Vector3(0.0, 15.0, -glider.target_goal.z)


func _norm(v: Vector3) -> Vector3:
	return v.normalized() if v.length() > 0.001 else Vector3.ZERO


# ---------------------------------------------------------------------------
# Feature vector: raw geometry/physics, mostly in the glider's local frame.
# ---------------------------------------------------------------------------
func _features(glider: Glider, _ball: Node3D, ctx: Dictionary) -> Dictionary:
	var gp: Vector3 = ctx["gp"]
	var bp: Vector3 = ctx["bp"]
	var binv: Basis = glider.global_transform.basis.inverse()
	var own_goal: Vector3 = _own_goal(glider)
	var opp: Node = ctx["opponent"]
	var to_own_z: float = signf(own_goal.z)

	var to_ball_l: Vector3 = (binv * (bp - gp))
	var to_owng_l: Vector3 = _norm(binv * (own_goal - gp))
	var to_othg_l: Vector3 = _norm(binv * (glider.target_goal - gp))
	var to_opp_l: Vector3 = _norm(binv * ((opp.global_position - gp) if opp else Vector3.ZERO))
	var ball_v_l: Vector3 = binv * ctx["ball_vel"]

	return {
		"bias": 1.0,
		# direction & distance to ball (local)
		"to_ball_x": _norm(to_ball_l).x, "to_ball_y": _norm(to_ball_l).y, "to_ball_z": _norm(to_ball_l).z,
		"dist_n": clampf(ctx["dist"] * POS_SCALE, 0.0, 2.0),
		# direction to own / other goal (local)
		"to_own_goal_x": to_owng_l.x, "to_own_goal_y": to_owng_l.y, "to_own_goal_z": to_owng_l.z,
		"to_other_goal_x": to_othg_l.x, "to_other_goal_y": to_othg_l.y, "to_other_goal_z": to_othg_l.z,
		# direction to opponent (local)
		"to_opp_x": to_opp_l.x, "to_opp_y": to_opp_l.y, "to_opp_z": to_opp_l.z,
		# ball motion (local)
		"ball_vel_x": ball_v_l.x * VEL_SCALE, "ball_vel_y": ball_v_l.y * VEL_SCALE, "ball_vel_z": ball_v_l.z * VEL_SCALE,
		"ball_speed_n": clampf(ctx["ball_vel"].length() * VEL_SCALE, 0.0, 2.0),
		# scalars
		"behind": clampf(ctx["behindness"], -1.0, 1.0),
		"near": smoothstep(40.0, 12.0, ctx["dist"]),
		"align": clampf(ctx["nose"].dot(_norm(glider.velocity)), -1.0, 1.0),
		"speed_n": clampf(ctx["speed"] * VEL_SCALE, 0.0, 2.0),
		"alt_n": clampf(gp.y * POS_SCALE, 0.0, 2.0),
		"energy_n": clampf((gp.y - bp.y) * POS_SCALE, -2.0, 2.0),
		"ball_wide": clampf(absf(bp.x) / 40.0, 0.0, 2.0),
		"ball_depth": clampf(bp.z * to_own_z * POS_SCALE, -2.0, 2.0),  # >0: ball in our half
		"ball_closing": clampf(ctx["ball_vel"].z * to_own_z * VEL_SCALE, -2.0, 2.0),
	}


# ---------------------------------------------------------------------------
# Tier-1 decisions: det baseline + weighted features, each clamped to [0,1].
# ---------------------------------------------------------------------------
func _decisions(f: Dictionary) -> Dictionary:
	return {
		"attack":    clampf(_combine(0.35, w_attack, f), 0.0, 1.0),
		"commit":    clampf(_combine(0.0, w_commit, f), 0.0, 1.0),
		"center":    clampf(_combine(0.0, w_center, f), 0.0, 1.0),
		"defend":    clampf(_combine(-0.2, w_defend, f), 0.0, 1.0),
		"climb":     clampf(_combine(0.0, w_climb, f), 0.0, 1.0),
		"recover":   clampf(_combine(-0.1, w_recover, f), 0.0, 1.0),
		"intercept": clampf(_combine(0.0, w_intercept, f), 0.0, 1.0),
	}


# ---------------------------------------------------------------------------
# Deterministic aim: blend candidate waypoints (one per generalized pattern) by
# the Tier-1 priorities. This is the programmatic component the steer baseline
# reads; the Tier-2 weights fine-tune the resulting ailerons on top.
# ---------------------------------------------------------------------------
func _aim(glider: Glider, ctx: Dictionary, dec: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	var ball_vel: Vector3 = ctx["ball_vel"]
	var own_goal: Vector3 = _own_goal(glider)

	# Predicted ball position (intercept lead), used by the attacking waypoints.
	var t: float = clampf(ctx["dist"] / maxf(ctx["speed"], 1.0), 0.0, 0.8) * 0.4 * float(dec["intercept"])
	var pred: Vector3 = bp + ball_vel * t

	# Candidate waypoints (mirrors of the old variants' aims).
	var behind: Vector3 = pred - shoot_dir * 12.0; behind.y = pred.y - 1.0
	var commit: Vector3 = pred + shoot_dir * 25.0; commit.y = pred.y
	var to_center: Vector3 = _norm(Vector3(-bp.x, 0.0, ctx["goal"].z - bp.z))
	if to_center == Vector3.ZERO:
		to_center = shoot_dir
	var center: Vector3 = pred + to_center * 26.0; center.y = pred.y
	var clear_dir: Vector3 = _norm(Vector3(own_goal.x - bp.x, 0.0, own_goal.z - bp.z))
	var defend: Vector3 = bp - clear_dir * 14.0; defend.y = bp.y - 1.0   # stage goal-side, punt away
	var climb: Vector3 = bp - shoot_dir * 8.0; climb.y = bp.y + 40.0
	var recover: Vector3 = behind; recover.y = maxf(behind.y, ctx["gp"].y + 28.0)

	# Priority-weighted blend (+ a small always-on attack term so there is always
	# a target). Weights sum in the denominator -> a true convex combination.
	var p_attack: float = float(dec["attack"])
	var p_commit: float = float(dec["commit"])
	var p_center: float = float(dec["center"])
	var p_defend: float = float(dec["defend"])
	var p_climb: float = float(dec["climb"])
	var p_recover: float = float(dec["recover"])
	var total: float = p_attack + p_commit + p_center + p_defend + p_climb + p_recover + 0.001
	return (behind * p_attack + commit * p_commit + center * p_center
		+ defend * p_defend + climb * p_climb + recover * p_recover) / total
