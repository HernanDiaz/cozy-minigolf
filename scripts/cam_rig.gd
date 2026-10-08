extends Camera3D
## Cámara con varios modos: detrás de la bola para apuntar (como en Neo Turf
## Masters), siguiendo la bola, vista general del hoyo, primer plano del hoyo
## cuando la bola llega (con cámara lenta) y plano del personaje al celebrar.

enum Mode { AIM, FOLLOW, TOP, CUP, CHAR }

var mode := Mode.TOP
var ball: Node3D
var cup := Vector3.ZERO
var focus: Node3D            # personaje para el modo CHAR
var char_shift := 0.0         # desplaza el personaje a la izquierda de la pantalla (m)
var aim_dir := Vector3.FORWARD
var follow_dir := Vector3.FORWARD
var smooth := 5.0
var _top_pos := Vector3(0, 10, 0)
var _top_target := Vector3.ZERO
var _top_up := Vector3.FORWARD
var _pos := Vector3.ZERO
var _look := Vector3.FORWARD
var _up := Vector3.UP
var _shake := 0.0
var _cup_side := Vector3.FORWARD


func _ready() -> void:
	fov = 55.0
	near = 0.05
	far = 250.0


## Calcula una vista cenital inclinada que encuadre todo el hoyo, con el
## lado largo del hoyo a lo ancho de la pantalla apaisada.
func setup_top(bounds: AABB) -> void:
	var size := bounds.size
	var center := bounds.get_center()
	var up_dir := Vector3(0, 0, -1)
	var lx := size.x
	var ly := size.z
	if size.z >= size.x:
		up_dir = Vector3(-1, 0, 0)
		lx = size.z
		ly = size.x
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var t := tan(deg_to_rad(fov * 0.5))
	var d := maxf((ly * 0.5 + 0.9) / t, (lx * 0.5 + 0.9) / (t * aspect))
	_top_target = center
	_top_pos = center + Vector3.UP * d * 0.94 - up_dir * d * 0.34
	_top_up = up_dir


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Primer plano del hoyo: la cámara se pone al otro lado, baja, mirando
## cómo llega la bola.
func watch_cup(cup_pos: Vector3) -> void:
	cup = cup_pos
	var d := cup - ball.global_position
	d.y = 0.0
	_cup_side = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	mode = Mode.CUP


func snap() -> void:
	var t := _targets()
	_pos = t[0]
	_look = t[1]
	_up = t[2]
	_apply()


func _targets() -> Array:
	if mode == Mode.TOP or ball == null:
		return [_top_pos, _top_target, _top_up]
	var b := ball.global_position
	match mode:
		Mode.AIM:
			# Algo desplazada a la derecha para que se vea al personaje.
			var right := aim_dir.cross(Vector3.UP)
			return [b - aim_dir * 2.2 + right * 0.25 + Vector3.UP * 1.1, b + aim_dir * 2.2,
				Vector3.UP]
		Mode.CUP:
			var side := _cup_side.cross(Vector3.UP) * 0.35
			return [cup + _cup_side * 1.1 + side + Vector3.UP * 0.42, (cup * 0.65 + b * 0.35),
				Vector3.UP]
		Mode.CHAR:
			if focus:
				var f := -focus.global_transform.basis.z
				var p := focus.global_position
				return [p + f * 1.3 + f.cross(Vector3.UP) * 0.4 + Vector3.UP * 0.55,
					p + Vector3.UP * 0.22 + (-f).cross(Vector3.UP) * char_shift, Vector3.UP]
	return [b - follow_dir * 2.8 + Vector3.UP * 1.9, b + follow_dir * 0.8, Vector3.UP]


func _process(delta: float) -> void:
	if mode == Mode.FOLLOW and ball is RigidBody3D:
		var v: Vector3 = (ball as RigidBody3D).linear_velocity
		v.y = 0.0
		if v.length() > 0.4:
			follow_dir = follow_dir.slerp(v.normalized(), 1.0 - exp(-2.0 * delta)).normalized()
	var t := _targets()
	# La cámara reacciona igual aunque el juego vaya a cámara lenta.
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	var k := 1.0 - exp(-smooth * real_dt)
	_pos = _pos.lerp(t[0], k)
	_look = _look.lerp(t[1], k)
	_up = _up.lerp(t[2], k).normalized()
	_shake = maxf(0.0, _shake - real_dt * 1.8)
	_apply()


func _apply() -> void:
	var offset := Vector3.ZERO
	if _shake > 0.0:
		offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.06
	global_position = _pos + offset
	var fwd := _look - _pos
	if fwd.length() < 0.001:
		return
	var up := _up
	if absf(fwd.normalized().dot(up)) > 0.98:
		up = Vector3(0, 0, -1) if absf(fwd.normalized().z) < 0.9 else Vector3.RIGHT
	look_at(_look + offset, up)
