extends AiBase
## GENERALIZATION BRAIN — a single parametric striker that subsumes the variant
## zoo (base/center/goalside/defense/prediction/powerdive/stallrec/...). A
## hand-coded DETERMINISTIC baseline keeps it flying sanely on its own; on top of
## that baseline a small 2-layer perceptron (MLP) produces RESIDUAL corrections.
##
##     value = deterministic_programmatic_component  +  mlp_residual
##
## With the MLP weights all zero the residuals are zero, so the brain reproduces
## the pure deterministic baseline exactly — that is the trainer's floor.
##
## NET TOPOLOGY (see genome contract below):
##   IN = 34  ->  hidden H = 12 (tanh)  ->  OUT = 13 (linear)
##   IN  = [27 geometry features] ++ [7 deterministic decision scalars]
##   OUT = [7 decision residuals] ++ [6 control residuals]
##
## FEATURES are raw geometry/physics in the glider's LOCAL frame (so steering
## stays orientation-relative): direction & distance to ball / own goal / other
## goal / opponent, ball velocity, own speed/altitude/energy, alignment, etc.

const TWO_GOAL_Z := 205.0   # |z| of either goal (own goal mirrors target_goal.z)

# Scales that map raw world quantities into a roughly [-1,1] feature range so
# every weight is comparable in magnitude regardless of the unit it multiplies.
const POS_SCALE := 1.0 / 50.0
const VEL_SCALE := 1.0 / 20.0

# ---------------------------------------------------------------------------
# MLP topology.
# ---------------------------------------------------------------------------
const IN_N := 34
const HID_N := 12
const OUT_N := 13

# IN order (34): 27 geometry features (FEATURE_KEYS) then 7 decision scalars
# (DECISION_KEYS). This MUST stay fixed — the genome columns are aligned to it.
const FEATURE_KEYS := [
	"bias",
	"to_ball_x", "to_ball_y", "to_ball_z",
	"dist_n",
	"to_own_goal_x", "to_own_goal_y", "to_own_goal_z",
	"to_other_goal_x", "to_other_goal_y", "to_other_goal_z",
	"to_opp_x", "to_opp_y", "to_opp_z",
	"ball_vel_x", "ball_vel_y", "ball_vel_z",
	"ball_speed_n",
	"behind", "near", "align", "speed_n", "alt_n", "energy_n",
	"ball_wide", "ball_depth", "ball_closing",
]   # 27
# Decision order (also OUT 0..6 residual order).
const DECISION_KEYS := [
	"attack", "commit", "center", "defend", "climb", "recover", "intercept",
]   # 7

# ---------------------------------------------------------------------------
# Net weights: flat PackedFloat32Array, row-major.
#   W1: length IN_N*HID_N, index = h*IN_N + i  (hidden h, input i)
#   b1: length HID_N
#   W2: length HID_N*OUT_N, index = o*HID_N + h  (output o, hidden h)
#   b2: length OUT_N
# All-zero (the default) => zero residuals => deterministic baseline.
# ---------------------------------------------------------------------------
var W1 := PackedFloat32Array()
var b1 := PackedFloat32Array()
var W2 := PackedFloat32Array()
var b2 := PackedFloat32Array()


## Optionally load the whole weight set from a JSON file named by the
## BRAIN_WEIGHTS env var (the evolutionary driver writes one genome per file).
## JSON shape: {"W1":[...], "b1":[...], "W2":[...], "b2":[...]} (flat float
## arrays). Missing or wrong-length arrays are treated as all-zeros, so a
## partial/empty genome simply yields the deterministic baseline.
## The evolutionary driver overrides this per-candidate via BRAIN_WEIGHTS; in
## normal play (F5) we fall back to the committed champion next to this script.
const DEFAULT_WEIGHTS := "res://scripts/ai_variants/ai_brain_weights.json"


func _init() -> void:
	# Start zeroed (deterministic baseline) so a missing/bad genome never crashes.
	apply_weights({})
	var path := OS.get_environment("BRAIN_WEIGHTS")
	if path == "" and FileAccess.file_exists(DEFAULT_WEIGHTS):
		path = DEFAULT_WEIGHTS
	if path == "" or not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY:
		apply_weights(data)


## Replace the whole weight set from a parsed genome dict (AUTHORITATIVE: fully
## replaces prior weights so the batch harness can re-weight one long-lived brain
## per candidate). Missing keys or wrong-length arrays zero-fill to the correct
## length — never crashes on bad input.
func apply_weights(data: Dictionary) -> void:
	W1 = _load_array(data, "W1", IN_N * HID_N)
	b1 = _load_array(data, "b1", HID_N)
	W2 = _load_array(data, "W2", HID_N * OUT_N)
	b2 = _load_array(data, "b2", OUT_N)


## Parse one flat float array of exactly `n` entries from `data[key]`; any
## absent/non-array/short/over-long value yields an all-zero array of length n.
func _load_array(data: Dictionary, key: String, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)   # zero-filled
	if not data.has(key):
		return out
	var src: Variant = data[key]
	if typeof(src) != TYPE_ARRAY:
		return out
	var arr: Array = src
	if arr.size() != n:
		return out   # wrong length => treat as all-zeros
	for i: int in range(n):
		out[i] = float(arr[i])
	return out


## Forward pass: IN(34) -> hidden(HID_N, tanh) -> OUT(13 linear). Returns the 13
## residuals. With zero weights every output is zero.
func _forward(inputs: PackedFloat32Array) -> PackedFloat32Array:
	var hidden := PackedFloat32Array()
	hidden.resize(HID_N)
	for h: int in range(HID_N):
		var acc: float = b1[h]
		var base: int = h * IN_N
		for i: int in range(IN_N):
			acc += W1[base + i] * inputs[i]
		hidden[h] = tanh(acc)
	var out := PackedFloat32Array()
	out.resize(OUT_N)
	for o: int in range(OUT_N):
		var acc2: float = b2[o]
		var base2: int = o * HID_N
		for h2: int in range(HID_N):
			acc2 += W2[base2 + h2] * hidden[h2]
		out[o] = acc2
	return out


func sample(glider: Glider, _scheme: int) -> GliderControls:
	var ctl := GliderControls.new()
	var ball: Node3D = glider.get_tree().get_first_node_in_group("ball")
	if ball == null:
		return ctl
	var ctx: Dictionary = _context(glider, ball)

	# 1) Geometry features (deterministic).
	var feats: Dictionary = _features(glider, ball, ctx)
	# 2) Deterministic decision scalars (no weighted term anymore).
	var dec: Dictionary = _decisions(feats)

	# 3) Build the 34-input MLP vector in the fixed documented order.
	var inputs := PackedFloat32Array()
	inputs.resize(IN_N)
	var idx: int = 0
	for k: String in FEATURE_KEYS:
		inputs[idx] = float(feats.get(k, 0.0))
		idx += 1
	for k: String in DECISION_KEYS:
		inputs[idx] = float(dec.get(k, 0.0))
		idx += 1

	# 4) Forward pass -> 13 residuals.
	var res: PackedFloat32Array = _forward(inputs)

	# 5) Decision residuals (OUT 0..6) added to deterministic decisions, clamped.
	var corrected: Dictionary = {}
	for d: int in range(DECISION_KEYS.size()):
		var name: String = DECISION_KEYS[d]
		corrected[name] = clampf(float(dec[name]) + res[d], 0.0, 1.0)

	# 6) Corrected decisions drive the deterministic aim blend, then steer.
	var aim: Vector3 = _aim(glider, ctx, corrected)
	if aim_noise > 0.0:
		aim += Vector3(rng.randfn(0.0, aim_noise), rng.randfn(0.0, aim_noise), rng.randfn(0.0, aim_noise))

	var desired: Vector3 = aim - glider.global_position
	var steer: Vector3 = _steer(glider, aim)

	# 7) Control residuals (OUT 7..12): pitch, roll, yaw, boost, slow, brake.
	ctl.targets = Vector3(
		clampf(steer.x + res[7], -1.0, 1.0),
		clampf(steer.y + res[8], -1.0, 1.0),
		clampf(steer.z + res[9], -1.0, 1.0))
	# Bias roll toward upright so the craft stops cruising inverted.
	ctl.targets = upright_roll(glider, ctl.targets)

	var facing: float = ctx["nose"].dot(desired.normalized()) if desired.length() > 0.01 else 0.0
	var boost_det: float = 0.0
	if facing > 0.2 and (ctx["speed"] < 26.0 or desired.length() > 40.0):
		boost_det = 0.6
	ctl.boost = (boost_det + res[10]) > 0.5 and facing > 0.1
	ctl.slow = clampf(0.0 + res[11], 0.0, 1.0)
	# ANALOG handbrake: deterministic turn-based baseline + net residual, so the
	# net can shape braking continuously (it could only flip 0/1 before).
	var brake_det: float = _brake_amount(glider, ball, ctx, aim)
	ctl.hand_brake = clampf(brake_det + res[12], 0.0, 1.0)
	return ctl


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
# Tier-1 decisions: DETERMINISTIC baselines, each clamped to [0,1]. The MLP adds
# residuals to these afterward.
# ---------------------------------------------------------------------------
func _decisions(_f: Dictionary) -> Dictionary:
	return {
		"attack":    clampf(0.35, 0.0, 1.0),
		"commit":    clampf(0.0, 0.0, 1.0),
		"center":    clampf(0.0, 0.0, 1.0),
		"defend":    clampf(-0.2, 0.0, 1.0),
		"climb":     clampf(0.0, 0.0, 1.0),
		"recover":   clampf(-0.1, 0.0, 1.0),
		"intercept": clampf(0.0, 0.0, 1.0),
	}


# ---------------------------------------------------------------------------
# Deterministic aim: blend candidate waypoints (one per generalized pattern) by
# the (corrected) Tier-1 priorities.
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
