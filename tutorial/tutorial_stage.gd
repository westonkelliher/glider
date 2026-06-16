class_name TutorialStage
extends Node3D
## Base class for one tutorial stage. The manager injects context (`glider`,
## `ui`), then drives the lifecycle:
##
##   place glider at start_pose()  ->  build()  ->  show intro_lines()
##   -> [player dismisses] -> on_begin() + timer starts -> update(delta) each
##   physics frame -> [emit `completed`] -> medal banner -> next stage.
##
## Spawn all your props (TutGate / TutMarker / TutZone / a Ball / etc.) as
## CHILDREN of `self` in build(); they are freed automatically when the stage
## ends. Remember to set `prop.glider = glider` on TutGate/TutMarker/TutZone so
## they can detect the player.
##
## NOTE: this project treats untyped declarations as ERRORS — give every `var`
## an explicit type.

signal completed
signal failed(reason: String)

var glider: Glider = null
var ui: TutorialUI = null
## The scene's camera rig. Ball stages can read its `mode` (0=FREE, 1=BALL,
## 2=VELOCITY) to detect ball-cam, and `spawn_ball()` registers the ball with it.
var camera: Node3D = null


# ---- Override these ----

## Short title shown in the header, e.g. "1 · Hold to Glide".
func stage_title() -> String:
	return "Stage"

## Lines shown on a panel before the stage begins (dismissed with Space / A).
func intro_lines() -> Array[String]:
	return []

## Where the glider spawns. Return a unit-scale transform; the manager applies
## the craft's display scale. Basis -Z is the nose direction.
func start_pose() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.0, 30.0, 0.0))

## Par time in seconds for a "gold" medal. Return 0.0 for an untimed stage.
func par_time() -> float:
	return 0.0

## Spawn props as children of self. Called once after the glider is placed.
func build() -> void:
	pass

## Called after the intro panel is dismissed; start any motion here.
func on_begin() -> void:
	pass

## Per-physics-frame progress check. Emit `completed` when the objective is met.
func update(_delta: float) -> void:
	pass

## Optional extra cleanup. Child props are freed by the manager regardless.
func teardown() -> void:
	pass


## Which powers this stage unlocks. Steering + grip are always available;
## boost and the hard-brake stay disabled until the stage that teaches them.
func allow_boost() -> bool:
	return false

func allow_slow() -> bool:
	return false


# ---- Helpers available to subclasses ----

## Convenience: a transform at `pos` whose nose (-Z) faces `look_dir`.
func pose_facing(pos: Vector3, look_dir: Vector3) -> Transform3D:
	var dir: Vector3 = look_dir
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	return Transform3D(Basis.looking_at(dir, Vector3.UP), pos)


## Spawn the game ball at `pos` as a child of this stage and register it with the
## camera rig so the ball-cam toggle tracks it. Returns the ball node.
func spawn_ball(pos: Vector3, ball_scale: float = 1.2) -> Node3D:
	var b: Node3D = load("res://ball.tscn").instantiate() as Node3D
	b.position = pos
	b.scale = Vector3.ONE * ball_scale
	add_child(b)
	if camera != null:
		camera.set("ball", b)
	return b


## True when the player has the camera locked onto the ball (BALL mode == 1).
func ball_cam_on() -> bool:
	return camera != null and int(camera.get("mode")) == 1
