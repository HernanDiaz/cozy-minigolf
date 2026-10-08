shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

#include "res://shaders/noise.gdshaderinc"

// Agua de acuarela: color turquesa con destellos claros que se desplazan.
uniform vec4 deep : source_color = vec4(0.14, 0.46, 0.66, 0.86);
uniform vec4 sparkle : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform vec2 flow = vec2(0.15, 0.08);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * 2.2 + flow * TIME;
	float n = vnoise(p) * vnoise(p * 1.7 - TIME * 0.12);
	float streak = smoothstep(0.3, 0.38, n);
	ALBEDO = mix(deep.rgb, sparkle.rgb, streak * 0.7);
	ALPHA = mix(deep.a, 1.0, streak * 0.5);
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
