extends Node
## Headless AI-vs-AI match harness.
##
## Spawns an arena, a ball, and two AI gliders attacking opposite goals, then
## plays for a fixed number of physics frames, re-kicking-off (with randomness)
## after every goal. Prints a machine-parseable TALLY at the end.
##
## Run:
##   godot --headless --fixed-fps 60 res://tests/match.tscn -- \
##     blue=prediction orange=base seed=1 frames=9000 goals=12 noise=1.5
##
## Args (all optional): blue=<variant> orange=<variant> seed=<int>
##   frames=<int> goals=<int> noise=<float> verbose=1
##
## "blue" attacks the NORTH/blue goal (+Z); its points = arena.score_blue.
## "orange" attacks the SOUTH/orange goal (-Z); its points = arena.score_orange.

const GLIDER := preload("res://scenes/glider_body.tscn")
const BALL := preload("res://ball.tscn")
const ARENA := preload("res://environment/arena.tscn")
const BLUE_GOAL := Vector3(0.0, 15.0, 205.0)
const ORANGE_GOAL := Vector3(0.0, 15.0, -205.0)

var blue_variant := "base"
var orange_variant := "base"
var seed_val := 1
var max_frames := 9000
var max_goals := 12
var noise := 1.5
var verbose := false

var frame := 0
var last_total := 0
var rng := RandomNumberGenerator.new()
var arena: Node
var ball: Node3D
var gliders: Array = []


func _ready() -> void:
	_parse_args()
	rng.seed = seed_val
	arena = ARENA.instantiate()
	add_child(arena)
	ball = BALL.instantiate()
	ball.scale = Vector3(1.35, 1.35, 1.35)
	add_child(ball)
	# Blue attacker: south end, nose facing +Z (180° yaw, scale 2.5).
	gliders.append(_spawn_ai(blue_variant, BLUE_GOAL,
		Transform3D(Vector3(-2.5, 0, 0), Vector3(0, 2.5, 0), Vector3(0, 0, -2.5), Vector3(0, 50, -60)), 100))
	# Orange attacker: north end, nose facing -Z (identity, scale 2.5).
	gliders.append(_spawn_ai(orange_variant, ORANGE_GOAL,
		Transform3D(Vector3(2.5, 0, 0), Vector3(0, 2.5, 0), Vector3(0, 0, 2.5), Vector3(0, 50, 60)), 200))
	_kickoff()
	print("[match] start blue=%s orange=%s seed=%d frames=%d goals=%d noise=%.2f" % [
		blue_variant, orange_variant, seed_val, max_frames, max_goals, noise])


func _spawn_ai(variant: String, goal: Vector3, xform: Transform3D, seed_off: int) -> Node:
	var g: Node = GLIDER.instantiate()
	g.is_ai = true
	g.ai_variant = variant
	g.target_goal = goal
	g.transform = xform
	add_child(g)
	# Per-glider seed + always-on aim noise so play is stochastic.
	g.controller.rng.seed = seed_val * 7919 + seed_off
	g.controller.aim_noise = noise
	return g


func _kickoff() -> void:
	for g: Node in gliders:
		g.reset_to_spawn()
	ball.global_position = Vector3(
		rng.randf_range(-50.0, 50.0), rng.randf_range(15.0, 40.0), rng.randf_range(-40.0, 40.0))
	ball.velocity = Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-12.0, 12.0))


func _physics_process(_d: float) -> void:
	frame += 1
	if verbose and frame % 120 == 0:
		var b: Vector3 = ball.global_position
		var g0: Vector3 = gliders[0].global_position
		var g1: Vector3 = gliders[1].global_position
		print("[dbg] f=%d ball(%.0f,%.0f,%.0f) bv=%.1f | blue(%.0f,%.0f,%.0f) orange(%.0f,%.0f,%.0f)" % [
			frame, b.x, b.y, b.z, ball.velocity.length(),
			g0.x, g0.y, g0.z, g1.x, g1.y, g1.z])
	var total: int = arena.score_blue + arena.score_orange
	if total > last_total:
		last_total = total
		if verbose:
			print("[match] goal f=%d  blue=%d orange=%d" % [frame, arena.score_blue, arena.score_orange])
		_kickoff()  # referee already reset to centre; override with randomness
	if frame >= max_frames or total >= max_goals:
		print("[match] TALLY blue_variant=%s orange_variant=%s blue=%d orange=%d frames=%d" % [
			blue_variant, orange_variant, arena.score_blue, arena.score_orange, frame])
		get_tree().quit()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() != 2:
			continue
		var k: String = kv[0]
		var v: String = kv[1]
		match k:
			"blue": blue_variant = v
			"orange": orange_variant = v
			"seed": seed_val = int(v)
			"frames": max_frames = int(v)
			"goals": max_goals = int(v)
			"noise": noise = float(v)
			"verbose": verbose = v == "1"
