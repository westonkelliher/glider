class_name TutGate
extends Node3D
## A ring the glider flies through. Emits `passed` once when the glider crosses
## the ring's plane (local -Z face) while within `radius` of the centre.
##
## Build one with TutGate.make(pos, look_dir, radius) and add it as a child of
## your stage. Assign `glider` (the manager-provided player glider) before it
## enters the tree, or set it right after .make() — the stage's `glider` works.

signal passed

@export var radius: float = 8.0
var glider: Node3D = null

var _armed: bool = true
var _have_prev: bool = false
var _prev_z: float = 0.0
var _ring: MeshInstance3D = null
var _passed_color: Color = Color(0.3, 1.0, 0.4)


static func make(pos: Vector3, look_dir: Vector3, ring_radius: float = 8.0) -> TutGate:
	var g: TutGate = TutGate.new()
	g.radius = ring_radius
	g.position = pos
	var dir: Vector3 = look_dir
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	# Ring plane normal points along local -Z, so flying toward `look_dir`
	# passes through it.
	g.basis = Basis.looking_at(dir, Vector3.UP)
	return g


func _ready() -> void:
	_build_mesh()


func _build_mesh() -> void:
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.outer_radius = radius
	torus.inner_radius = maxf(radius - 0.7, radius * 0.85)
	torus.rings = 24
	torus.ring_segments = 12
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.8, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.2, 0.7, 1.0)
	m.emission_energy_multiplier = 2.0
	torus.material = m
	_ring.mesh = torus
	# Torus lies in the local XZ plane; rotate so it lies in XY (normal = Z).
	_ring.rotation.x = PI / 2.0
	add_child(_ring)


## Recolour the ring (used to show it as already cleared).
func set_color(c: Color) -> void:
	if _ring == null:
		return
	var m: StandardMaterial3D = _ring.mesh.material as StandardMaterial3D
	m.albedo_color = c
	m.emission = c


func _physics_process(_delta: float) -> void:
	if not _armed or glider == null:
		return
	var local: Vector3 = to_local(glider.global_position)
	var z: float = local.z
	if _have_prev:
		var crossed: bool = (z <= 0.0 and _prev_z > 0.0) or (z >= 0.0 and _prev_z < 0.0)
		var in_ring: bool = Vector2(local.x, local.y).length() <= radius
		if crossed and in_ring:
			_armed = false
			set_color(_passed_color)
			passed.emit()
	_prev_z = z
	_have_prev = true
