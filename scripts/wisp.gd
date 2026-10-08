extends AnimatableBody3D
## Espíritu del bosque: una bolita de luz con ojos que flota de un punto a otro
## (ida y vuelta, frenando en los extremos) y rebota la bola si choca con ella.

const Looks = preload("res://scripts/looks.gd")

var a := Vector3.ZERO
var b := Vector3.ZERO
var period := 3.0
var _t := 0.0
var _body: Node3D


func setup(p_a: Vector3, p_b: Vector3, p_period: float, phase: float, col: Color) -> void:
	a = p_a
	b = p_b
	period = p_period
	_t = phase * period
	position = a
	collision_layer = 4
	collision_mask = 0
	set_meta("kick", 1.2)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.7
	pm.friction = 0.0
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.2
	cs.shape = sh
	add_child(cs)

	_body = Node3D.new()
	add_child(_body)
	# Al chocar solo "rebota" la parte visual (escalar el cuerpo físico da problemas).
	set_meta("pop", _body)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.19
	sm.height = 0.36
	sm.radial_segments = 14
	sm.rings = 7
	orb.mesh = sm
	orb.material_override = Looks.glow(col, 1.2)
	_body.add_child(orb)
	var eye := SphereMesh.new()
	eye.radius = 1.0
	eye.height = 2.0
	eye.radial_segments = 8
	eye.rings = 4
	var dark := Looks.toon(Color(0.1, 0.1, 0.15))
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.mesh = eye
		e.material_override = dark
		e.scale = Vector3(0.028, 0.04, 0.02)
		e.position = Vector3(0.06 * sx, 0.03, -0.17)
		_body.add_child(e)
	# Estela de chispas.
	var sparks := CPUParticles3D.new()
	sparks.amount = 16
	sparks.lifetime = 0.8
	sparks.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	sparks.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	sparks.material_override = mat
	sparks.gravity = Vector3(0, 0.2, 0)
	sparks.initial_velocity_max = 0.1
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.9))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	sparks.color_ramp = grad
	add_child(sparks)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 0.6
	light.omni_range = 1.4
	add_child(light)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := 0.5 - 0.5 * cos(TAU * _t / period)
	var pos := a.lerp(b, k)
	pos.y += sin(_t * 3.0) * 0.03
	position = pos
	# Mira hacia donde va.
	var dir := (b - a) * signf(sin(TAU * _t / period))
	dir.y = 0.0
	if dir.length() > 0.01:
		_body.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
