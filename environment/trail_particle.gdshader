shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// opacity = base_alpha * (1.0 - (t/T)^fade_exp), where t/T is the particle's
// age fraction (0 at birth, 1 at death), read from INSTANCE_CUSTOM.y.
uniform vec3 trail_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float fade_exp = 0.1;
uniform float base_alpha = 1.0;
uniform float softness = 0.35; // radial edge falloff (0 = hard square, 1 = very soft)

varying float age; // t/T, passed from vertex

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);

	// Billboard: face the camera while preserving the particle's scale.
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	mat4 mv = VIEW_MATRIX * MODEL_MATRIX;
	mv[0] = vec4(sx, 0.0, 0.0, 0.0);
	mv[1] = vec4(0.0, sy, 0.0, 0.0);
	mv[2] = vec4(0.0, 0.0, 1.0, 0.0);
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	float a = base_alpha * (1.0 - pow(age, fade_exp));

	// soft round sprite instead of a hard quad
	float d = distance(UV, vec2(0.5)) * 2.0; // 0 center -> 1 edge
	float mask = 1.0 - smoothstep(1.0 - softness, 1.0, d);

	ALBEDO = trail_color;
	ALPHA = clamp(a, 0.0, 1.0) * mask;
}
