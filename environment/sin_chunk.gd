class_name SinChunk
extends StaticBody3D
## One 32m terrain chunk: 33x33 HeightMapShape3D collision + flat-shaded
## checker-green ArrayMesh, both sourced from GroundMath.height so physics
## matches visuals exactly. Also scatters deterministic trees/rocks.

const CHUNK_SIZE := 32
const SIZE: Vector2i = Vector2i(CHUNK_SIZE + 1, CHUNK_SIZE + 1)
const HALF := CHUNK_SIZE / 2 # heightmap is centered on the body origin

var _heights := PackedFloat32Array()


func _ready() -> void:
	_build_collision_shape()
	_build_mesh()
	_scatter_decorations()


## Sample GroundMath at world coords; heightmap point (x,z) sits at local
## (x - HALF, z - HALF), so world = chunk position + local.
func _build_collision_shape() -> void:
	_heights.resize(SIZE.x * SIZE.y)
	for z in range(SIZE.y):
		for x in range(SIZE.x):
			var wx := position.x + float(x - HALF)
			var wz := position.z + float(z - HALF)
			_heights[z * SIZE.x + x] = GroundMath.height(wx, wz)
	var shape := HeightMapShape3D.new()
	shape.map_width = SIZE.x
	shape.map_depth = SIZE.y
	shape.map_data = _heights
	($Shape as CollisionShape3D).shape = shape


func _build_mesh() -> void:
	var arrays := _build_mesh_arrays()
	var arr_mesh := ArrayMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, material)
	var mesh_ins := MeshInstance3D.new()
	mesh_ins.mesh = arr_mesh
	add_child(mesh_ins)


## Flat-shaded triangles with alternating two-green checker vertex colors,
## ported from GetHeavy's SinBody.build_mesh_arrays.
func _build_mesh_arrays() -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var green1 := Color(0.01, 0.94, 0.01)
	var green2 := Color(0.005, 0.60, 0.005)
	for z in range(SIZE.y - 1):
		for x in range(SIZE.x - 1):
			var color := green1
			if x % 2 == z % 2:
				color = green2
			#
			var vx := x - HALF
			var vz := z - HALF
			var v1 := Vector3(vx, _get_height(x, z), vz)
			var v2 := Vector3(vx + 1, _get_height(x + 1, z), vz)
			var v3 := Vector3(vx, _get_height(x, z + 1), vz + 1)
			var v4 := Vector3(vx + 1, _get_height(x + 1, z + 1), vz + 1)
			#
			var n123 := (v1 - v2).cross(v3 - v1)
			#
			vertices.push_back(v1)
			vertices.push_back(v2)
			vertices.push_back(v3)
			vertices.push_back(v4)
			vertices.push_back(v3)
			vertices.push_back(v2)
			#
			for i in range(6):
				normals.push_back(n123)
				colors.push_back(color)
	#
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays


func _get_height(x: int, z: int) -> float:
	return _heights[z * SIZE.x + x]


#### Decoration ####

## Deterministic per-chunk scatter: ~3-6 trees, ~2-4 rocks seeded from the
## chunk coordinate so chunks always regenerate identically.
func _scatter_decorations() -> void:
	var coord := Vector2i(roundi(position.x / CHUNK_SIZE), roundi(position.z / CHUNK_SIZE))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord)
	for i in range(rng.randi_range(3, 6)):
		_place(rng, _make_tree(rng))
	for i in range(rng.randi_range(2, 4)):
		_place(rng, _make_rock(rng))


func _place(rng: RandomNumberGenerator, node: Node3D) -> void:
	var lx := rng.randf_range(-float(HALF), float(HALF))
	var lz := rng.randf_range(-float(HALF), float(HALF))
	node.position = Vector3(lx, GroundMath.height(position.x + lx, position.z + lz), lz)
	node.rotate_y(rng.randf_range(0.0, TAU))
	add_child(node)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _make_tree(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var tree_scale := rng.randf_range(0.8, 3.2)

	var trunk_h := 2.0 * tree_scale
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * tree_scale
	trunk_mesh.bottom_radius = 0.25 * tree_scale
	trunk_mesh.height = trunk_h
	trunk.mesh = trunk_mesh
	trunk.material_override = _mat(Color(0.4, 0.26, 0.13))
	trunk.position.y = trunk_h * 0.5
	root.add_child(trunk)

	var foliage_h := 3.0 * tree_scale
	var foliage := MeshInstance3D.new()
	var foliage_mesh := CylinderMesh.new() # cone = cylinder with top_radius 0
	foliage_mesh.top_radius = 0.0
	foliage_mesh.bottom_radius = 1.3 * tree_scale
	foliage_mesh.height = foliage_h
	foliage.mesh = foliage_mesh
	foliage.material_override = _mat(Color(0.13, 0.42, 0.18))
	foliage.position.y = trunk_h + foliage_h * 0.4
	root.add_child(foliage)
	return root


func _make_rock(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var r := rng.randf_range(0.6, 2.2)
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 6 # low poly
	mesh.rings = 3
	rock.mesh = mesh
	rock.material_override = _mat(Color(0.5, 0.5, 0.52))
	# embed in ground: sink so only the top portion shows
	rock.position.y = -r * rng.randf_range(0.3, 0.6)
	rock.scale = Vector3(1.0, rng.randf_range(0.6, 0.9), 1.0)
	root.add_child(rock)
	return root
