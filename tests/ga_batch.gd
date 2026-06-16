extends Node
## BATCHED scenario evaluator for the evolutionary driver. Evaluates a whole
## POPULATION of genomes inside ONE headless process — the brain is re-weighted
## per candidate via apply_weights() rather than relaunching the engine, so a
## generation costs a handful of process starts instead of dozens.
##
## Run:
##   godot --headless --path . --fixed-fps 60 res://tests/ga_batch.tscn -- \
##     manifest=/abs/list.txt set=train reps=12 seeds=1,2 noise=1.0
## `manifest` = a text file with one genome-JSON path per line. Prints, per
## genome, `[ga] idx=<i> success=<n>` (total over all scenarios×reps×seeds).

const GLIDER := preload("res://scenes/glider_body.tscn")
const BALL := preload("res://ball.tscn")
const ARENA := preload("res://environment/arena.tscn")
const Scenarios := preload("res://tests/scenarios.gd")
const NORTH := Vector3(0.0, 15.0, 205.0)
const G_GLIDER := 9.8
const FRAC := 0.07
const POS_FLOOR := 2.0
const VEL_FLOOR := 1.0

var manifest := ""
var scen_set := "train"
var reps := 12
var seeds: Array = [1]
var noise := 1.0
var reward := "success"     # "success" (binary) or "dot" (continuous shaped reward)
var dot_frames := 240       # fixed time budget per rep in "dot" mode

var rng := RandomNumberGenerator.new()
var referee: Node
var ball: Node3D
var glider: Glider
var scenarios: Array = []
var genomes: Array = []      # parsed weight dicts, one per candidate

var gi := 0                  # genome index
var sei := 0                 # seed index
var si := 0                  # scenario index
var rep := 0
var rep_frame := 0
var base_blue := 0
var base_orange := 0
var succ := 0                # successes accumulated for the current genome
var reward_sum := 0.0        # summed dot-reward accumulated for the current genome
var done := false

const POS_B_THRESH := 0.6    # position-kind: behindness >= this
const POS_D_THRESH := 26.0   # position-kind: AND dist to ball <= this


func _ready() -> void:
	_parse_args()
	referee = ARENA.instantiate()
	add_child(referee)
	ball = BALL.instantiate()
	ball.scale = Vector3(1.35, 1.35, 1.35)
	add_child(ball)
	glider = GLIDER.instantiate()
	glider.is_ai = true
	glider.ai_variant = "brain"
	glider.target_goal = NORTH
	add_child(glider)
	glider.controller.aim_noise = noise
	scenarios = Scenarios.scenario_set(scen_set)
	_load_manifest()
	print("[ga] batch genomes=%d set=%s reps=%d seeds=%s reward=%s dot_frames=%d" % [
		genomes.size(), scen_set, reps, str(seeds), reward, dot_frames])
	if genomes.is_empty():
		get_tree().quit()
		return
	_start_genome()


func _load_manifest() -> void:
	var f := FileAccess.open(manifest, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(line))
		genomes.append(data if typeof(data) == TYPE_DICTIONARY else {})


func _start_genome() -> void:
	glider.controller.call("apply_weights", genomes[gi])
	succ = 0
	reward_sum = 0.0
	sei = 0
	_start_seed()


func _start_seed() -> void:
	# Same seed => identical jitter sequence for every genome => fair A/B.
	rng.seed = int(seeds[sei])
	glider.controller.rng.seed = int(seeds[sei]) * 7919 + 100
	si = 0
	rep = 0
	_setup_rep()


func _setup_rep() -> void:
	var s: Dictionary = scenarios[si]
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
	glider.pot_height = pos.y + vel.length_squared() / (2.0 * G_GLIDER)
	glider.wing_extension = 1.0
	glider.ail_pitch = 0.0
	glider.ail_pitch_target = 0.0
	glider.ail_pitch_speed = 0.0
	glider.ail_roll = 0.0
	glider.ail_roll_target = 0.0
	glider.ail_roll_speed = 0.0
	glider.ail_yaw = 0.0
	glider.ail_yaw_target = 0.0
	glider.ail_yaw_speed = 0.0


const SHOT_FRAMES := 600
const KEEP_FRAMES := 300


func _physics_process(_d: float) -> void:
	if done:
		return
	rep_frame += 1
	var s: Dictionary = scenarios[si]
	var db: int = referee.score_blue - base_blue
	var do_: int = referee.score_orange - base_orange

	var ended := false
	var success := false
	if reward == "dot":
		# CONTINUOUS shaped reward: never end early. At the END of a FIXED budget,
		# score how fast the ball is moving toward the target (+Z) goal.
		if rep_frame >= dot_frames:
			ended = true
			var to_goal: Vector3 = NORTH - ball.global_position
			if to_goal.length() < 0.001:
				reward_sum += 0.0
			else:
				reward_sum += ball.velocity.dot(to_goal.normalized())
	elif s["kind"] == "position":
		var b_thresh: float = float(s.get("b_thresh", POS_B_THRESH))
		var d_thresh: float = float(s.get("d_thresh", POS_D_THRESH))
		var budget: int = int(s.get("frames", SHOT_FRAMES))
		if _positioned(b_thresh, d_thresh):
			ended = true; success = true
		elif rep_frame >= budget:
			ended = true
	elif s["kind"] == "shot":
		if db > 0:
			ended = true; success = true
		elif rep_frame >= SHOT_FRAMES:
			ended = true
	else:
		if do_ > 0:
			ended = true
		elif rep_frame >= KEEP_FRAMES:
			ended = true; success = true
	if not ended:
		return
	if success:
		succ += 1

	# Advance rep -> scenario -> seed -> genome.
	rep += 1
	if rep < reps:
		_setup_rep()
		return
	si += 1
	if si < scenarios.size():
		rep = 0
		_setup_rep()
		return
	sei += 1
	if sei < seeds.size():
		_start_seed()
		return
	if reward == "dot":
		print("[ga] idx=%d reward=%.3f" % [gi, reward_sum])
	else:
		print("[ga] idx=%d success=%d" % [gi, succ])
	gi += 1
	if gi < genomes.size():
		_start_genome()
		return
	done = true
	get_tree().quit()


## position-kind success: glider lined up behind the ball toward the +Z (NORTH)
## goal and within range. Same behindness math as ai_base.gd._context.
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
			"manifest": manifest = kv[1]
			"set": scen_set = kv[1]
			"reps": reps = int(kv[1])
			"noise": noise = float(kv[1])
			"reward": reward = kv[1]
			"dot_frames": dot_frames = int(kv[1])
			"seeds":
				seeds = []
				for s: String in kv[1].split(","):
					seeds.append(int(s))
