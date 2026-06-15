extends Node
## Headless telemetry probe. Instanced alongside main.tscn by tests/ai_test.tscn.
## Prints AI glider + ball state every N physics frames so we can see whether
## the AI chases the ball and drives it toward the BLUE goal (world +Z, z=215).

const EVERY := 30    # print cadence (frames)
const STOP_AT := 3000  # self-quit after this many physics frames (deterministic)
var frame := 0


func _find_ai() -> Node3D:
	for g in get_tree().get_nodes_in_group("glider"):
		if g.get("is_ai") == true:
			return g
	return null


func _physics_process(_d: float) -> void:
	frame += 1
	if frame >= STOP_AT:
		print("[probe] done at f=%d" % frame)
		get_tree().quit()
		return
	if frame % EVERY != 0:
		return
	var ball: Node3D = get_tree().get_first_node_in_group("ball")
	var ai := _find_ai()
	if ball == null or ai == null:
		print("[probe] f=%d  MISSING ball=%s ai=%s" % [frame, ball, ai])
		return
	var bp: Vector3 = ball.global_position
	var ap: Vector3 = ai.global_position
	var nose: Vector3 = (ai.global_transform.basis * Vector3.FORWARD).normalized()
	var d: float = ap.distance_to(bp)
	print("[probe] f=%d d=%.1f | ai(%.0f,%.0f,%.0f) v=%.1f nose(%.2f,%.2f,%.2f) | ball(%.0f,%.0f,%.0f) bz=%.0f bv=%.1f | tgt(%.2f,%.2f,%.2f)" % [
		frame, d,
		ap.x, ap.y, ap.z, ai.velocity.length(), nose.x, nose.y, nose.z,
		bp.x, bp.y, bp.z, bp.z, ball.velocity.length(),
		ai.ail_pitch, ai.ail_roll, ai.ail_yaw,
	])
