extends RefCounted
## Materiales compartidos del estilo visual (dibujo animado suave, inspirado
## en la animación japonesa de paisajes: verdes vivos, sombras azuladas).

const TOON = preload("res://shaders/toon.gdshader")
const GRASS = preload("res://shaders/grass.gdshader")
const WATER = preload("res://shaders/water.gdshader")


static func toon(col: Color, noise: float = 0.0, wobble: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("noise_amount", noise)
	m.set_shader_parameter("wobble", wobble)
	return m


## Material que usa los colores por vértice (y por instancia en MultiMesh).
static func toon_vc(noise: float = 0.0, noise_scale: float = 1.2) -> ShaderMaterial:
	var m := toon(Color.WHITE, noise)
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("noise_scale", noise_scale)
	return m


## Nubes: blancas, con la cara en sombra azul muy clara.
static func cloud() -> ShaderMaterial:
	var m := toon(Color(1, 1, 1))
	m.set_shader_parameter("shadow_tint", Color(0.72, 0.8, 1.0))
	m.set_shader_parameter("shadow_fill", 0.85)
	m.set_shader_parameter("band_soft", 0.3)
	m.set_shader_parameter("rim_strength", 0.35)
	return m


## Material que brilla (setas mágicas, espíritus, portales). Con el "glow"
## del entorno deja un halo suave.
static func glow(col: Color, energy: float = 1.5) -> ShaderMaterial:
	var m := toon(col)
	m.set_shader_parameter("emission", col)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("shadow_fill", 0.9)
	return m


static func grass(base: Color = Color(0.16, 0.38, 0.12), tip: Color = Color(0.58, 0.82, 0.32)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("tip_color", tip)
	return m


static func water() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER
	return m
