extends Node3D
## Zona de viento: empuja la bola en una dirección con ráfagas periódicas.
## Las hojas que vuelan muestran cuándo sopla y hacia dónde.

var rect := Rect2()          # zona en el plano (x, z)
var dir := Vector2.RIGHT     # dirección del viento (x, z)
var strength := 1.5          # aceleración máxima en m/s²
var period := 4.5            # segundos por ciclo de ráfaga
var _t := 0.0
var _leaves: CPUParticles3D


func setup(p_rect: Rect2, p_dir: Vector2, p_strength: float, p_period: float, y: float) -> void:
	rect = p_rect
	dir = p_dir.normalized()
	strength = p_strength
	period = p_period
	_leaves = CPUParticles3D.new()
	_leaves.amount = 36
	_leaves.lifetime = 1.6
	_leaves.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.045)
	_leaves.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaves.material_override = mat
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = Vector3(rect.size.x * 0.5, 0.25, rect.size.y * 0.5)
	_leaves.position = Vector3(rect.get_center().x - dir.x * rect.size.x * 0.3, y + 0.35,
		rect.get_center().y - dir.y * rect.size.y * 0.3)
	_leaves.direction = Vector3(dir.x, 0.15, dir.y)
	_leaves.spread = 12.0
	_leaves.initial_velocity_min = 2.0
	_leaves.initial_velocity_max = 3.2
	_leaves.gravity = Vector3(0, -0.4, 0)
	_leaves.angular_velocity_min = -300.0
	_leaves.angular_velocity_max = 300.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.8, 0.3))
	grad.set_color(1, Color(0.95, 0.85, 0.35))
	_leaves.color_initial_ramp = grad
	add_child(_leaves)


func gust() -> float:
	var s := maxf(0.0, sin(TAU * _t / period))
	return s * s


func accel_at(p: Vector3) -> Vector3:
	if not rect.has_point(Vector2(p.x, p.z)):
		return Vector3.ZERO
	var g := gust() * strength
	return Vector3(dir.x * g, 0.0, dir.y * g)


func _process(delta: float) -> void:
	_t += delta
	if _leaves:
		_leaves.emitting = gust() > 0.12
