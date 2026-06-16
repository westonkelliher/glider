class_name TutMarker
extends Node3D
## A floating waypoint sphere. Emits `reached` once when the glider comes within
## `radius`. Build with TutMarker.make(pos, radius); assign `glider`.

signal reached

@export var radius: float = 6.0
var glider: Node3D = null

var _armed: bool = true
var _mesh: MeshInstance3D = null
var _t: float = 0.0
var _base_y: float = 0.0


static func make(pos: Vector3, hit_radius: float = 6.0) -> TutMarker:
	var m: TutMarker = TutMarker.new()
	m.radius = hit_radius
	m.position = pos
	return m


func _ready() -> void:
	_base_y = position.y
	_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius * 0.5
	sphere.height = radius
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.1)
	mat.emission_energy_multiplier = 2.5
	sphere.material = mat
	_mesh.mesh = sphere
	add_child(_mesh)


func set_color(c: Color) -> void:
	if _mesh == null:
		return
	var mat: StandardMaterial3D = _mesh.mesh.material as StandardMaterial3D
	mat.albedo_color = c
	mat.emission = c


func _physics_process(delta: float) -> void:
	# gentle bob so waypoints read as targets, not scenery
	_t += delta
	position.y = _base_y + sin(_t * 2.0) * 0.6
	if not _armed or glider == null:
		return
	if global_position.distance_to(glider.global_position) <= radius:
		_armed = false
		set_color(Color(0.3, 1.0, 0.4))
		reached.emit()
