shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/toon.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float noise_amount = 0.0;
uniform float noise_scale = 1.2;
uniform float wobble = 0.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wobble > 0.0) {
		float s = sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5);
		VERTEX.x += s * wobble * max(VERTEX.y, 0.0);
		VERTEX.z += s * wobble * 0.5 * max(VERTEX.y, 0.0);
	}
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_vertex_color) {
		c *= pow(COLOR.rgb, vec3(2.2));
	}
	if (noise_amount > 0.0) {
		float n = vnoise(wpos.xz * noise_scale) * 0.65 + vnoise(wpos.xz * noise_scale * 3.7) * 0.35;
		c *= 1.0 + (n - 0.5) * noise_amount;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = emission.rgb * emission_energy;
}
