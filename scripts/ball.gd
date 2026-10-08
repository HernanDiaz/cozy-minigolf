extends RigidBody3D
## Bola de minigolf. La rodadura se calcula a mano (rozamiento de rodadura
## constante y 5/7 de la gravedad en pendiente, como una esfera maciza que
## rueda) para que los tiros sean previsibles; Jolt se encarga de los choques.

const Looks = preload("res://scripts/looks.gd")

signal stopped
signal hit_wall(speed: float)
signal bumped(body: Node)

const RADIUS := 0.085
const ROLL_DECEL := 1.3
const SAND_DECEL := 4.5
const ICE_DECEL := 0.3
const SNOW_DECEL := 3.2
const CURVE_ACCEL := 1.5      # golpe con efecto: empuje lateral mientras rueda
const HOP_UP := 2.6           # golpe saltarín: velocidad hacia arriba del bote
const BRAKE_DECEL := 7.0      # golpe con freno
const BRAKE_TIME := 1.2
const SPIN_ACCEL := 1.8
const SPIN_TIME := 0.9
const STOP_SPEED := 0.06

var moving := false
var grounded := false
var surface := "grass"
var visual: Node3D
var _still := 0.0
var _move_time := 0.0
var _spin_sign := 0.0
var _spin_time := 0.0
var _pending_vel := Vector3.ZERO
var _has_pending := false
var _lip := false
var external_accel := Vector3.ZERO
## Golpe con efecto: +1 curva a la derecha, -1 a la izquierda, 0 sin efecto.
var curve_side := 0.0
var _brake_time := 0.0
var airtime := 0.0
var _body_mat: ShaderMaterial
var _stripe_mat: ShaderMaterial
var _trail: CPUParticles3D


func _ready() -> void:
	mass = 0.2
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.02
	collision_layer = 8
	# Las bolas no chocan entre sí por física: ese choque lo calcula main.gd.
	collision_mask = 1 | 2 | 4 | 16
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	physics_material_override = pm
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)

	visual = Node3D.new()
	add_child(visual)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var white := Looks.toon(Color(0.98, 0.97, 0.94))
	_body_mat = white
	white.set_shader_parameter("rim_strength", 0.35)
	mi.material_override = white
	visual.add_child(mi)
	# Franja de color para que se vea girar al rodar.
	var stripe := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS * 0.93
	tm.outer_radius = RADIUS * 1.02
	tm.rings = 16
	tm.ring_segments = 4
	stripe.mesh = tm
	_stripe_mat = Looks.toon(Color(0.9, 0.25, 0.18))
	stripe.material_override = _stripe_mat
	visual.add_child(stripe)

	body_entered.connect(_on_body_entered)

	# Estela de brillos cuando va rápida.
	_trail = CPUParticles3D.new()
	_trail.amount = 28
	_trail.lifetime = 0.35
	_trail.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	_trail.mesh = q
	var tm2 := StandardMaterial3D.new()
	tm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	tm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm2.vertex_color_use_as_albedo = true
	_trail.material_override = tm2
	_trail.direction = Vector3.UP
	_trail.spread = 180.0
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.1
	_trail.gravity = Vector3.ZERO
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 0.85, 0.8))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	_trail.color_ramp = grad
	_trail.emitting = false
	add_child(_trail)


## Color de la bola y de su franja (cada jugador tiene el suyo).
func set_colors(body: Color, stripe: Color) -> void:
	_body_mat.set_shader_parameter("albedo", body)
	_stripe_mat.set_shader_parameter("albedo", stripe)


## Otra bola la ha golpeado: deja de estar quieta y sale con esa velocidad.
func wake(v: Vector3) -> void:
	freeze = false
	moving = true
	_still = 0.0
	_move_time = 0.0
	_spin_time = 0.0
	set_velocity(v)


func set_stripe(col: Color) -> void:
	_stripe_mat.set_shader_parameter("albedo", col)


## Cambia la velocidad mientras rueda (plataformas de salto, tuberías).
func set_velocity(v: Vector3) -> void:
	_pending_vel = v
	_has_pending = true


func shoot(vel: Vector3) -> void:
	freeze = false
	_pending_vel = vel
	_has_pending = true
	moving = true
	_still = 0.0
	_move_time = 0.0
	_spin_time = 0.0


func halt() -> void:
	moving = false
	_still = 0.0
	_spin_time = 0.0
	_brake_time = 0.0
	curve_side = 0.0
	airtime = 0.0
	_has_pending = false
	external_accel = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	freeze = true


func place(pos: Vector3) -> void:
	halt()
	global_position = pos
	# Un cuerpo congelado tarda un fotograma en recibir la nueva posición; se
	# fuerza en el motor de física para que un disparo inmediato (tuberías,
	# portales) salga desde aquí y no desde el sitio anterior.
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
		global_transform)


## Efecto lateral durante la rodadura (+1 derecha, -1 izquierda).
func apply_spin(side: float) -> bool:
	if not moving or Vector2(linear_velocity.x, linear_velocity.z).length() < 0.4:
		return false
	_spin_sign = side
	_spin_time = SPIN_TIME
	return true


## Golpe saltarín: un bote en seco mientras rueda (pasa por encima de vallas,
## huecos y espíritus). Solo si va por el suelo.
func hop() -> bool:
	if not moving or airtime > 0.08:
		return false
	var v := linear_velocity
	set_velocity(Vector3(v.x, HOP_UP, v.z))
	return true


## Golpe con freno: la bola se agarra al suelo y se para en muy poco espacio.
func brake() -> bool:
	if not moving:
		return false
	_brake_time = BRAKE_TIME
	curve_side = 0.0
	return true


## La bola ha pasado rozando el hoyo demasiado rápido: sale desviada.
func lip_out() -> void:
	_lip = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _has_pending:
		state.linear_velocity = _pending_vel
		_has_pending = false
		return
	var dt := state.step
	var v := state.linear_velocity
	grounded = false
	var n_sum := Vector3.ZERO
	var surf := "grass"
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		if n.y > 0.45:
			grounded = true
			n_sum += n
			var obj := state.get_contact_collider_object(i)
			if obj and obj.has_meta("surface"):
				surf = obj.get_meta("surface")
	surface = surf

	if _lip:
		_lip = false
		var ang := randf_range(0.35, 0.7) * (1.0 if randf() < 0.5 else -1.0)
		v = v.rotated(Vector3.UP, ang) * 0.7

	if grounded:
		var n := n_sum.normalized()
		# Una esfera maciza que rueda solo acelera 5/7 de lo que desliza.
		var g := state.total_gravity
		var g_t := g - n * g.dot(n)
		v -= g_t * (2.0 / 7.0) * dt
		var v_t := v - n * v.dot(n)
		var sp := v_t.length()
		var decel := decel_of(surface)
		if _brake_time > 0.0:
			decel += BRAKE_DECEL
		if sp > 0.00001:
			v -= v_t * (minf(sp, decel * dt) / sp)
		if _spin_time > 0.0 and sp > 0.3:
			var side := (v_t / sp).cross(n) * _spin_sign
			v += side * SPIN_ACCEL * dt
		if curve_side != 0.0 and sp > 0.3:
			v += (v_t / sp).cross(n) * curve_side * CURVE_ACCEL * dt
	if _brake_time > 0.0:
		_brake_time -= dt
	if _spin_time > 0.0:
		_spin_time -= dt
	airtime = 0.0 if grounded else airtime + dt
	v += external_accel * dt
	state.linear_velocity = v


## Frenada de rodadura de cada superficie (m/s²).
static func decel_of(surf: String) -> float:
	match surf:
		"sand":
			return SAND_DECEL
		"ice":
			return ICE_DECEL
		"snow":
			return SNOW_DECEL
	return ROLL_DECEL


func _physics_process(delta: float) -> void:
	if not moving:
		return
	_move_time += delta
	if grounded and linear_velocity.length() < STOP_SPEED:
		_still += delta
	else:
		_still = 0.0
	if _still > 0.2 or _move_time > 30.0:
		halt()
		stopped.emit()


func _process(delta: float) -> void:
	_trail.emitting = moving and linear_velocity.length() > 1.2
	if not moving:
		return
	var v := linear_velocity
	v.y = 0.0
	var sp := v.length()
	if sp < 0.001:
		return
	var axis := Vector3.UP.cross(v / sp)
	visual.basis = (Basis(axis, sp * delta / RADIUS) * visual.basis).orthonormalized()


func _on_body_entered(body: Node) -> void:
	if body.has_meta("kick") and moving:
		# Seta rebotadora: empuja la bola hacia fuera con fuerza.
		var d := global_position - (body as Node3D).global_position
		d.y = 0.0
		var v := linear_velocity
		v.y = 0.0
		set_velocity(d.normalized() * maxf(v.length(), 1.0) + d.normalized() * float(body.get_meta("kick")))
		bumped.emit(body)
	elif body.has_meta("kind"):
		hit_wall.emit(linear_velocity.length())

