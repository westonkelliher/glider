class_name GroundMath
extends RefCounted
## Analytic terrain height — single source of truth shared by the chunk
## collision/mesh builder and the glider's terrain-following physics.
## Ported from GetHeavy's sin_body height equation, rescaled for flight:
## wider hills and taller amplitude than the rolling-ball original.

const AMPLITUDE := 9.0
const H_SCALE := 2.6 # horizontal stretch vs GetHeavy original


static func height(wx: float, wz: float) -> float:
	var x := wx / H_SCALE
	var z := wz / H_SCALE
	var v := Vector2(x, z)
	var b1 := _noise(x, z)
	var v_course := v.rotated(PI / 4) / 6.0 + Vector2(20, 20)
	var b2 := _noise(v_course.x, v_course.y)
	var v_fine := v.rotated(PI / 3) * 2.0 + Vector2(-20, 20)
	var b3 := _noise(v_fine.x, v_fine.y)
	return (b1 + 1.8 * b2 + 0.15 * b3) * AMPLITUDE


static func _noise(x: float, y: float) -> float:
	return sin(x / 5) + 0.05 * sin(x / 7 + .4) + 0.05 * sin(x / 1.4 + .8) \
		+ 0.4 * sin(y / 3) + 0.2 * sin(x / 4 + y / 2) + 0.2 * sin(x / 2 - y / 4) \
		+ 1.0 * cos(x / 20 + y / 25)


## Unit upward surface normal via central differences.
static func normal(wx: float, wz: float) -> Vector3:
	const E := 0.5
	var dx := height(wx + E, wz) - height(wx - E, wz)
	var dz := height(wx, wz + E) - height(wx, wz - E)
	return Vector3(-dx, 2.0 * E, -dz).normalized()
