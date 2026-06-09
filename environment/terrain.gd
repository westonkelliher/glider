class_name Terrain
extends Node3D
## Infinite rolling-hill terrain: keeps a dictionary of SinChunk instances
## keyed by chunk coordinate and instances any missing chunks within
## RADIUS chunks of the glider each physics frame. Chunks are never freed.

const CHUNK_SIZE := 32
const RADIUS := 5 # 11x11 grid around the glider
const MAX_NEW_PER_FRAME := 3 # spread streaming cost so boundary crossings don't hitch

const CHUNK_SCENE: PackedScene = preload("res://environment/sin_chunk.tscn")

@export var glider_path: NodePath = ^"../GliderBody"

var _chunks: Dictionary = {}
var _glider: Node3D = null


func _ready() -> void:
	_glider = get_node(glider_path) as Node3D
	_update_chunks(RADIUS * RADIUS * 8) # initial fill all at once, before play


func _physics_process(_delta: float) -> void:
	_update_chunks(MAX_NEW_PER_FRAME)


func _update_chunks(max_new: int) -> void:
	var p := _glider.global_position
	var idx := Vector2i(roundi(p.x / CHUNK_SIZE), roundi(p.z / CHUNK_SIZE))
	var spawned := 0
	# nearest rings first so the ground under the glider always exists
	for r in range(0, RADIUS + 1):
		for z in range(idx.y - r, idx.y + r + 1):
			for x in range(idx.x - r, idx.x + r + 1):
				var key := Vector2i(x, z)
				if maxi(absi(x - idx.x), absi(z - idx.y)) < r or _chunks.has(key):
					continue
				var chunk: SinChunk = CHUNK_SCENE.instantiate()
				chunk.position = Vector3(x * CHUNK_SIZE, 0, z * CHUNK_SIZE)
				add_child(chunk)
				_chunks[key] = chunk
				spawned += 1
				if spawned >= max_new:
					return
