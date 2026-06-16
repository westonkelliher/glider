extends Node
## Headless SCENARIO harness for fast AI tuning. Instead of playing full games,
## it drops the AI into 10 fixed micro-situations — 5 "shot on goal" and 5
## "goalkeeper" — each repeated `reps` times with +-7% jitter (with an absolute
## floor so centred setups still vary) on ball/glider position AND velocity.
##
## All scenarios run inside ONE headless process (the win: no per-match godot
## startup cost). Jitter is driven by a single seeded RNG in a fixed order, so
## two variants run with the same `seed` see IDENTICAL setups -> fair A/B.
##
## The AI under test always attacks the NORTH (+Z) goal:
##   shot   -> success if it scores in the north goal within `shot_frames`.
##   keep   -> the ball is launched at the SOUTH goal; success if NO south goal
##             is conceded within `keep_frames` (the AI cleared/blocked it).
##
## Run:
##   godot --headless --path . --fixed-fps 60 res://tests/scenarios.tscn -- \
##     variant=hbgs reps=20 seed=1
##
## Args (all optional): variant=<name> reps=<int> seed=<int>
##   shot_frames=<int> keep_frames=<int> noise=<float> verbose=1

const GLIDER := preload("res://scenes/glider_body.tscn")
const BALL := preload("res://ball.tscn")
const ARENA := preload("res://environment/arena.tscn")
const NORTH := Vector3(0.0, 15.0, 205.0)   # blue goal: the AI attacks this
const G_GLIDER := 9.8                       # matches Glider.G (for pot_height)

# Jitter: +-max(FRAC*|base|, floor) per component.
const FRAC := 0.07
const POS_FLOOR := 2.0
const VEL_FLOOR := 1.0

var variant := "hbgs"
var scen_set := "train"   # "train" (default) or "test" (held-out, overfitting check)
var reps := 20
var seed_val := 1
var shot_frames := 600
var keep_frames := 300
var noise := 1.0
var verbose := false

var rng := RandomNumberGenerator.new()
var referee: Node          # arena root carries score_blue / score_orange
var ball: Node3D
var glider: Glider
var scenarios: Array = []
var results: Array = []     # one dict per scenario: {name,kind,succ,reps,fsum,fn}

var si := 0                 # scenario index
var rep := 0                # rep within scenario
var rep_frame := 0
var base_blue := 0
var base_orange := 0
var done := false


func _ready() -> void:
	_parse_args()
	rng.seed = seed_val
	referee = ARENA.instantiate()
	add_child(referee)
	ball = BALL.instantiate()
	ball.scale = Vector3(1.35, 1.35, 1.35)
	add_child(ball)
	glider = GLIDER.instantiate()
	glider.is_ai = true
	glider.ai_variant = variant
	glider.target_goal = NORTH
	add_child(glider)            # _ready() builds glider.controller here
	glider.controller.rng.seed = seed_val * 7919 + 100
	glider.controller.aim_noise = noise
	_build_scenarios()
	_start_scenario()
	print("[scn] start variant=%s reps=%d seed=%d shot_frames=%d keep_frames=%d" % [
		variant, reps, seed_val, shot_frames, keep_frames])


## Each scenario: kind, glider pos + approach speed, ball pos + velocity. The
## glider is oriented to face the (jittered) ball and given velocity along that
## facing at `g_speed`. Shots attack +Z; keeper balls are launched toward -Z.
func _build_scenarios() -> void:
	scenarios = scenario_set(scen_set)


## Shared scenario definitions (also used by the batched GA harness).
## Sets: "train" (diverse binary, drives selection), "test" (held-out binary,
## DISTINCT from train, overfitting check), "basics" (continuous dot-reward,
## phase-1 flight-control curriculum).
static func scenario_set(which: String) -> Array:
	match which:
		"test": return test_scenarios()
		"basics": return basics_scenarios()
		_: return train_scenarios()


## Defaults for the "position" success kind (lined-up-behind-ball check).
const POS_B_THRESH := 0.6   # behindness >= this (1 = perfectly behind the ball)
const POS_D_THRESH := 26.0  # AND distance to ball <= this (world units)


## CONTINUOUS-REWARD curriculum ("basics"). The dot harness ignores `kind` and
## never ends early; it scores `ball_vel . dir(GOAL-ball)` at the end of a fixed
## budget. POINT: teach basic flight + knocking the ball toward the +Z goal from
## a WIDE variety of ball states (central/wide/near/far/low/high; stationary /
## slow-toward / slow-AWAY / lateral) and glider start poses (behind / off to a
## side / low+slow / high). These need not be "scoreable", only diverse striking
## setups. Ball `kind` stays "shot" (harmless: dot mode ignores it).
static func basics_scenarios() -> Array:
	return [
		# central, ball roughly still or drifting goalward — pure "knock it north".
		{"name": "b_central_still", "kind": "shot", "g_pos": Vector3(0, 28, 120),   "g_speed": 20.0, "b_pos": Vector3(0, 26, 150),    "b_vel": Vector3(0, 0, 0)},
		{"name": "b_central_slow",  "kind": "shot", "g_pos": Vector3(0, 28, 115),   "g_speed": 22.0, "b_pos": Vector3(0, 26, 148),    "b_vel": Vector3(0, 0, 3)},
		# ball drifting the WRONG way (toward us) — must turn it around.
		{"name": "b_central_away",  "kind": "shot", "g_pos": Vector3(0, 28, 110),   "g_speed": 20.0, "b_pos": Vector3(0, 26, 140),    "b_vel": Vector3(0, 0, -4)},
		# wide left / right, glider behind.
		{"name": "b_wide_left",     "kind": "shot", "g_pos": Vector3(-40, 28, 120), "g_speed": 22.0, "b_pos": Vector3(-40, 26, 150),  "b_vel": Vector3(0, 0, 0)},
		{"name": "b_wide_right",    "kind": "shot", "g_pos": Vector3(40, 28, 120),  "g_speed": 22.0, "b_pos": Vector3(40, 26, 150),   "b_vel": Vector3(0, 0, 0)},
		# lateral ball drift (cross the ball's path).
		{"name": "b_lateral",       "kind": "shot", "g_pos": Vector3(0, 28, 120),   "g_speed": 22.0, "b_pos": Vector3(-10, 26, 150),  "b_vel": Vector3(8, 0, 0)},
		# near (short range) and far (long range) approaches.
		{"name": "b_near",          "kind": "shot", "g_pos": Vector3(0, 28, 150),   "g_speed": 18.0, "b_pos": Vector3(0, 26, 160),    "b_vel": Vector3(0, 0, 0)},
		{"name": "b_far",           "kind": "shot", "g_pos": Vector3(0, 30, 70),    "g_speed": 26.0, "b_pos": Vector3(0, 26, 140),    "b_vel": Vector3(0, 0, 1)},
		# low + slow (near stall) and high-energy starts — flight-control stress.
		{"name": "b_low_slow",      "kind": "shot", "g_pos": Vector3(0, 12, 120),   "g_speed": 12.0, "b_pos": Vector3(0, 20, 150),    "b_vel": Vector3(0, 0, 0)},
		{"name": "b_high",          "kind": "shot", "g_pos": Vector3(0, 55, 120),   "g_speed": 20.0, "b_pos": Vector3(0, 26, 150),    "b_vel": Vector3(0, 0, 0)},
		# glider off to the side of a central ball (must swing around).
		{"name": "b_side_offset",   "kind": "shot", "g_pos": Vector3(-35, 28, 150), "g_speed": 22.0, "b_pos": Vector3(0, 26, 150),    "b_vel": Vector3(0, 0, 0)},
		# diagonal wide + drifting goalward.
		{"name": "b_diag_drift",    "kind": "shot", "g_pos": Vector3(30, 30, 110),  "g_speed": 22.0, "b_pos": Vector3(20, 26, 150),   "b_vel": Vector3(-3, 0, 2)},
	]


## DIVERSE BINARY TRAIN set (drives selection). Spans ball positions (own half,
## midfield, attacking third, corners, near walls, near own goal, high/low),
## ball velocities (stationary, slow correct-dir, slow WRONG-dir w/ time to
## recover, fast incoming, lateral, popped-up) and glider start poses (behind,
## goalside/wrong-side, off a side, far, low+slow stall, high-energy).
## Three kinds: "shot" (score north +Z goal), "keep" (deny south -Z goal),
## "position" (reach an advantageous lined-up spot: behindness>=b_thresh AND
## dist<=d_thresh within budget). Difficulty is tuned by SLOWING, not re-angling.
static func train_scenarios() -> Array:
	return [
		# --- SHOTS (drive ball into north/+Z goal, mouth |x|<40) ---
		{"name": "shot_central",    "kind": "shot",     "g_pos": Vector3(0, 28, 130),   "g_speed": 22.0, "b_pos": Vector3(0, 26, 152),    "b_vel": Vector3(0, 0, 2)},
		{"name": "shot_left",       "kind": "shot",     "g_pos": Vector3(-45, 28, 150), "g_speed": 22.0, "b_pos": Vector3(-38, 26, 165),  "b_vel": Vector3(0, 0, 1)},
		{"name": "shot_right",      "kind": "shot",     "g_pos": Vector3(45, 28, 150),  "g_speed": 22.0, "b_pos": Vector3(38, 26, 165),   "b_vel": Vector3(0, 0, 1)},
		{"name": "shot_fastbreak",  "kind": "shot",     "g_pos": Vector3(0, 28, 115),   "g_speed": 30.0, "b_pos": Vector3(0, 26, 150),    "b_vel": Vector3(0, 0, 4)},
		# wrong-side, but SLOW ball so there's plenty of time to recover.
		{"name": "shot_wrongside",  "kind": "shot",     "g_pos": Vector3(0, 28, 120),   "g_speed": 22.0, "b_pos": Vector3(0, 26, 95),     "b_vel": Vector3(0, 0, -2)},
		# corner: ball wide+deep in the attacking third, near the side wall.
		{"name": "shot_corner",     "kind": "shot",     "g_pos": Vector3(55, 28, 150),  "g_speed": 22.0, "b_pos": Vector3(62, 26, 175),   "b_vel": Vector3(0, 0, 0)},
		# popped-up ball (high), glider lower — must climb to it.
		{"name": "shot_popped",     "kind": "shot",     "g_pos": Vector3(0, 24, 120),   "g_speed": 22.0, "b_pos": Vector3(0, 48, 150),    "b_vel": Vector3(0, -2, 1)},
		# --- KEEPS (stop ball reaching south/-Z goal); defender starts goal-side ---
		{"name": "keep_central",    "kind": "keep",     "g_pos": Vector3(0, 28, -170),  "g_speed": 20.0, "b_pos": Vector3(0, 26, -120),   "b_vel": Vector3(0, 0, -18)},
		{"name": "keep_fast",       "kind": "keep",     "g_pos": Vector3(0, 28, -172),  "g_speed": 24.0, "b_pos": Vector3(0, 26, -112),   "b_vel": Vector3(0, 0, -22)},
		{"name": "keep_left",       "kind": "keep",     "g_pos": Vector3(-25, 28, -168),"g_speed": 20.0, "b_pos": Vector3(-35, 26, -120),  "b_vel": Vector3(5, 0, -18)},
		{"name": "keep_right",      "kind": "keep",     "g_pos": Vector3(25, 28, -168), "g_speed": 20.0, "b_pos": Vector3(35, 26, -120),   "b_vel": Vector3(-5, 0, -18)},
		# deep recovery: defender starts at midfield, must chase back.
		{"name": "keep_recover",    "kind": "keep",     "g_pos": Vector3(0, 28, -10),   "g_speed": 30.0, "b_pos": Vector3(0, 26, -120),   "b_vel": Vector3(0, 0, -18)},
		# --- POSITION (reach a TIGHT striking spot behind the ball IN TIME) ---
		# Tight thresholds (behindness>=0.85, close) so merely flying past doesn't
		# count, and a per-scenario `frames` time budget (the difficulty lever:
		# SLOW = more frames, HARD = fewer) so the AI must settle lined-up quickly.
		# ball in midfield, glider must line up behind it toward +Z. (moderate)
		{"name": "pos_midfield",    "kind": "position", "g_pos": Vector3(0, 28, 20),    "g_speed": 22.0, "b_pos": Vector3(0, 26, 70),     "b_vel": Vector3(0, 0, 0),   "b_thresh": 0.85, "d_thresh": 18.0, "frames": 120},
		# glider on the WRONG (goal) side of a slow ball — must swing around. (hard)
		{"name": "pos_wrongside",   "kind": "position", "g_pos": Vector3(0, 28, 180),   "g_speed": 20.0, "b_pos": Vector3(0, 26, 150),    "b_vel": Vector3(0, 0, -2),  "b_thresh": 0.8,  "d_thresh": 20.0, "frames": 160},
		# ball wide left, glider central — get behind it. (moderate)
		{"name": "pos_wide",        "kind": "position", "g_pos": Vector3(0, 28, 110),   "g_speed": 22.0, "b_pos": Vector3(-50, 26, 155),  "b_vel": Vector3(0, 0, 0),   "b_thresh": 0.85, "d_thresh": 18.0, "frames": 150},
		# ball in OWN half (deep), long low-energy transition. (slow/forgiving budget)
		{"name": "pos_ownhalf",     "kind": "position", "g_pos": Vector3(0, 22, -70),   "g_speed": 18.0, "b_pos": Vector3(0, 26, -20),    "b_vel": Vector3(0, 0, 0),   "b_thresh": 0.85, "d_thresh": 18.0, "frames": 240},
	]


## Held-out DIVERSE BINARY TEST set — DISTINCT geometry from train (different
## distances, offsets, angles, ball speeds, and a different mix of the same three
## kinds). Used only to score the final champion -> train-vs-test gap.
static func test_scenarios() -> Array:
	return [
		# --- SHOTS ---
		{"name": "t_shot_far",      "kind": "shot",     "g_pos": Vector3(0, 30, 95),    "g_speed": 24.0, "b_pos": Vector3(0, 26, 140),    "b_vel": Vector3(0, 0, 3)},
		{"name": "t_shot_wideleft", "kind": "shot",     "g_pos": Vector3(-20, 28, 145), "g_speed": 22.0, "b_pos": Vector3(-30, 26, 160),  "b_vel": Vector3(-3, 0, 1)},
		{"name": "t_shot_diag",     "kind": "shot",     "g_pos": Vector3(35, 30, 120),  "g_speed": 24.0, "b_pos": Vector3(15, 26, 158),   "b_vel": Vector3(-2, 0, 2)},
		{"name": "t_shot_high",     "kind": "shot",     "g_pos": Vector3(0, 48, 130),   "g_speed": 20.0, "b_pos": Vector3(0, 26, 158),    "b_vel": Vector3(0, 0, 0)},
		{"name": "t_shot_cross",    "kind": "shot",     "g_pos": Vector3(-30, 28, 148), "g_speed": 26.0, "b_pos": Vector3(20, 26, 160),   "b_vel": Vector3(6, 0, 1)},
		# wrong-side variant: ball slow toward us, glider behind goal line.
		{"name": "t_shot_wrong",    "kind": "shot",     "g_pos": Vector3(15, 28, 135),  "g_speed": 22.0, "b_pos": Vector3(10, 26, 100),   "b_vel": Vector3(0, 0, -3)},
		# --- KEEPS ---
		{"name": "t_keep_slow",     "kind": "keep",     "g_pos": Vector3(0, 28, -175),  "g_speed": 18.0, "b_pos": Vector3(0, 26, -130),  "b_vel": Vector3(0, 0, -14)},
		{"name": "t_keep_vfast",    "kind": "keep",     "g_pos": Vector3(0, 28, -178),  "g_speed": 26.0, "b_pos": Vector3(0, 26, -100),  "b_vel": Vector3(0, 0, -26)},
		{"name": "t_keep_wideL",    "kind": "keep",     "g_pos": Vector3(-30, 28, -165),"g_speed": 22.0, "b_pos": Vector3(-20, 26, -125), "b_vel": Vector3(-8, 0, -17)},
		{"name": "t_keep_wideR",    "kind": "keep",     "g_pos": Vector3(20, 28, -170), "g_speed": 22.0, "b_pos": Vector3(40, 26, -125),  "b_vel": Vector3(-10, 0, -16)},
		{"name": "t_keep_deep",     "kind": "keep",     "g_pos": Vector3(10, 28, -40),  "g_speed": 28.0, "b_pos": Vector3(0, 26, -115),   "b_vel": Vector3(0, 0, -20)},
		# --- POSITION (tight thresholds + time budget; distinct from train) ---
		# ball near the right wall in the attacking third, glider central. (hard)
		{"name": "t_pos_wall",      "kind": "position", "g_pos": Vector3(0, 28, 120),   "g_speed": 22.0, "b_pos": Vector3(60, 26, 168),   "b_vel": Vector3(0, 0, 0),   "b_thresh": 0.85, "d_thresh": 18.0, "frames": 150},
		# ball drifting wrong-way in midfield, glider far behind. (moderate)
		{"name": "t_pos_drift",     "kind": "position", "g_pos": Vector3(0, 28, 0),     "g_speed": 24.0, "b_pos": Vector3(0, 26, 55),     "b_vel": Vector3(0, 0, -3),  "b_thresh": 0.85, "d_thresh": 18.0, "frames": 140},
		# low+slow stall start: line up behind a nearby ball without much energy. (slow)
		{"name": "t_pos_stall",     "kind": "position", "g_pos": Vector3(-22, 14, 120), "g_speed": 12.0, "b_pos": Vector3(-22, 26, 152),  "b_vel": Vector3(0, 0, 0),   "b_thresh": 0.8,  "d_thresh": 20.0, "frames": 200},
	]


func _start_scenario() -> void:
	rep = 0
	results.append({
		"name": scenarios[si]["name"], "kind": scenarios[si]["kind"],
		"succ": 0, "reps": 0, "fsum": 0, "fn": 0,
	})
	_setup_rep()


func _setup_rep() -> void:
	var s: Dictionary = scenarios[si]
	# Place the ball first (jittered), then orient the glider to face it.
	var bpos: Vector3 = _jvec(s["b_pos"], POS_FLOOR)
	var bvel: Vector3 = _jvec(s["b_vel"], VEL_FLOOR)
	ball.global_position = bpos
	ball.velocity = bvel
	ball.last_position = bpos
	ball.last_velocity = bvel

	var gpos: Vector3 = _jvec(s["g_pos"], POS_FLOOR)
	var face: Vector3 = bpos - gpos
	if face.length() < 0.01:
		face = Vector3(0, 0, 1)
	face = face.normalized()
	var gvel: Vector3 = _jvec(face * float(s["g_speed"]), VEL_FLOOR)
	_place_glider(gpos, face, gvel)

	base_blue = referee.score_blue
	base_orange = referee.score_orange
	rep_frame = 0


func _place_glider(pos: Vector3, face: Vector3, vel: Vector3) -> void:
	var t := Transform3D(Basis(), pos).looking_at(pos + face, Vector3.UP)
	t.basis = t.basis.scaled(Vector3(2.5, 2.5, 2.5))
	glider.global_transform = t
	glider.velocity = vel
	# pot_height is the flight model's source of truth for speed; seed it so the
	# craft actually carries `vel`'s speed instead of regenerating its old one.
	glider.pot_height = pos.y + vel.length_squared() / (2.0 * G_GLIDER)
	glider.wing_extension = 1.0
	glider.pitch_v = 0.0
	glider.roll_v = 0.0
	glider.yaw_v = 0.0
	glider.ail_pitch = 0.0
	glider.ail_pitch_target = 0.0
	glider.ail_pitch_speed = 0.0
	glider.ail_roll = 0.0
	glider.ail_roll_target = 0.0
	glider.ail_roll_speed = 0.0
	glider.ail_yaw = 0.0
	glider.ail_yaw_target = 0.0
	glider.ail_yaw_speed = 0.0


func _physics_process(_d: float) -> void:
	if done:
		return
	rep_frame += 1
	var s: Dictionary = scenarios[si]
	var db: int = referee.score_blue - base_blue
	var do_: int = referee.score_orange - base_orange

	var ended := false
	var success := false
	if s["kind"] == "position":
		# Advantageous-position kind: success the moment the glider is lined up
		# behind the ball toward the target (+Z) goal AND close enough.
		var b_thresh: float = float(s.get("b_thresh", POS_B_THRESH))
		var d_thresh: float = float(s.get("d_thresh", POS_D_THRESH))
		var budget: int = int(s.get("frames", shot_frames))
		if _positioned(b_thresh, d_thresh):
			ended = true; success = true
		elif rep_frame >= budget:
			ended = true; success = false
	elif s["kind"] == "shot":
		if db > 0:
			ended = true; success = true
		elif rep_frame >= shot_frames:
			ended = true; success = false
	else:  # keep
		if do_ > 0:
			ended = true; success = false
		elif rep_frame >= keep_frames:
			ended = true; success = true
	if not ended:
		return

	var r: Dictionary = results[si]
	r["reps"] += 1
	if success:
		r["succ"] += 1
		if s["kind"] == "shot":
			r["fsum"] += rep_frame
			r["fn"] += 1
	if verbose:
		print("[dbg] %s rep=%d frame=%d success=%s" % [s["name"], rep, rep_frame, success])

	rep += 1
	if rep < reps:
		_setup_rep()
		return
	# scenario complete
	si += 1
	if si < scenarios.size():
		_start_scenario()
	else:
		_report()
		done = true
		get_tree().quit()


func _report() -> void:
	var shot_rates: Array = []
	var keep_rates: Array = []
	var pos_rates: Array = []
	var all_rates: Array = []
	for r: Dictionary in results:
		var rate: float = (float(r["succ"]) / r["reps"]) if r["reps"] > 0 else 0.0
		var avg_f: float = (float(r["fsum"]) / r["fn"]) if r["fn"] > 0 else -1.0
		all_rates.append(rate)
		if r["kind"] == "shot":
			shot_rates.append(rate)
		elif r["kind"] == "position":
			pos_rates.append(rate)
		else:
			keep_rates.append(rate)
		print("[scn] s=%s kind=%s reps=%d success=%d rate=%.3f avg_frames=%.1f" % [
			r["name"], r["kind"], r["reps"], r["succ"], rate, avg_f])
	print("[scn] SUMMARY variant=%s shots=%.3f keeps=%.3f position=%.3f overall=%.3f" % [
		variant, _mean(shot_rates), _mean(keep_rates), _mean(pos_rates), _mean(all_rates)])


## True if the glider is lined up behind the ball toward the +Z (NORTH) goal and
## within range — same behindness math as ai_base.gd._context (shoot_dir =
## horizontal dir ball->target goal; behindness = from_ball.dot(-shoot_dir)).
func _positioned(b_thresh: float, d_thresh: float) -> bool:
	var bp: Vector3 = ball.global_position
	var gp: Vector3 = glider.global_position
	var ball_flat := Vector3(bp.x, 0.0, bp.z)
	var goal_flat := Vector3(NORTH.x, 0.0, NORTH.z)
	var shoot_dir: Vector3 = (goal_flat - ball_flat).normalized()
	var from_ball: Vector3 = Vector3(gp.x, 0.0, gp.z) - ball_flat
	var behindness: float = -1.0
	if from_ball.length() > 0.1:
		behindness = from_ball.normalized().dot(-shoot_dir)
	return behindness >= b_thresh and gp.distance_to(bp) <= d_thresh


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x: float in a:
		s += x
	return s / a.size()


func _js(base: float, floor_amp: float) -> float:
	var amp: float = maxf(FRAC * absf(base), floor_amp)
	return base + rng.randf_range(-amp, amp)


func _jvec(v: Vector3, floor_amp: float) -> Vector3:
	return Vector3(_js(v.x, floor_amp), _js(v.y, floor_amp), _js(v.z, floor_amp))


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"variant": variant = kv[1]
			"set": scen_set = kv[1]
			"reps": reps = int(kv[1])
			"seed": seed_val = int(kv[1])
			"shot_frames": shot_frames = int(kv[1])
			"keep_frames": keep_frames = int(kv[1])
			"noise": noise = float(kv[1])
			"verbose": verbose = kv[1] == "1"
