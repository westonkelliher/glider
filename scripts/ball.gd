extends CharacterBody3D
class_name Ball

## Rocket-league-style ball. Uses SumoSoccer's "detect-revert-resolve" pattern:
## move_and_slide() is run only to DETECT contacts, then position/velocity are
## reverted and collisions resolved manually with impulse math. Final motion is
## integrated by hand. See ../SumoSoccer/ball.gd.

const G := 7.0 # floatier than 9.8

var mass := 30.0
var radius := 2.0                  # filled from the collision shape in _ready

const RESTITUTION := 0.6           # bounciness against the glider
const GROUND_RESTITUTION := 0.6    # bounce off floor / static geometry
const AIR_DRAG := 0.11             # fractional speed loss per second in air
const ROLL_FRICTION := 1.2         # horizontal decel (units/s) while on ground

var last_position := Vector3.ZERO
var last_velocity := Vector3.ZERO


func _ready() -> void:
	add_to_group("ball")
	var shape: Shape3D = $Shape.shape
	if shape is SphereShape3D:
		radius = shape.radius * scale.x
	velocity = Vector3.UP * 24.0


func _physics_process(delta: float) -> void:
	# gravity
	velocity += G * Vector3.DOWN * delta
	#
	# detect collisions, then revert godot's slide (SumoSoccer pattern)
	last_position = global_position
	last_velocity = velocity
	move_and_slide()
	global_position = last_position
	velocity = last_velocity
	for i in get_slide_collision_count():
		_handle_collision(get_slide_collision(i))
	#
	_handle_ground(delta)
	_apply_drag(delta)
	#
	# integrate manually
	global_position += velocity * delta


func _handle_collision(c: KinematicCollision3D) -> void:
	var other := c.get_collider()
	var n := c.get_normal()            # points from the surface toward the ball
	var depth := c.get_depth()
	if other is Glider:
		_resolve_dynamic(other, n, depth)
	else:
		# static / world geometry: push out and reflect
		global_position += n * depth
		var vn := velocity.dot(n)
		if vn < 0.0:
			velocity -= (1.0 + GROUND_RESTITUTION) * vn * n


## Elastic impulse exchange with a moving body that exposes `velocity`/`mass`.
func _resolve_dynamic(other: Glider, n: Vector3, depth: float) -> void:
	global_position += n * depth       # de-penetrate
	var relative_v: Vector3 = velocity - other.velocity
	var v_along_normal := relative_v.dot(n)
	if v_along_normal > 0.0:
		return                         # already separating
	var j := -(1.0 + RESTITUTION) * v_along_normal
	j /= (1.0 / mass) + (1.0 / other.mass)
	var impulse := j * n
	velocity += impulse / mass
	if other.has_method("apply_impulse"):
		other.apply_impulse(-impulse)


func _handle_ground(delta: float) -> void:
	if global_position.y > radius:
		return
	global_position.y = radius
	if velocity.y < 0.0:
		velocity.y = -velocity.y * GROUND_RESTITUTION
		if velocity.y < 1.0:           # kill tiny bounces so it settles
			velocity.y = 0.0
	# rolling friction on the horizontal component
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.move_toward(Vector3.ZERO, ROLL_FRICTION * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z


func _apply_drag(delta: float) -> void:
	velocity *= maxf(0.0, 1.0 - AIR_DRAG * delta)
