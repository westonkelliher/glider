class_name TutZone
extends Node3D
## A box region drawn as a glowing WIREFRAME plus a translucent floor pad — so
## it stays readable whether you're outside it or flying through the middle (a
## solid box would either backface-cull to nothing or wash out the whole view
## from inside). Poll `is_inside(pos)`, or connect `entered` / `exited`.
## Build with TutZone.make(pos, size).

signal entered
signal exited

@export var size: Vector3 = Vector3(12, 12, 12)
var glider: Node3D = null
var color: Color = Color(0.3, 1.0, 0.5)

var _inside: bool = false
var _edges: MeshInstance3D = null
var _pad: MeshInstance3D = null
var _edge_mat: StandardMaterial3D = null
var _pad_mat: StandardMaterial3D = null


static func make(pos: Vector3, box_size: Vector3) -> TutZone:
	var z: TutZone = TutZone.new()
	z.position = pos
	z.size = box_size
	return z


func _ready() -> void:
	_build_edges()
	_build_pad()
	set_color(color)


func _build_edges() -> void:
	var h: Vector3 = size * 0.5
	# 8 corners of the box.
	var c: Array[Vector3] = [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	# 12 edges as index pairs.
	var e: Array[int] = [
		0, 1, 1, 2, 2, 3, 3, 0,  # bottom
		4, 5, 5, 6, 6, 7, 7, 4,  # top
		0, 4, 1, 5, 2, 6, 3, 7,  # verticals
	]
	_edge_mat = StandardMaterial3D.new()
	_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_mat.emission_enabled = true
	_edge_mat.emission_energy_multiplier = 3.0
	var im: ImmediateMesh = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, _edge_mat)
	for i: int in range(0, e.size(), 2):
		im.surface_add_vertex(c[e[i]])
		im.surface_add_vertex(c[e[i + 1]])
	im.surface_end()
	_edges = MeshInstance3D.new()
	_edges.mesh = im
	add_child(_edges)


func _build_pad() -> void:
	# A thin glowing slab on the box floor — the thing you aim to land on.
	_pad_mat = StandardMaterial3D.new()
	_pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pad_mat.emission_enabled = true
	_pad_mat.emission_energy_multiplier = 1.2
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(size.x, 0.4, size.z)
	box.material = _pad_mat
	_pad = MeshInstance3D.new()
	_pad.mesh = box
	_pad.position.y = -size.y * 0.5
	add_child(_pad)


func set_color(c: Color) -> void:
	color = c
	if _edge_mat != null:
		_edge_mat.albedo_color = Color(c.r, c.g, c.b, 1.0)
		_edge_mat.emission = Color(c.r, c.g, c.b)
	if _pad_mat != null:
		_pad_mat.albedo_color = Color(c.r, c.g, c.b, 0.22)
		_pad_mat.emission = Color(c.r, c.g, c.b)


func is_inside(world_pos: Vector3) -> bool:
	var local: Vector3 = to_local(world_pos)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 \
		and absf(local.z) <= size.z * 0.5


func _physics_process(_delta: float) -> void:
	if glider == null:
		return
	var now: bool = is_inside(glider.global_position)
	if now and not _inside:
		entered.emit()
	elif not now and _inside:
		exited.emit()
	_inside = now
