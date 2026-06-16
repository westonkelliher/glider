extends CanvasLayer
class_name MatchController
## Runs a 3-2-1-GO countdown before kickoff: freezes every glider and the ball
## (disables their physics), counts down on a big centre label, then releases
## them on "GO!". The referee calls kickoff() again after each goal so every
## restart gets the same countdown.

@export var count_from: int = 3
@export var go_linger: float = 0.6   # seconds "GO!" stays up after release

## Symmetric kickoff spawns (Rocket League style), given for the BLUE/player
## side (z > 0); the orange/AI side is the mirror (-x, -z). Each entry is the
## (x, z) ground position for that side. Picked once per kickoff and shared by
## both teams so they stay mirrored. Kept within the arena scale (|x|<=10.5,
## |z|<=28). Facing per side is preserved from each glider's scene transform.
const KICKOFF_SPAWNS: Array[Vector2] = [
	Vector2(0.0, 28.0),     # back-center
	Vector2(7.0, 25.0),     # back-right diagonal
	Vector2(-7.0, 25.0),    # back-left diagonal
	Vector2(10.5, 21.0),    # right corner
	Vector2(-10.5, 21.0),   # left corner
]

var _label: Label = null
var _busy: bool = false


func _ready() -> void:
	layer = 20
	add_to_group("match_controller")
	_build_label()
	# Wait one frame so the gliders and ball have joined their groups in _ready.
	await get_tree().process_frame
	place_kickoff(get_tree())
	kickoff()


func _build_label() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -300.0
	_label.offset_right = 300.0
	_label.offset_top = -120.0
	_label.offset_bottom = 120.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 140)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 12)
	_label.visible = false
	add_child(_label)


## Pick one random kickoff spawn (shared by both teams so they stay mirrored)
## and apply it to every glider, then snap them back to that spawn. Static so
## the referee can reuse it without duplicating the spawn table.
static func place_kickoff(tree: SceneTree) -> void:
	var blue_xz: Vector2 = KICKOFF_SPAWNS[randi() % KICKOFF_SPAWNS.size()]
	for g: Node in tree.get_nodes_in_group("glider"):
		if g.has_method("set_kickoff_position"):
			g.set_kickoff_position(blue_xz)
		if g.has_method("reset_to_spawn"):
			g.reset_to_spawn()


## Freeze the field, count down, then release on GO. Safe to call repeatedly.
func kickoff() -> void:
	if _busy:
		return
	_busy = true
	_set_frozen(true)
	var n: int = count_from
	while n > 0:
		_label.text = str(n)
		_label.visible = true
		await get_tree().create_timer(1.0).timeout
		n -= 1
	_label.text = "GO!"
	_set_frozen(false)
	await get_tree().create_timer(go_linger).timeout
	_label.visible = false
	_busy = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		reset_match()


## Back button / R: put the ball and gliders back to spawn and re-run kickoff.
func reset_match() -> void:
	var ball: Node = get_tree().get_first_node_in_group("ball")
	if ball:
		ball.global_position = Vector3(0, 5, 0)
		ball.set("velocity", Vector3.UP * 15.0)
	place_kickoff(get_tree())
	kickoff()


func _set_frozen(frozen: bool) -> void:
	for g: Node in get_tree().get_nodes_in_group("glider"):
		g.set_physics_process(not frozen)
	for b: Node in get_tree().get_nodes_in_group("ball"):
		b.set_physics_process(not frozen)
