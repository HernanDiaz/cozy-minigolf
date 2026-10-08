// Iluminación de dibujo animado suave: transición corta entre luz y sombra,
// sombras teñidas de azul en vez de negras y un ligero brillo en el borde.
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.52, 0.85, 1.0);
uniform float shadow_fill = 0.32;
uniform float band_soft = 0.08;
uniform float rim_strength = 0.18;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_soft, ndl) * smoothstep(0.25, 0.75, ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb * shadow_fill, vec3(1.0), lit);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength * lit;
	DIFFUSE_LIGHT += LIGHT_COLOR * (shade + rim) / PI;
}
