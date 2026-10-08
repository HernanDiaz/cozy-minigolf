extends Node3D
## Golfista: una criatura redonda (personaje original) con palo de golf.
## Se coloca junto a la bola, hace el swing siguiendo la barra de fuerza y
## reacciona al resultado del hoyo. Todo con mallas sencillas y tweens.

const Looks = preload("res://scripts/looks.gd")

var body_color := Color(0.98, 0.95, 0.88)
var scarf_color := Color(0.88, 0.25, 0.2)
var leaf_color := Color(0.4, 0.72, 0.3)
var char_name := "Tú"

var _rig: Node3D           # todo el cuerpo (para saltar, aplastarse, girar)
var _swing: Node3D         # pivote del swing en las manos
var _swing_angle := 0.0
var _t := 0.0
var _busy := false         # durante una animación no se aplica el balanceo
var _tween: Tween


func _ready() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	var body_mat := Looks.toon(body_color)
	body_mat.set_shader_parameter("rim_strength", 0.3)
	var belly_mat := Looks.toon(body_color.lightened(0.35))
	var dark := Looks.toon(Color(0.12, 0.1, 0.1))
	var white := Looks.toon(Color(1, 1, 1))
	var blush := Looks.toon(Color(1.0, 0.62, 0.6))

	_ball(_rig, Vector3(0, 0.19, 0), Vector3(0.17, 0.162, 0.153), body_mat)
	_ball(_rig, Vector3(0, 0.15, -0.075), Vector3(0.11, 0.1, 0.08), belly_mat)
	# Orejas, brote en la cabeza y pies.
	for sx in [-1.0, 1.0]:
		_ball(_rig, Vector3(0.09 * sx, 0.335, 0.0), Vector3(0.048, 0.06, 0.035), body_mat)
		_ball(_rig, Vector3(0.07 * sx, 0.018, -0.03), Vector3(0.05, 0.025, 0.07), body_mat)
		# Ojos con brillo y mejillas sonrosadas.
		_ball(_rig, Vector3(0.055 * sx, 0.225, -0.142), Vector3(0.022, 0.028, 0.012), dark)
		_ball(_rig, Vector3(0.05 * sx, 0.235, -0.152), Vector3(0.007, 0.007, 0.004), white)
		_ball(_rig, Vector3(0.095 * sx, 0.18, -0.122), Vector3(0.026, 0.016, 0.01), blush)
		# Bracitos hacia las manos.
		var arm := _ball(_rig, Vector3(0.075 * sx, 0.17, -0.13), Vector3(0.028, 0.028, 0.06), body_mat)
		arm.rotation = Vector3(0.3, -0.5 * sx, 0)
	var sprout := Node3D.new()
	sprout.position = Vector3(0, 0.35, 0)
	_rig.add_child(sprout)
	_ball(sprout, Vector3(0, 0.02, 0), Vector3(0.008, 0.03, 0.008), Looks.toon(leaf_color.darkened(0.2)))
	for sx in [-1.0, 1.0]:
		var leaf := _ball(sprout, Vector3(0.03 * sx, 0.05, 0), Vector3(0.035, 0.01, 0.018),
			Looks.toon(leaf_color, 0.0, 0.3))
		leaf.rotation.z = -0.4 * sx
	var scarf := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.13
	tm.outer_radius = 0.17
	tm.rings = 16
	tm.ring_segments = 6
	scarf.mesh = tm
	scarf.material_override = Looks.toon(scarf_color)
	scarf.position.y = 0.11
	_rig.add_child(scarf)
	var tail := _ball(_rig, Vector3(0.07, 0.07, 0.13), Vector3(0.03, 0.06, 0.015), Looks.toon(scarf_color))
	tail.rotation.z = 0.3

	# Palo: manos -> pivote del swing -> inclinación hacia la bola.
	var hands := Node3D.new()
	hands.position = Vector3(0, 0.17, -0.17)
	_rig.add_child(hands)
	_swing = Node3D.new()
	hands.add_child(_swing)
	var lean := Node3D.new()
	lean.rotation.x = 0.7
	_swing.add_child(lean)
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.008
	sm.bottom_radius = 0.008
	sm.height = 0.24
	sm.radial_segments = 6
	shaft.mesh = sm
	shaft.material_override = Looks.toon(Color(0.75, 0.75, 0.78))
	shaft.position.y = -0.12
	lean.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.09, 0.03, 0.035)
	head.mesh = hm
	head.material_override = Looks.toon(Color(0.35, 0.35, 0.4))
	head.position.y = -0.245
	lean.add_child(head)
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.013
	gm.bottom_radius = 0.013
	gm.height = 0.06
	gm.radial_segments = 6
	grip.mesh = gm
	grip.material_override = Looks.toon(scarf_color.darkened(0.3))
	grip.position.y = -0.02
	lean.add_child(grip)


func _ball(parent: Node3D, pos: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = radii
	parent.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if not _busy:
		var s := 1.0 + 0.025 * sin(_t * 3.0)
		_rig.scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
	_swing.rotation.z = _swing_angle


## Se coloca junto a la bola, de cara a la línea de tiro (a su izquierda).
func stand_at(ball_pos: Vector3, aim_dir: Vector3, floor_y: float) -> void:
	var right := aim_dir.cross(Vector3.UP).normalized()
	var pos := ball_pos - right * 0.32
	pos.y = floor_y
	global_transform = Transform3D(Basis.looking_at(right, Vector3.UP), pos)


func poof() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	var q := SphereMesh.new()
	q.radius = 0.05
	q.height = 0.1
	q.radial_segments = 6
	q.rings = 3
	p.mesh = q
	p.material_override = Looks.toon(Color(1, 1, 1))
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.position.y = 0.15
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	_rig.scale = Vector3.ONE * 0.2
	_anim().tween_property(_rig, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## Swing hacia atrás proporcional a la barra de fuerza (0..1.1).
func backswing(amount: float) -> void:
	_swing_angle = clampf(amount, 0.0, 1.1) * 1.3


func strike() -> void:
	var tw := _anim()
	tw.tween_property(self, "_swing_angle", -0.9, 0.09)
	tw.tween_interval(0.35)
	tw.tween_property(self, "_swing_angle", 0.0, 0.4)


func address() -> void:
	_swing_angle = 0.0


func celebrate(big: bool) -> void:
	_busy = true
	var tw := _anim()
	var jumps := 3 if big else 2
	for i in jumps:
		tw.tween_property(_rig, "position:y", 0.22 if big else 0.14, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if big:
			tw.parallel().tween_property(_rig, "rotation:y", _rig.rotation.y + TAU, 0.36)
		tw.tween_property(_rig, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_rig, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
		tw.tween_property(_rig, "scale", Vector3.ONE, 0.08)
	tw.tween_callback(func() -> void: _busy = false)


func sad() -> void:
	_busy = true
	var tw := _anim()
	tw.tween_property(_rig, "scale", Vector3(1.12, 0.8, 1.12), 0.35)
	tw.parallel().tween_property(_rig, "rotation:x", 0.25, 0.35)
	tw.tween_interval(1.0)
	tw.tween_property(_rig, "scale", Vector3.ONE, 0.3)
	tw.parallel().tween_property(_rig, "rotation:x", 0.0, 0.3)
	tw.tween_callback(func() -> void: _busy = false)


## Bailecito de alegría (unos 1,6 s). Estilos: 0 vaivén de caderas, 1 saltos
## con giro, 2 contoneo agitando el palo, 3 pasitos de lado. -1 = al azar.
func dance(style: int = -1) -> void:
	if style < 0:
		style = randi() % 4
	_busy = true
	var tw := _anim()
	var beat := 0.2
	match style:
		0:
			for i in 8:
				var side := 1.0 if i % 2 == 0 else -1.0
				tw.tween_property(_rig, "rotation:z", 0.28 * side, beat).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(_rig, "rotation:y", 0.35 * side, beat)
				tw.parallel().tween_property(self, "_swing_angle", 0.6 * side, beat)
		1:
			for i in 3:
				tw.tween_property(_rig, "position:y", 0.2, 0.22).set_ease(Tween.EASE_OUT) \
					.set_trans(Tween.TRANS_QUAD)
				tw.parallel().tween_property(_rig, "rotation:y", (i + 1) * TAU * 0.5, 0.44)
				tw.tween_property(_rig, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN) \
					.set_trans(Tween.TRANS_QUAD)
				tw.tween_property(_rig, "scale", Vector3(1.2, 0.8, 1.2), 0.05)
				tw.tween_property(_rig, "scale", Vector3.ONE, 0.06)
		2:
			for i in 8:
				var up := i % 2 == 0
				tw.tween_property(_rig, "scale", Vector3(0.88, 1.18, 0.88) if up
					else Vector3(1.12, 0.86, 1.12), beat)
				tw.parallel().tween_property(self, "_swing_angle", -1.1 if up else 1.1, beat)
				tw.parallel().tween_property(_rig, "rotation:x", -0.12 if up else 0.1, beat)
		_:
			for i in 8:
				var side := 1.0 if (i / 2) % 2 == 0 else -1.0
				tw.tween_property(_rig, "position:x", 0.07 * side, beat).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(_rig, "rotation:z", -0.2 * side, beat)
				tw.parallel().tween_property(_rig, "position:y", 0.05 if i % 2 == 0 else 0.0, beat)
	tw.tween_property(_rig, "rotation", Vector3.ZERO, 0.15)
	tw.parallel().tween_property(_rig, "position", Vector3.ZERO, 0.15)
	tw.parallel().tween_property(_rig, "scale", Vector3.ONE, 0.15)
	tw.parallel().tween_property(self, "_swing_angle", 0.0, 0.15)
	tw.tween_callback(func() -> void: _busy = false)


func surprised() -> void:
	_busy = true
	var tw := _anim()
	tw.tween_property(_rig, "scale", Vector3(0.9, 1.2, 0.9), 0.08)
	tw.tween_property(_rig, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_callback(func() -> void: _busy = false)


func _anim() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_rig.position = Vector3.ZERO
	_rig.rotation = Vector3.ZERO
	_rig.scale = Vector3.ONE
	_tween = create_tween()
	return _tween
