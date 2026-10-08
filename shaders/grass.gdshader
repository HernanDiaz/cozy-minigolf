shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/toon.gdshaderinc"

// Matas de hierba que se mecen con el viento (una instancia por mata).
uniform vec4 base_color : source_color = vec4(0.16, 0.38, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(0.58, 0.82, 0.32, 1.0);
uniform float wind = 0.18;

varying float hgt;

void vertex() {
	hgt = VERTEX.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.8 + wp.x * 0.9 + wp.z * 0.4) + 0.4 * sin(TIME * 3.3 + wp.z * 1.7);
	VERTEX.x += s * wind * hgt;
	VERTEX.z += s * wind * 0.4 * hgt;
}

void fragment() {
	vec3 c = mix(base_color.rgb, tip_color.rgb, clamp(hgt / 0.35, 0.0, 1.0));
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = 1.0;
}
