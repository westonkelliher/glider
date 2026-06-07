@tool
extends Node3D
## Procedurally scatters trees (cylinder trunk + cone foliage) and rocks
## (low-poly spheres embedded in the ground) across the floor plane.
## Runs in the editor too (@tool); spawned nodes are runtime-only (no owner),
## so they preview live but are never baked into the scene file.

@export var area_size: float = 200.0:
	set(v): area_size = v; _regenerate()
@export var tree_count: int = 120:
	set(v): tree_count = v; _regenerate()
@export var rock_count: int = 80:
	set(v): rock_count = v; _regenerate()
@export var rng_seed: int = 1337:
	set(v): rng_seed = v; _regenerate()

func _ready() -> void:
	_regenerate()

func _regenerate() -> void:
	if not is_inside_tree():
		return
	# Clear previously generated children before re-scattering.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_scatter(rng, tree_count, _make_tree)
	_scatter(rng, rock_count, _make_rock)

func _scatter(rng: RandomNumberGenerator, count: int, factory: Callable) -> void:
	var half := area_size * 0.5
	for i in count:
		var node: Node3D = factory.call(rng)
		node.position = Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		node.rotate_y(rng.randf_range(0.0, TAU))
		add_child(node)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _make_tree(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var scale := rng.randf_range(0.8, 1.6)

	var trunk_h := 2.0 * scale
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale
	trunk_mesh.bottom_radius = 0.25 * scale
	trunk_mesh.height = trunk_h
	trunk.mesh = trunk_mesh
	trunk.material_override = _mat(Color(0.4, 0.26, 0.13))
	trunk.position.y = trunk_h * 0.5
	root.add_child(trunk)

	var foliage_h := 3.0 * scale
	var foliage := MeshInstance3D.new()
	var foliage_mesh := CylinderMesh.new() # cone = cylinder with top_radius 0
	foliage_mesh.top_radius = 0.0
	foliage_mesh.bottom_radius = 1.3 * scale
	foliage_mesh.height = foliage_h
	foliage.mesh = foliage_mesh
	foliage.material_override = _mat(Color(0.13, 0.42, 0.18))
	foliage.position.y = trunk_h + foliage_h * 0.4
	root.add_child(foliage)
	return root

func _make_rock(rng: RandomNumberGenerator) -> Node3D:
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
	return rock
