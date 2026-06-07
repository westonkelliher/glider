shader_type spatial;

// World-space checkerboard on the X,Z plane. 1m x 1m squares.
// Pattern is keyed to world coords (via MODEL_MATRIX), so it stays
// aligned to the world grid regardless of mesh placement, and Y is
// ignored -- terrain slopes stretch the squares in 3D.

uniform float square_size = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Anti-aliased "is this an even cell?" stripe along one axis.
// tri is a triangle wave (slope 1 in cell units): 1 at even cells,
// 0 at odd cells. fw is that axis's pixel footprint (from fwidth), so
// the smoothstep transition is exactly ~one pixel wide regardless of
// distance/angle -- far-away cells fade to the average instead of aliasing.
float aa_stripe(float u, float fw) {
	float tri = abs(2.0 * fract(u * 0.5) - 1.0);
	float aa = max(fw, 1e-5);
	return smoothstep(0.5 - aa, 0.5 + aa, tri);
}

void fragment() {
	vec2 uv = world_pos.xz / square_size;
	vec2 fw = fwidth(uv); // screen-space derivative -> pixel size in cell units
	float ax = aa_stripe(uv.x, fw.x);
	float az = aa_stripe(uv.y, fw.y);
	// XOR of the two axis parities = checkerboard, blended at edges.
	float checker = ax + az - 2.0 * ax * az;
	//
	vec3 light_green = vec3(0.09, 0.48, 0.035);
	vec3 dark_green = vec3(0.035, 0.28, 0.035);
	ALBEDO = mix(dark_green, light_green, checker);
}
