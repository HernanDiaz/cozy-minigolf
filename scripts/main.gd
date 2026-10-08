extends Node3D
## Controlador del juego: menú, hoyos, golpe en tres toques al estilo Neo Turf
## Masters (empezar, fijar la fuerza y acertar la precisión), turnos alternos
## contra el rival de la CPU (cada uno con su bola, que pueden chocar entre sí),
## juguetes del recorrido, comentarista, estrellas y tarjeta.

const Holes = preload("res://scripts/holes.gd")
const HoleBuilder = preload("res://scripts/hole_builder.gd")
const Ball = preload("res://scripts/ball.gd")
const CamRig = preload("res://scripts/cam_rig.gd")
const Hud = preload("res://scripts/hud.gd")
const SlopeGrid = preload("res://scripts/slope_grid.gd")
const WorldDecor = preload("res://scripts/world_decor.gd")
const Character = preload("res://scripts/character.gd")
const Looks = preload("res://scripts/looks.gd")

enum State { MENU, INTRO, AIM, POWER, ACCURACY, ROLLING, PIPE, SINKING, PENALTY, TURN_DONE,
	DANCE, WATCH, FINISHED }

const MAX_DIST := 14.0        # metros que rueda un tiro al 100 % en llano
const MAX_STROKES := 7        # al llegar aquí sin embocar se anotan 8
const POWER_RISE := 0.7       # velocidad de la barra (unidades por segundo)
const POWER_MAX := 1.1        # la barra llega al 110 % (zona roja)
const DEBOUNCE_MS := 250      # ignora una pulsación demasiado seguida
const ACC_SPEED := 0.5        # velocidad de la marca al buscar la precisión
const ACC_ZONE := 0.07        # franja de precisión (± sobre la línea roja)
const ACC_PERFECT := 0.015    # parte perfecta de la franja
const GUIDE_DIST := 4.0       # la guía de fuerza solo aparece cerca del hoyo
const AIM_SPEED := 0.6        # rad/s con los botones o las flechas
const DRAG_AIM := 0.0045      # rad por píxel arrastrado
const SINK_SPEED := 1.35      # por debajo de esta velocidad la bola entra
const LIP_SPEED := 2.2        # entre SINK y LIP la bola escupe del hoyo
const SLOWMO := 0.35          # cámara lenta cuando la bola llega al hoyo
const SKIP_SPEED := 4.0       # velocidad al saltar el turno del rival
const SAVE_PATH := "user://progreso.cfg"
## Golpes especiales: se desbloquean al reunir estrellas y cada jugador puede
## usar cada uno unas pocas veces por hoyo.
const SPECIALS := [
	{"id": "curve", "stars": 4, "uses": 2},
	{"id": "hop", "stars": 10, "uses": 2},
	{"id": "brake", "stars": 18, "uses": 2},
]
const CURVE_PREVIEW := 0.32   # rad por metro en la curva que dibuja la mira
# Idiomas disponibles ("" = el del móvil). Cada uno tiene su columna en
# locale/translations.csv.
const LANGUAGES := ["", "en", "es", "pt_BR", "fr", "de", "it", "ru", "tr", "id", "vi", "hi", "ar",
	"ja", "ko", "zh_CN"]

var db
var world := 0
var holes: Array = []
var hole_index := 0
var duel := true
# Cada jugador: {name, color, ball_color, char, ball, cpu, scores} y, durante el
# hoyo, {strokes, done, started, last_rest}.
var players: Array = []
var cur := 0
var strokes := 0
var state := State.MENU
var info := {}
var builder
var course: Node3D
var ball
var cam
var hud
var grid
var aim_dots: Array[MeshInstance3D] = []
var aim_yaw := 0.0
var top_view := false
var meter := 0.0
var meter_dir := 1.0
var power := 0.0
var power_guide := -1.0
var swing_start_ms := 0
var waiting_release := false
var last_rest := Vector3.ZERO
var spin_left := 1
var drag_accum := 0.0
var lip_cooldown := 0.0
var flow := 0
var seeds_got := 0
var seeds_total := 0
var shot_start := Vector3.ZERO
var min_cup_dist := INF
var flew := false
var slowmo := false
var skipping := false
var cpu_power := 0.0
var cpu_acc := 0.0
var _prev_meter := 0.0
var autotest := false
var shot_dir := ""
var _shots_taken := {}
var language := ""
var decor
var unlock_all := false
var start_world := 0
var start_hole := 0
var hole_serial := 0          # cambia en cada hoyo (para esperas que no deben seguir)
var transit := 0              # bolas dentro de una tubería o portal
var hit_rival := false        # el tiro actual ha golpeado la bola del rival
var special := ""             # golpe elegido: "", curve_l, curve_r, hop o brake
var special_armed := ""       # salto o freno listos para usar mientras rueda
var specials_open: Array = [] # golpes especiales desbloqueados
# --- Duelo por Wi-Fi ---
var online := false           # partida contra otra persona por Wi-Fi
var hotseat := false          # dos personas en el mismo móvil, por turnos
var me_idx := 0               # puesto de este móvil (0 anfitrión, 1 invitado)
var lobby_status := ""
var lobby_world := 0
var net_targets := {}         # puesto -> posición recibida de su bola
var _net_tick := 0
var _aim_tick := 0.0
var net_host_auto := false
var net_join_ip := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	language = str(_cfg().get_value("settings", "language", ""))
	_apply_language()
	db = Holes.new()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a == "--unlock-all":
			unlock_all = true
		elif a.begins_with("--hole="):
			start_hole = int(a.substr(7)) - 1
		elif a.begins_with("--world="):
			start_world = int(a.substr(8))
		elif a == "--hotseat":
			hotseat = true
		elif a == "--net-host":
			net_host_auto = true
		elif a.begins_with("--net-join="):
			net_join_ip = a.substr(11)
		elif a.begins_with("--lang="):
			language = a.substr(7)
			_apply_language()
	decor = WorldDecor.new()
	add_child(decor)
	_make_players()
	ball = players[0]["ball"]
	cam = CamRig.new()
	cam.ball = ball
	add_child(cam)
	cam.make_current()
	grid = SlopeGrid.new()
	add_child(grid)
	_make_aim_dots()
	hud = Hud.new()
	add_child(hud)
	hud.action.connect(_on_action)
	hud.action_released.connect(_on_action_released)
	hud.view_toggled.connect(_on_view)
	hud.special_toggled.connect(_on_special)
	hud.skip_pressed.connect(_on_skip)
	hud.play_pressed.connect(_on_play)
	hud.play_hotseat.connect(func(w: int) -> void: _on_play(true, w, true))
	hud.restart.connect(_on_restart)
	hud.menu_pressed.connect(_show_menu)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.quit_pressed.connect(_quit_to_menu)
	hud.language_pressed.connect(_open_language_picker)
	hud.language_chosen.connect(_set_language)
	hud.wifi_pressed.connect(_open_lobby)
	hud.quit_game_pressed.connect(func() -> void:
		Net.leave()
		get_tree().quit())
	hud.lobby_host.connect(_on_lobby_host)
	hud.lobby_join.connect(_on_lobby_join)
	hud.lobby_start.connect(_on_lobby_start)
	hud.lobby_back.connect(_on_lobby_back)
	Net.players_changed.connect(_refresh_lobby)
	Net.games_changed.connect(_refresh_lobby)
	Net.joined.connect(_refresh_lobby)
	Net.left.connect(_on_net_left)
	Net.game_started.connect(_start_online)
	Net.aim_received.connect(_on_net_aim)
	Net.balls_received.connect(_on_net_balls)
	Net.event_received.connect(_on_net_event)
	Net.sync_received.connect(_on_net_sync)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	if autotest:
		Engine.time_scale = 3.0
		# Por si algo se atasca, la prueba nunca dura más de 20 minutos de juego.
		get_tree().create_timer(1200.0).timeout.connect(func() -> void:
			print("AUTOTEST: tiempo agotado")
			get_tree().quit(1))
		if net_host_auto:
			# Prueba en red: crea la sala y empieza en cuanto entra el otro.
			Net.host("Anfitrion")
			Net.players_changed.connect(func() -> void:
				if Net.players.size() == 2 and not Net.in_game:
					Net.start_game(start_world))
		elif net_join_ip != "":
			Net.join(net_join_ip, "Invitado")
		else:
			_on_play(true, start_world, hotseat)
	else:
		_show_menu()
		if shot_dir != "":
			# Captura del menú para revisar las traducciones.
			if "--picker" in OS.get_cmdline_user_args():
				_open_language_picker()
			await get_tree().create_timer(2.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				shot_dir.path_join("menu_%s.png" % TranslationServer.get_locale()))
			get_tree().quit()


func _make_players() -> void:
	var me := Character.new()
	me.char_name = tr("NAME_YOU")
	add_child(me)
	var kaze := Character.new()
	kaze.char_name = "Kaze"
	kaze.body_color = Color(0.72, 0.8, 0.92)
	kaze.scarf_color = Color(0.95, 0.78, 0.2)
	kaze.leaf_color = Color(0.95, 0.6, 0.25)
	add_child(kaze)
	players = [
		{"name": tr("NAME_YOU"), "color": Color(0.9, 0.25, 0.18), "char": me, "cpu": false,
			"remote": false,
			"ball_color": Color(0.98, 0.97, 0.94), "stripe": Color(0.9, 0.25, 0.18), "scores": []},
		{"name": "Kaze", "color": Color(0.95, 0.72, 0.15), "char": kaze, "cpu": true,
			"remote": false,
			"ball_color": Color(1.0, 0.85, 0.3), "stripe": Color(0.35, 0.5, 0.8), "scores": []},
	]
	for q in players:
		var b := Ball.new()
		b.name = "Ball_" + str(q["cpu"])
		add_child(b)
		b.set_colors(q["ball_color"], q["stripe"])
		b.visible = false
		b.stopped.connect(_on_ball_stopped.bind(q))
		b.hit_wall.connect(_on_wall_hit)
		b.bumped.connect(_on_bumped)
		q["ball"] = b


func _make_aim_dots() -> void:
	var m := SphereMesh.new()
	m.radius = 0.022
	m.height = 0.044
	m.radial_segments = 8
	m.rings = 4
	for i in 9:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 1.0 - i * 0.09)
		var d := MeshInstance3D.new()
		d.mesh = m
		d.material_override = mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		add_child(d)
		aim_dots.append(d)


# --- Menú ----------------------------------------------------------------------

func _show_menu() -> void:
	if online or Net.is_online():
		Net.leave()
		online = false
	hud.hide_lobby()
	flow += 1
	cam.char_shift = 0.0
	state = State.MENU
	Engine.time_scale = 1.0
	holes = db.world_holes(0)
	decor.set_theme(0)
	Music.play_track(0)
	_build_course(holes[0])
	for p in players:
		p["char"].visible = false
		_park(p["ball"])
	cam.mode = CamRig.Mode.TOP
	cam.snap()
	grid.visible = false
	_hide_aim()
	var counts := []
	for w in Holes.WORLDS.size():
		counts.append(_world_stars(w) if not db.world_holes(w).is_empty() else -1)
	var total := _total_stars()
	var sp := []
	for s in SPECIALS:
		sp.append({"name": "SP_NAME_" + str(s["id"]).to_upper(), "stars": s["stars"],
			"open": unlock_all or total >= int(s["stars"])})
	hud.show_menu(Holes.WORLDS, counts, total, _language_text(), unlock_all, sp)


func _on_play(p_duel: bool, p_world: int = 0, p_hotseat: bool = false) -> void:
	duel = p_duel
	hotseat = p_hotseat
	online = false
	me_idx = 0
	players[0]["name"] = tr("NAME_YOU")
	players[0]["remote"] = false
	players[1]["name"] = "Kaze"
	players[1]["cpu"] = true
	players[1]["remote"] = false
	if hotseat:
		# Dos personas en el mismo móvil: el segundo personaje ya no es Kaze.
		players[0]["name"] = tr("PLAYER_N") % 1
		players[1]["name"] = tr("PLAYER_N") % 2
		players[1]["cpu"] = false
	world = p_world
	holes = db.world_holes(world)
	decor.set_theme(world)
	Music.play_track(world)
	hud.hide_menu()
	hud.hide_scorecard()
	for p in players:
		p["scores"] = []
	hole_index = start_hole if autotest else 0
	_update_total()
	_load_hole(hole_index)


# --- Flujo de la partida ---------------------------------------------------

func _active_players() -> Array:
	return players if duel else [players[0]]


func _player() -> Dictionary:
	return _active_players()[cur]


func _build_course(data: Dictionary) -> void:
	if course:
		course.queue_free()
	builder = HoleBuilder.new()
	info = builder.build(data)
	course = info["root"]
	add_child(course)
	for t in info["triggers"]:
		(t["area"] as Area3D).body_entered.connect(_on_trigger.bind(t))
	cam.setup_top(info["bounds"])


func _load_hole(i: int) -> void:
	flow += 1
	cam.char_shift = 0.0
	hole_serial += 1
	transit = 0
	var my := flow
	var data: Dictionary = holes[i]
	_build_course(data)
	specials_open = _open_specials()
	seeds_got = 0
	seeds_total = 0
	for t in info["triggers"]:
		if t["type"] == "seed":
			seeds_total += 1
	cur = 0
	var act := _active_players()
	for k in act.size():
		var q: Dictionary = act[k]
		q["strokes"] = 0
		q["done"] = false
		q["started"] = false
		q["last_rest"] = _tee_spot(k, act.size())
		q["uses"] = {}
		for s in SPECIALS:
			q["uses"][s["id"]] = s["uses"]
	for p in players:
		p["char"].visible = false
		_park(p["ball"])
	grid.visible = false
	_hide_aim()
	cam.mode = CamRig.Mode.TOP
	cam.snap()
	hud.set_hole(i + 1, holes.size(), data["name"])
	hud.set_strokes(_player()["name"], 0, data["par"])
	hud.set_seeds(0, seeds_total)
	hud.set_turn("")
	hud.set_phase("intro")
	var sub: String = tr("MSG_HOLE_SUB") % [tr(data["name"]), data["par"]]
	if duel and not online and not hotseat:
		sub += "\n" + tr("KAZE_LEVEL") % _kaze_level()
	hud.show_message(tr("MSG_HOLE") % (i + 1), sub, Color.WHITE, 2.0)
	state = State.INTRO
	_screenshot("intro")
	await get_tree().create_timer(0.15 if autotest and shot_dir == "" else 2.4, false).timeout
	if my != flow:
		return
	_begin_turn()


## Cada jugador sale desde un lado de la alfombrilla, para que las bolas no
## aparezcan una encima de otra.
func _tee_spot(k: int, n: int) -> Vector3:
	var off := (k - (n - 1) * 0.5) * 0.22
	var t: Vector3 = info["tee"] + Vector3(off, 0, 0)
	return Vector3(t.x, builder.h(t.x, t.z) + Ball.RADIUS + 0.004, t.z)


## Retira una bola del campo (antes de salir o después de embocar).
func _park(b) -> void:
	b.place(Vector3(0, -60, 0))
	b.visible = false


func _begin_turn() -> void:
	var p := _player()
	if online and p["remote"]:
		_watch()
		return
	net_targets.clear()
	var changed: bool = ball != p["ball"]
	ball = p["ball"]
	cam.ball = ball
	strokes = p["strokes"]
	last_rest = p["last_rest"]
	top_view = false
	skipping = false
	special = ""
	special_armed = ""
	hud.roll_action = ""
	Engine.time_scale = 3.0 if autotest else 1.0
	_show_special()
	if not p["started"]:
		p["started"] = true
		ball.visible = true
		ball.place(last_rest)
	for q in players:
		q["char"].visible = false
	p["char"].visible = true
	grid.setup(builder)
	hud.set_strokes(p["name"], strokes, holes[hole_index]["par"])
	var turn := tr("HUD_TURN") % str(p["name"]).to_upper() if p["cpu"] or hotseat \
		else tr("HUD_YOUR_TURN")
	hud.set_turn(turn if duel else "")
	hud.set_seeds(seeds_got, seeds_total)
	if duel and (changed or strokes == 0):
		hud.shout(turn, p["color"])
	_enter_aim()


## Pasa el turno al siguiente jugador que aún no ha embocado (en solitario,
## al mismo). Si ya han terminado todos, se cierra el hoyo.
func _next_turn() -> void:
	var act := _active_players()
	for k in range(1, act.size() + 1):
		var idx := (cur + k) % act.size()
		if not act[idx]["done"]:
			cur = idx
			if online:
				# El otro móvil recibe el estado y, si le toca, empieza su turno.
				Net.send_sync(_sync_data())
				Net.send_event("turn", [idx])
			_begin_turn()
			return
	_hole_complete()


func _enter_aim() -> void:
	state = State.AIM
	waiting_release = false
	var p := _player()
	aim_yaw = _yaw_to(_auto_target())
	cam.aim_dir = _dir(aim_yaw)
	cam.mode = CamRig.Mode.TOP if top_view else CamRig.Mode.AIM
	grid.visible = not p["cpu"]
	meter = 0.0
	_update_guide()
	hud.set_phase("cpu" if p["cpu"] else "aim")
	hud.set_distance(_flat_dist(ball.global_position, info["cup"]))
	hud.set_shot(_shot_text(0.0))
	var ch = p["char"]
	ch.address()
	_update_aim()
	ch.poof()
	Sfx.play("poof", -12.0)
	_screenshot("aim")
	if p["cpu"]:
		_cpu_think()
	elif autotest:
		_auto_shot()


func _on_action() -> void:
	# Solo cuenta una pulsación nueva: si el mismo clic llega dos veces (ratón
	# y toque a la vez) o se mantiene pulsado, no avanza.
	if waiting_release or not _local_turn():
		return
	waiting_release = true
	_press()


func _press() -> void:
	match state:
		State.AIM:
			state = State.POWER
			swing_start_ms = Time.get_ticks_msec()
			meter = 0.0
			_prev_meter = 0.0
			meter_dir = 1.0
			hud.set_phase("cpu" if _player()["cpu"] else "power")
			_hide_aim()
			Sfx.play("tick", -6.0)
		State.POWER:
			# Un doble clic (o el rebote de un ratón) no debe fijar la fuerza al instante.
			if _too_soon():
				return
			power = maxf(meter, 0.02)
			_prev_meter = meter
			swing_start_ms = Time.get_ticks_msec()
			state = State.ACCURACY
			hud.set_phase("cpu" if _player()["cpu"] else "accuracy")
			Sfx.play("tick", -6.0, 1.25)
		State.ACCURACY:
			if _too_soon():
				return
			_strike()
		State.ROLLING:
			_trigger_special()


## En el tercer toque la marca va más despacio abajo del todo (así se puede
## acertar la línea roja de un golpe suave) y acelera poco a poco hasta su
## velocidad normal a partir de la mitad. La barra de fuerza no cambia.
func _meter_speed(m: float) -> float:
	var k := clampf(m / 0.55, 0.0, 1.0)
	return lerpf(0.3, 1.0, k * k * (3.0 - 2.0 * k))


## Un doble clic (o el rebote de un ratón) no debe avanzar dos pasos de golpe.
## Kaze no necesita esta protección.
func _too_soon() -> bool:
	if _player()["cpu"]:
		return false
	return Time.get_ticks_msec() - swing_start_ms < DEBOUNCE_MS / Engine.time_scale


func _strike() -> void:
	# Precisión: distancia entre la marca y la línea roja al dar el tercer toque.
	# Por encima de la línea la bola se va a la izquierda; por debajo, a la
	# derecha (como el medidor de precisión de Neo Turf Masters).
	var err := meter - power
	var aerr := absf(err)
	var ang := 0.0
	var label := tr("ACC_PERFECT")
	var col := Color(1, 0.9, 0.3)
	if aerr > ACC_PERFECT and aerr <= ACC_ZONE:
		ang = 1.0 + 3.0 * (aerr - ACC_PERFECT) / (ACC_ZONE - ACC_PERFECT)
		label = tr("ACC_GOOD")
		col = Color(0.6, 1, 0.6)
	elif aerr > ACC_ZONE:
		ang = minf(4.0 + (aerr - ACC_ZONE) * 60.0, 15.0)
		label = "<  " + tr("ACC_OFF") if err > 0.0 else tr("ACC_OFF") + "  >"
		col = Color(1, 0.6, 0.4)
	ang *= 1.0 if err > 0.0 else -1.0
	# Zona roja (100-110 %): más fuerza, pero se añade un desvío al azar.
	if power > 1.0:
		var over := (power - 1.0) / (POWER_MAX - 1.0)
		ang += randf_range(2.0, 2.0 + 7.0 * over) * (1.0 if randf() < 0.5 else -1.0)
		label = tr("ACC_TOO_STRONG")
		col = Color(1, 0.5, 0.35)
	var yaw := aim_yaw + deg_to_rad(ang)
	var p := power
	var v := sqrt(2.0 * Ball.ROLL_DECEL * p * MAX_DIST)
	var dir := _dir(yaw)
	var vel := dir * v

	strokes += 1
	_player()["strokes"] = strokes
	hud.set_strokes(_player()["name"], strokes, holes[hole_index]["par"])
	if not autotest:
		hud.flash(label, col)
	Sfx.play("hit", linear_to_db(0.35 + 0.4 * p), 0.95 + 0.15 * (1.0 - p))
	_player()["char"].strike()
	Net.send_event("strike", [cur, p])
	cam.shake(0.25 + p * 0.5)
	_puff(ball.global_position)
	last_rest = ball.global_position
	shot_start = ball.global_position
	min_cup_dist = INF
	flew = false
	hit_rival = false
	ball.shoot(vel)
	special_armed = ""
	hud.roll_action = ""
	if special.begins_with("curve"):
		ball.curve_side = 1.0 if special == "curve_r" else -1.0
		_use_special("curve")
		_shout_key("SHOUT_CURVE", Color(0.6, 0.9, 1))
	elif special != "":
		special_armed = special
		hud.roll_action = tr("BTN_HOP") if special == "hop" else tr("BTN_BRAKE")
	special = ""
	state = State.ROLLING
	spin_left = 1
	drag_accum = 0.0
	cam.follow_dir = dir
	cam.mode = CamRig.Mode.TOP if top_view else CamRig.Mode.FOLLOW
	grid.visible = false
	_hide_aim()
	hud.set_phase("cpu" if _player()["cpu"] else "rolling")


func _physics_process(delta: float) -> void:
	if lip_cooldown > 0.0:
		lip_cooldown -= delta
	if state == State.MENU or info.is_empty():
		return
	var c: Vector3 = info["cup"]
	_ball_collisions()
	# Todas las bolas en movimiento (la del turno y las que ha golpeado).
	for q in _active_players():
		var b = q["ball"]
		if q["done"] or not b.visible or not b.moving:
			continue
		var pos: Vector3 = b.global_position
		var wind := Vector3.ZERO
		for w in info["winds"]:
			wind += w.accel_at(pos)
		b.external_accel = wind
		if b == ball and state != State.ROLLING:
			continue
		if pos.y < info["min_h"] - 0.35:
			if b == ball:
				_penalty(builder.tile_at(pos.x, pos.z) == "~")
				return
			_restore_knocked(q, builder.tile_at(pos.x, pos.z) == "~")
			continue
		var dh := Vector2(pos.x - c.x, pos.z - c.z).length()
		var sp: float = b.linear_velocity.length()
		if dh < HoleBuilder.CUP_R + 0.01 and pos.y < c.y + Ball.RADIUS + 0.1:
			if sp < SINK_SPEED:
				if b == ball:
					_sink()
					return
				_knocked_in(q)
				continue
			elif sp < LIP_SPEED and dh < HoleBuilder.CUP_R and lip_cooldown <= 0.0:
				lip_cooldown = 0.5
				b.lip_out()
				_shout_key("SHOUT_LIP", Color(1, 0.7, 0.4))
				Sfx.play("ooh", -4.0)
		if b != ball:
			continue
		min_cup_dist = minf(min_cup_dist, dh)
		if not flew and ball.airtime > 0.45:
			flew = true
			_shout_key("SHOUT_FLY", Color(0.6, 0.9, 1))
			Sfx.play("whoosh")
		# Cámara lenta cuando la bola se acerca al hoyo con opciones de entrar.
		var toward: float = ball.linear_velocity.dot((c - pos).normalized())
		if not slowmo and dh < 1.1 and dh > 0.2 and sp < 3.0 and toward > 0.3 and not skipping \
				and not autotest:
			_set_slowmo(true)
		elif slowmo and (dh > 1.5 or sp < 0.15):
			_set_slowmo(false)
	# En línea, durante tu turno, el otro móvil recibe las bolas unas 30 veces por segundo.
	if online and _local_turn() and state != State.WATCH:
		_net_tick += 1
		if _net_tick % 4 == 0:
			Net.send_balls(_ball_states())
	# El tiro termina cuando se han parado todas las bolas.
	if state == State.ROLLING and not ball.moving and transit == 0 and not _any_moving():
		_shot_over()


## Choque entre bolas, calculado a mano como en el billar (casi elástico, a lo
## largo de la línea entre centros). Funciona igual si la otra bola está parada
## (y "congelada" para no moverse sola) o en movimiento.
func _ball_collisions() -> void:
	var act := _active_players()
	for i in act.size():
		for j in range(i + 1, act.size()):
			var a = act[i]["ball"]
			var b = act[j]["ball"]
			if not a.visible or not b.visible or act[i]["done"] or act[j]["done"]:
				continue
			if not a.moving and not b.moving:
				continue
			var d: Vector3 = b.global_position - a.global_position
			d.y = 0.0
			var dist := d.length()
			if dist >= Ball.RADIUS * 2.0 or dist < 0.0001:
				continue
			var n := d / dist
			var va: Vector3 = a.linear_velocity if a.moving else Vector3.ZERO
			var vb: Vector3 = b.linear_velocity if b.moving else Vector3.ZERO
			var rel := (va - vb).dot(n)
			if rel <= 0.0:
				continue
			var imp := n * rel * 0.95
			for pair in [[a, va - imp], [b, vb + imp]]:
				if pair[0].moving:
					pair[0].set_velocity(pair[1])
				else:
					pair[0].wake(pair[1])
			if a == ball or b == ball:
				hit_rival = true
			_on_ball_hit(b, rel)


func _any_moving() -> bool:
	for q in _active_players():
		if q["ball"].visible and q["ball"].moving and not q["done"]:
			return true
	return false


func _set_slowmo(on: bool) -> void:
	slowmo = on
	Engine.time_scale = SLOWMO if on else _base_speed()
	if on:
		cam.watch_cup(info["cup"])
	elif state == State.ROLLING:
		cam.mode = CamRig.Mode.TOP if top_view else CamRig.Mode.FOLLOW


func _base_speed() -> float:
	if autotest:
		return 3.0
	return SKIP_SPEED if skipping else 1.0


## Una bola se ha parado. Si es la del turno, el tiro se cierra en
## _physics_process cuando estén quietas todas; si es otra (golpeada), juega
## desde ahí, o vuelve a su sitio si ha quedado fuera del recorrido.
func _on_ball_stopped(q: Dictionary) -> void:
	var b = q["ball"]
	if b == ball:
		return
	var pos: Vector3 = b.global_position
	if builder.is_floor_char(builder.tile_at(pos.x, pos.z)):
		q["last_rest"] = pos
	else:
		b.place(q["last_rest"])


func _shot_over() -> void:
	if slowmo:
		_set_slowmo(false)
	var b: Vector3 = ball.global_position
	if not builder.is_floor_char(builder.tile_at(b.x, b.z)):
		_penalty(false)
		return
	last_rest = b
	var p := _player()
	p["last_rest"] = b
	p["strokes"] = strokes
	if autotest:
		print("  %s golpe %d -> parada a %.2f m del hoyo" % [p["name"], strokes,
			_flat_dist(b, info["cup"])])
	var cup: Vector3 = info["cup"]
	var good := _flat_dist(b, cup) < 0.9 and _flat_dist(shot_start, cup) > 2.0
	if min_cup_dist < 0.4 and not good:
		_shout_key("SHOUT_ALMOST", Color(1, 0.75, 0.4))
		Sfx.play("ooh", -3.0)
		p["char"].surprised()
	# Bailecito si el tiro ha salido bien o ha golpeado la bola del rival.
	if (good or hit_rival) and (not autotest or shot_dir != ""):
		var still_here: bool = await _dance_moment(p, "SHOUT_TAKE_THAT" if hit_rival
			else "SHOUT_GOOD_SHOT")
		if not still_here:
			return
	if strokes >= MAX_STROKES:
		_player_finished(p, MAX_STROKES + 1)
		return
	_next_turn()


## El personaje baila junto a su bola con la cámara delante. Devuelve false si
## mientras tanto la partida ha cambiado (por ejemplo, se ha vuelto al menú).
func _dance_moment(p: Dictionary, text_key: String) -> bool:
	state = State.DANCE
	flow += 1
	var my := flow
	hud.set_phase("")
	grid.visible = false
	_hide_aim()
	_dance_visual(p, text_key)
	Net.send_event("dance", [players.find(p), text_key])
	_screenshot("baile")
	await get_tree().create_timer(1.9, false).timeout
	return my == flow


func _dance_visual(p: Dictionary, text_key: String) -> void:
	var ch = p["char"]
	var b: Vector3 = p["ball"].global_position
	var to_cup: Vector3 = info["cup"] - b
	to_cup.y = 0.0
	if to_cup.length() < 0.01:
		to_cup = Vector3.FORWARD
	ch.visible = true
	ch.stand_at(b, to_cup.normalized(), _floor_under(b - to_cup.normalized().cross(Vector3.UP) * 0.32, b))
	cam.focus = ch
	cam.mode = CamRig.Mode.CHAR
	ch.dance()
	Sfx.play("dance", -3.0)
	hud.shout(tr(text_key), p["color"])


func _penalty(water: bool) -> void:
	state = State.PENALTY
	if slowmo:
		_set_slowmo(false)
	flow += 1
	var my := flow
	strokes += 1
	ball.halt()
	hud.set_strokes(_player()["name"], strokes, holes[hole_index]["par"])
	hud.set_phase("")
	Sfx.play("splash" if water else "wall")
	Sfx.play("ooh", -6.0)
	Net.send_event("penalty", [cur, water])
	hud.shout(_out_text(water), Color(0.5, 0.8, 1))
	hud.show_message("", tr("PENALTY"), Color.WHITE, 1.2)
	_player()["char"].surprised()
	if autotest:
		print("  %s golpe %d -> %s" % [_player()["name"], strokes - 1, "agua" if water else "fuera"])
	await get_tree().create_timer(1.6, false).timeout
	if my != flow:
		return
	ball.place(last_rest)
	var p := _player()
	p["strokes"] = strokes
	if strokes >= MAX_STROKES:
		_player_finished(p, MAX_STROKES + 1)
	else:
		_next_turn()


func _sink() -> void:
	state = State.SINKING
	flow += 1
	var my := flow
	ball.halt()
	var c: Vector3 = info["cup"]
	var tw := create_tween()
	tw.tween_property(ball, "global_position", Vector3(c.x, c.y + Ball.RADIUS * 0.5, c.z), 0.1)
	tw.tween_property(ball, "global_position", Vector3(c.x, c.y - 0.25, c.z), 0.22) \
		.set_ease(Tween.EASE_IN)
	Sfx.play("cup")
	Net.send_event("sink", [cur])
	await tw.finished
	if my != flow:
		return
	if slowmo:
		_set_slowmo(false)
	var par: int = holes[hole_index]["par"]
	_confetti(c, 120 if strokes < par else 50)
	if strokes == 1:
		cam.shake(1.0)
	if _flat_dist(shot_start, c) > 5.0 and strokes > 1:
		_shout_key("SHOUT_FAR", Color(1, 0.9, 0.35))
	_player_finished(_player(), strokes)


## Un jugador ha terminado el hoyo: resultado, reacción de su personaje junto
## al hoyo y, si es el jugador humano, sus estrellas. Luego sigue el otro.
func _player_finished(p: Dictionary, score: int) -> void:
	state = State.TURN_DONE
	flow += 1
	var my := flow
	p["done"] = true
	p["scores"].append(score)
	_park(p["ball"])
	var par: int = holes[hole_index]["par"]
	hud.set_phase("")
	grid.visible = false
	_hide_aim()
	_update_total()
	Net.send_event("finished", [players.find(p), score])
	_finish_visual(p, score)
	_player_stars(p, score)
	if autotest:
		print("HOYO %d (%s) %s: %d golpes, par %d" % [hole_index + 1, holes[hole_index]["name"],
			p["name"], score, par])
	_screenshot("fin")
	await get_tree().create_timer(3.2, false).timeout
	if my != flow:
		return
	_next_turn()


## Resultado de un jugador con su personaje celebrándolo junto al hoyo.
func _finish_visual(p: Dictionary, score: int) -> void:
	var par: int = holes[hole_index]["par"]
	var res := _result_name(score, par)
	var sub: String = tr("RES_STROKE_ONE") % p["name"] if score == 1 \
		else tr("RES_STROKES") % [p["name"], score]
	hud.show_message(res[0], sub, res[1], 2.4)
	# El personaje aparece junto al hoyo y celebra (o no).
	var ch = p["char"]
	for q in players:
		q["char"].visible = false
	ch.visible = true
	var c: Vector3 = info["cup"]
	var toward_tee: Vector3 = info["tee"] - c
	toward_tee.y = 0.0
	var spot: Vector3 = c + toward_tee.normalized() * 0.45
	ch.global_transform = Transform3D(Basis.looking_at(toward_tee.normalized(), Vector3.UP),
		Vector3(spot.x, builder.h(spot.x, spot.z), spot.z))
	ch.poof()
	cam.focus = ch
	cam.mode = CamRig.Mode.CHAR
	if score == 1:
		Sfx.play("big_fanfare")
		Sfx.play("applause")
		ch.dance(1)
	elif score < par:
		Sfx.play("fanfare")
		Sfx.play("applause")
		Sfx.play("dance", -6.0)
		ch.dance()
	elif score == par:
		Sfx.play("small_applause", -3.0)
		ch.celebrate(false)
	else:
		Sfx.play("sad", -4.0)
		ch.sad()


func _player_stars(p: Dictionary, score: int) -> void:
	if p["cpu"] or p["remote"]:
		return
	var par: int = holes[hole_index]["par"]
	var got := int(score <= par) + int(seeds_total > 0 and seeds_got == seeds_total) \
		+ int(score < par)
	var before := _total_stars()
	_save_stars(hole_index, got)
	_announce_unlocks(before, _total_stars())
	if not autotest:
		hud.show_stars(got, 2.6)


## Todos han terminado el hoyo: en duelo se dice quién lo gana y se pasa al
## siguiente (o a la tarjeta final).
func _hole_complete(from_net: bool = false) -> void:
	if online and not from_net:
		Net.send_sync(_sync_data())
		Net.send_event("hole_complete", [])
	flow += 1
	var my := flow
	if duel:
		await _duel_hole_result()
		if my != flow:
			return
	if hole_index + 1 < holes.size():
		hole_index += 1
		_load_hole(hole_index)
	else:
		_finish()


## Una bola golpeada por la del turno ha caído en el hoyo: cuenta como
## embocada para su dueño, con los golpes que llevaba.
func _knocked_in(q: Dictionary) -> void:
	var b = q["ball"]
	q["done"] = true
	b.halt()
	var c: Vector3 = info["cup"]
	var tw := create_tween()
	tw.tween_property(b, "global_position", Vector3(c.x, c.y - 0.25, c.z), 0.25)
	tw.tween_callback(func() -> void: _park(b))
	Sfx.play("cup")
	Sfx.play("small_applause", -4.0)
	var score: int = q["strokes"]
	q["scores"].append(score)
	_shout_key("SHOUT_KNOCKED_IN", q["color"])
	var res := _result_name(score, holes[hole_index]["par"])
	hud.flash("%s: %s" % [q["name"], res[0]], res[1])
	_update_total()
	_player_stars(q, score)
	if autotest:
		print("HOYO %d (%s) %s: %d golpes (de carambola)" % [hole_index + 1,
			holes[hole_index]["name"], q["name"], score])


## Una bola golpeada ha caído al agua o fuera: vuelve a su sitio, sin castigo.
func _restore_knocked(q: Dictionary, water: bool) -> void:
	var b = q["ball"]
	Sfx.play("splash" if water else "wall", -6.0)
	b.place(q["last_rest"])


func _duel_hole_result() -> void:
	Engine.time_scale = 3.0 if autotest else 1.0
	var a: int = players[me_idx]["scores"].back()
	var b: int = players[1 - me_idx]["scores"].back()
	var title := tr("DUEL_TIE_HOLE")
	var col := Color.WHITE
	if hotseat and a != b:
		# Dos jugadores en el mismo móvil: se dice quién gana el hoyo.
		var w: Dictionary = players[0] if a < b else players[1]
		title = tr("DUEL_HOLE_FOR") % str(w["name"]).to_upper()
		col = w["color"]
		Sfx.play("fanfare")
	elif a < b:
		title = tr("DUEL_WIN_HOLE")
		col = Color(0.5, 1, 0.55)
		Sfx.play("fanfare")
	elif b < a:
		title = tr("DUEL_LOSE_HOLE") if not online else tr("DUEL_HOLE_FOR") % players[1 - me_idx]["name"]
		col = players[1 - me_idx]["color"]
	hud.show_message(title, "%s %d  ·  %s %d" % [players[me_idx]["name"], a, players[1 - me_idx]["name"], b],
		col, 1.8)
	await get_tree().create_timer(2.0, false).timeout


func _finish() -> void:
	state = State.FINISHED
	flow += 1
	Engine.time_scale = 1.0
	var rows := []
	var totals := []
	for p in _active_players():
		var total := 0
		for s in p["scores"]:
			total += s
		totals.append(total)
		rows.append({"name": p["name"], "color": p["color"], "scores": p["scores"]})
	var note := ""
	if duel:
		var mine: int = totals[me_idx]
		var theirs: int = totals[1 - me_idx]
		if hotseat and mine != theirs:
			note = tr("END_WINNER") % players[0 if mine < theirs else 1]["name"]
			Sfx.play("big_fanfare")
			Sfx.play("applause")
		elif mine < theirs:
			note = tr("END_WIN")
			Sfx.play("big_fanfare")
			Sfx.play("applause")
		elif theirs < mine:
			note = tr("END_LOSE") if not online else tr("END_LOSE_ONLINE") % players[1 - me_idx]["name"]
		else:
			note = tr("END_TIE")
	else:
		var best := _load_best()
		if best <= 0 or totals[0] < best:
			_save_best(totals[0])
			note = tr("END_RECORD")
		else:
			note = tr("END_BEST") % best
	note += "   ·   " + tr("MENU_WORLD_STARS") % _world_stars(world)
	var show_party := not autotest or shot_dir != ""
	if show_party:
		# Fin del recorrido: el ganador (o tú, si juegas solo o hay empate)
		# baila junto al último hoyo entre confeti antes de la tarjeta.
		var my := flow
		var w := me_idx
		if duel and totals[0] != totals[1]:
			w = 0 if totals[0] < totals[1] else 1
		_final_dance(players[w])
		await get_tree().create_timer(2.8).timeout
		if my != flow:
			return
		cam.char_shift = 0.8
	hud.show_scorecard(holes, rows, note, show_party)
	if show_party:
		hud.confetti(6.0)
	if shot_dir != "":
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("tarjeta.png"))
	if autotest:
		for p in _active_players():
			print("TARJETA %s: %s" % [p["name"], str(p["scores"])])
		print("FIN: %s" % note)
		if online:
			# Da tiempo al otro móvil a terminar antes de cerrar la conexión.
			await get_tree().create_timer(6.0).timeout
		get_tree().quit()


func _final_dance(p: Dictionary) -> void:
	hud.set_turn("")
	cam.char_shift = 0.0
	hud.set_phase("")
	grid.visible = false
	_hide_aim()
	var ch = p["char"]
	for q in players:
		q["char"].visible = false
	ch.visible = true
	var c: Vector3 = info["cup"]
	var toward_tee: Vector3 = info["tee"] - c
	toward_tee.y = 0.0
	var spot: Vector3 = c + toward_tee.normalized() * 0.45
	ch.global_transform = Transform3D(Basis.looking_at(toward_tee.normalized(), Vector3.UP),
		Vector3(spot.x, builder.h(spot.x, spot.z), spot.z))
	ch.poof()
	cam.focus = ch
	cam.mode = CamRig.Mode.CHAR
	ch.dance(1)
	hud.shout(tr("SHOUT_COURSE_DONE"), p["color"])
	Sfx.play("dance", -3.0)
	Sfx.play("applause")
	for k in 4:
		get_tree().create_timer(0.5 * k).timeout.connect(func() -> void:
			if state == State.FINISHED:
				_confetti(c + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)), 90))
	# Sigue bailando mientras se ve la tarjeta.
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if state == State.FINISHED:
			ch.dance())


func _result_name(score: int, par: int) -> Array:
	var gold := Color(1, 0.85, 0.2)
	if score == 1:
		return [tr("RES_ACE"), gold]
	match score - par:
		-3:
			return [tr("RES_ALBATROSS"), gold]
		-2:
			return [tr("RES_EAGLE"), gold]
		-1:
			return [tr("RES_BIRDIE"), Color(0.45, 1, 0.5)]
		0:
			return [tr("RES_PAR"), Color.WHITE]
		1:
			return [tr("RES_BOGEY"), Color(1, 0.75, 0.45)]
		2:
			return [tr("RES_DOUBLE_BOGEY"), Color(1, 0.6, 0.4)]
	return ["+%d" % (score - par), Color(1, 0.5, 0.4)]


func _vs_par(p: Dictionary) -> String:
	var d := 0
	var sc: Array = p["scores"]
	for i in sc.size():
		d += int(sc[i]) - int(holes[i]["par"])
	if d > 0:
		return "+%d" % d
	if d < 0:
		return "%d" % d
	return "±0"


func _update_total() -> void:
	if duel:
		hud.set_total("%s %s   ·   %s %s" % [str(players[0]["name"]).to_upper(), _vs_par(players[0]),
			str(players[1]["name"]).to_upper(), _vs_par(players[1])])
	else:
		hud.set_total(tr("HUD_TOTAL") % _vs_par(players[0]))


# --- Pausa e idioma --------------------------------------------------------------------

func _pause() -> void:
	if state in [State.MENU, State.FINISHED] or get_tree().paused:
		return
	if not online:
		get_tree().paused = true
	hud.show_pause()


func _resume() -> void:
	get_tree().paused = false
	hud.hide_pause()


func _quit_to_menu() -> void:
	get_tree().paused = false
	if online:
		Net.leave()
		online = false
	hud.hide_pause()
	slowmo = false
	for q in players:
		q["ball"].halt()
	_show_menu()


## Botón "atrás" de Android: en partida pausa; en la pausa sigue; en el menú sale.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.MENU:
			get_tree().quit()
		elif get_tree().paused:
			_resume()
		else:
			_pause()


func _apply_language() -> void:
	TranslationServer.set_locale(language if language != "" else OS.get_locale())


func _language_text() -> String:
	var text := tr("LANGUAGE") + ":  "
	if language == "":
		text += "%s (%s)" % [tr("LANGUAGE_AUTO"), tr("LANGUAGE_NAME")]
	else:
		text += tr("LANGUAGE_NAME")
	return text


## Lista de idiomas para el selector, cada uno con su nombre en su propio
## idioma (sale de la fila LANGUAGE_NAME de las traducciones).
func _open_language_picker() -> void:
	var options := [["", tr("LANGUAGE_AUTO")]]
	for code in LANGUAGES:
		if code == "":
			continue
		var t := TranslationServer.get_translation_object(code)
		options.append([code, t.get_message("LANGUAGE_NAME") if t else code])
	hud.show_language_picker(options, language)


func _set_language(code: String) -> void:
	language = code
	_apply_language()
	var cfg := _cfg()
	cfg.set_value("settings", "language", language)
	_save_cfg(cfg)
	players[0]["name"] = tr("NAME_YOU")
	hud.refresh_texts()
	_show_menu()


# --- Juguetes del recorrido ------------------------------------------------------

func _on_trigger(body: Node, t: Dictionary) -> void:
	var owner_p := {}
	for q in _active_players():
		if q["ball"] == body:
			owner_p = q
	if owner_p.is_empty() or owner_p["done"] or not body.visible or state in [State.MENU, State.WATCH]:
		return
	var b = body
	match t["type"]:
		"seed":
			if owner_p["cpu"] or owner_p["remote"] or not (t["node"] as Node3D).visible:
				return
			(t["node"] as Node3D).visible = false
			seeds_got += 1
			hud.set_seeds(seeds_got, seeds_total)
			hud.flash(tr("SEED_PLUS") if seeds_got < seeds_total else tr("SEED_ALL"),
				Color(1, 0.85, 0.35))
			Sfx.play("coin", 0.0, 1.0 + seeds_got * 0.12)
			_sparkle((t["node"] as Node3D).global_position)
		"pad":
			var v: Vector3 = b.linear_velocity
			var hv := Vector3(v.x, 0, v.z)
			var dir := hv.normalized() if hv.length() > 0.1 else _dir(aim_yaw)
			b.set_velocity(dir * maxf(hv.length(), t["min_speed"]) + Vector3.UP * t["up"])
			Sfx.play("boing")
			_shout_key("SHOUT_BOING", Color(1, 0.55, 0.5))
			var cap: Node3D = t["node"]
			var tw := create_tween()
			tw.tween_property(cap, "scale", Vector3(1.3, 0.4, 1.3), 0.06)
			tw.tween_property(cap, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
		"pipe":
			_through_pipe(t, b)
		"launch":
			var v: Vector3 = b.linear_velocity
			var d: Vector3 = t["dir"]
			var along := maxf(v.dot(d), 0.0)
			b.set_velocity(d * maxf(along, float(t["speed"])) + Vector3.UP * maxf(v.y, float(t["up"])))
			Sfx.play("jump", -2.0)
			cam.shake(0.3)
		"boost":
			var v: Vector3 = b.linear_velocity
			var d: Vector3 = t["dir"]
			var along := maxf(v.dot(d), 0.0)
			b.set_velocity(d * maxf(along, float(t["speed"])) + Vector3.UP * v.y)
			Sfx.play("whoosh", -2.0, 1.2)
			cam.shake(0.2)
			var arrows: Node3D = t["node"]
			var tw := create_tween()
			tw.tween_property(arrows, "scale", Vector3(1.25, 1, 1.25), 0.06)
			tw.tween_property(arrows, "scale", Vector3.ONE, 0.3)


func _through_pipe(t: Dictionary, b) -> void:
	var active: bool = b == ball
	if active:
		state = State.PIPE
	transit += 1
	var serial := hole_serial
	var sp: float = clampf(b.linear_velocity.length(), 1.4, 3.2)
	b.halt()
	b.visible = false
	if t.get("portal", false):
		Sfx.play("whoosh")
		Sfx.play("coin", -6.0, 0.7)
		_shout_key("SHOUT_PORTAL", Color(0.7, 0.85, 1.0))
	else:
		Sfx.play("pipe")
		_shout_key("SHOUT_PIPE", Color(0.95, 0.65, 0.45))
	await get_tree().create_timer(0.8, false).timeout
	if serial != hole_serial:
		return
	transit -= 1
	b.place(t["exit"])
	b.visible = true
	b.shoot(t["out"] * sp)
	Sfx.play("jump", -4.0)
	if active and state == State.PIPE:
		cam.follow_dir = t["out"]
		cam.mode = CamRig.Mode.TOP if top_view else CamRig.Mode.FOLLOW
		state = State.ROLLING


func _on_bumped(body: Node) -> void:
	Sfx.play("boing", -2.0, randf_range(0.9, 1.15))
	cam.shake(0.35)
	if body.has_meta("pop"):
		var look: Node3D = body.get_meta("pop")
		var tw := create_tween()
		tw.tween_property(look, "scale", Vector3(1.25, 0.8, 1.25), 0.06)
		tw.tween_property(look, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC)


func _on_ball_hit(_other: Node, speed: float) -> void:
	Sfx.play("wall", linear_to_db(clampf(speed / 3.0, 0.3, 1.0)), 1.8)
	cam.shake(0.25)
	if speed > 0.8:
		_shout_key("SHOUT_KNOCK", Color(1, 0.8, 0.45))


func _on_wall_hit(speed: float) -> void:
	if speed > 0.3:
		Sfx.play("wall", linear_to_db(clampf(speed / 4.0, 0.15, 1.0)))
	if speed > 3.0:
		cam.shake(0.3)


# --- Efectos ------------------------------------------------------------------------

func _burst(pos: Vector3, amount: int, colors: Array, speed: float, grav: float,
		life: float, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(size, size * 0.6)
	p.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = mat
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.damping_min = 0.5
	p.damping_max = 1.5
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array()
	grad.colors = PackedColorArray()
	for i in colors.size():
		grad.add_point(float(i) / maxf(colors.size() - 1, 1), colors[i])
	p.color_initial_ramp = grad
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)


func _confetti(pos: Vector3, amount: int) -> void:
	_burst(pos + Vector3.UP * 0.1, amount, [Color(1, 0.35, 0.3), Color(1, 0.85, 0.3),
		Color(0.4, 0.8, 1.0), Color(0.5, 0.95, 0.5), Color(1, 0.6, 0.85)], 4.5, 4.0, 2.5, 0.07)


func _sparkle(pos: Vector3) -> void:
	_burst(pos, 24, [Color(1, 0.95, 0.6), Color(1, 0.8, 0.3)], 1.6, 1.0, 0.7, 0.05)


func _puff(pos: Vector3) -> void:
	_burst(pos, 10, [Color(0.55, 0.8, 0.35), Color(0.85, 0.95, 0.6)], 1.0, 3.0, 0.5, 0.04)


# --- Rival de la CPU ----------------------------------------------------------------

## Kaze decide el tiro: normalmente sigue la ruta del hoyo (esquivando tu bola
## si se cruza, cuando ya tiene nivel), y a veces, con más picardía cuanto más
## avanza el recorrido, va a por tu bola para alejarla del hoyo. Después la
## barra avanza igual que para el jugador y "pulsa" cuando toca.
func _cpu_think() -> void:
	var my := flow
	await get_tree().create_timer(0.9, false).timeout
	if my != flow or state != State.AIM:
		return
	await get_tree().physics_frame
	var skill := _kaze_skill()
	var b: Vector3 = ball.global_position
	var target_yaw := 0.0
	var plan := {}
	var other = _rival_ball()
	if other != null and randf() < _kaze_cunning(skill):
		plan = _attack_plan(b, other.global_position)
	if not plan.is_empty():
		target_yaw = _yaw_to(plan["aim"])
		cpu_power = plan["power"]
		hud.shout(tr("KAZE_ATTACK"), players[1]["color"])
		players[1]["char"].surprised()
	else:
		var target := _auto_target()
		var is_cup := _flat_dist(target, info["cup"]) < 0.3
		target_yaw = _yaw_to(target)
		cpu_power = _power_to(b, target, 0.35 if is_cup else 0.5)
		if OS.get_cmdline_user_args().has("--debug-aim"):
			print("    Kaze desde (%.2f, %.2f) apunta a (%.2f, %.2f) fuerza %.2f" % [b.x, b.z,
				target.x, target.z, cpu_power])
		if other != null and skill > 0.2:
			target_yaw += _dodge(b, target, other.global_position)
	# Errores de puntería y de fuerza, cada vez menores.
	target_yaw += deg_to_rad(randfn(0.0, lerpf(3.0, 0.7, skill)))
	cpu_power = clampf(cpu_power * randfn(1.0, lerpf(0.09, 0.03, skill)), 0.03, 1.0)
	cpu_acc = randfn(0.0, lerpf(0.04, 0.012, skill))
	# Gira la mira poco a poco hasta el objetivo.
	var tw := create_tween()
	tw.tween_property(self, "aim_yaw", target_yaw, 0.5)
	await tw.finished
	if my != flow or state != State.AIM:
		return
	_press()


## Nivel de Kaze: 1 en el primer hoyo del primer mundo, 12 en el último del
## segundo.
func _kaze_level() -> int:
	return world * 6 + hole_index + 1


func _kaze_skill() -> float:
	return clampf((_kaze_level() - 1) / 11.0, 0.0, 1.0)


## Probabilidad de que Kaze intente golpear tu bola cuando le conviene.
func _kaze_cunning(skill: float) -> float:
	return clampf((skill - 0.15) / 0.85, 0.0, 1.0) * 0.9


## Tu bola, si está en el campo y aún no has embocado (para Kaze).
func _rival_ball():
	var me: Dictionary = players[0]
	if not duel or me["done"] or not me["started"] or not me["ball"].visible:
		return null
	return me["ball"]


## Plan para golpear la bola rival y alejarla del hoyo. Solo si le compensa:
## la tuya está cerca del hoyo, la de Kaze no, y hay línea limpia. Devuelve
## {aim, power} o vacío.
func _attack_plan(from: Vector3, other: Vector3) -> Dictionary:
	var cup: Vector3 = info["cup"]
	if _flat_dist(other, cup) > 2.2 or _flat_dist(from, cup) < 1.6:
		return {}
	var best := {}
	var best_gain := 0.4
	var r2 := Ball.RADIUS * 2.0
	# Prueba 16 direcciones de empujón (de frente o golpeándola de lado) y se
	# queda con la que más la aleja del hoyo.
	for k in 16:
		var u := Vector3(cos(k * TAU / 16.0), 0.0, sin(k * TAU / 16.0))
		var contact := other - u * r2
		var approach := contact - from
		approach.y = 0.0
		# El golpe solo empuja en esa dirección si llega casi de frente.
		if approach.length() < 0.3 or approach.normalized().dot(u) < 0.5:
			continue
		var push := 2.2
		var landing := other + u * push
		if not builder.is_floor_char(builder.tile_at(landing.x, landing.z)):
			push = 1.2
			landing = other + u * push
		var gain := _flat_dist(landing, cup) - _flat_dist(other, cup)
		if gain <= best_gain:
			continue
		var space := get_world_3d().direct_space_state
		var aim_pt := Vector3(contact.x, builder.h(contact.x, contact.z) + Ball.RADIUS, contact.z)
		if not _clear_line(space, from + Vector3.UP * 0.03, aim_pt + Vector3.UP * 0.03) \
				or not _dry_line(from, aim_pt):
			continue
		# Velocidad al llegar para que tu bola ruede "push" metros, y la de salida.
		var v_contact := sqrt(2.0 * Ball.ROLL_DECEL * push) / 0.95 / approach.normalized().dot(u)
		var v0 := sqrt(v_contact * v_contact + 2.0 * Ball.ROLL_DECEL * approach.length())
		var pw := v0 * v0 / (2.0 * Ball.ROLL_DECEL * MAX_DIST)
		if pw > 1.0:
			continue
		best = {"aim": aim_pt, "power": pw}
		best_gain = gain
	return best


## Si tu bola se cruza en la línea de tiro de Kaze, corrige el ángulo para
## pasarle por un lado. Devuelve el giro en radianes (0 si no estorba).
func _dodge(from: Vector3, target: Vector3, other: Vector3) -> float:
	var d := target - from
	d.y = 0.0
	var seg_len := d.length()
	if seg_len < 0.01:
		return 0.0
	var dir := d / seg_len
	var rel := other - from
	rel.y = 0.0
	var along := rel.dot(dir)
	if along <= 0.0 or along >= seg_len:
		return 0.0
	var side := rel - dir * along
	var clearance := Ball.RADIUS * 2.0 + 0.04
	if side.length() >= clearance:
		return 0.0
	# Gira hacia el lado contrario a donde está tu bola, lo justo para rozarla.
	var ang := asin(clampf(clearance / maxf(rel.length(), clearance), 0.0, 1.0)) \
		- asin(clampf(side.length() / maxf(rel.length(), 0.001), 0.0, 1.0))
	# Girar a la izquierda sube el ángulo: si tu bola está a la izquierda, a la derecha.
	var sign_side := -signf(dir.cross(side).y) if side.length() > 0.001 else 1.0
	return ang * sign_side


## Kaze pulsa cuando la marca cruza su objetivo entre un fotograma y el
## siguiente (con pocos fotogramas por segundo o el turno acelerado la marca
## avanza mucho de golpe y nunca cae justo encima). Si en 6 s no ha pulsado,
## pulsa igualmente para que su turno nunca se quede atascado.
func _cpu_update() -> void:
	var target := cpu_power
	if state == State.ACCURACY:
		target = clampf(power + cpu_acc, 0.0, POWER_MAX)
	var elapsed := (Time.get_ticks_msec() - swing_start_ms) * Engine.time_scale / 1000.0
	if state == State.ACCURACY and elapsed < 0.3:
		return
	var crossed := (_prev_meter - target) * (meter - target) <= 0.0
	if crossed or elapsed > 6.0:
		meter = target
		_press()


func _on_skip() -> void:
	if not _player()["cpu"]:
		return
	skipping = true
	if not slowmo:
		Engine.time_scale = SKIP_SPEED


# --- Golpes especiales ---------------------------------------------------------

func _open_specials() -> Array:
	var total := 0 if unlock_all else _total_stars()
	var res := []
	for s in SPECIALS:
		if unlock_all or total >= int(s["stars"]):
			res.append(s["id"])
	return res


## Opciones del botón de golpe especial para el jugador del turno: las
## desbloqueadas a las que aún les quedan usos en este hoyo.
func _special_options() -> Array:
	var p := _player()
	var opts := [""]
	if p["cpu"] or p["remote"]:
		return opts
	for id in specials_open:
		if int(p["uses"].get(id, 0)) <= 0:
			continue
		if id == "curve":
			opts.append_array(["curve_l", "curve_r"])
		else:
			opts.append(id)
	return opts


func _on_special() -> void:
	if state != State.AIM or not _local_turn():
		return
	var opts := _special_options()
	if opts.size() <= 1:
		return
	special = opts[(opts.find(special) + 1) % opts.size()]
	Sfx.play("tick", -8.0, 1.5)
	_show_special()
	_update_aim()


func _show_special() -> void:
	var opts := _special_options()
	var uses: Dictionary = _player().get("uses", {})
	var text := tr("SP_NONE")
	var hint := ""
	match special:
		"curve_l":
			text = "<  " + tr("SP_NAME_CURVE") + " ×%d" % uses.get("curve", 0)
			hint = tr("HINT_CURVE")
		"curve_r":
			text = tr("SP_NAME_CURVE") + " ×%d" % uses.get("curve", 0) + "  >"
			hint = tr("HINT_CURVE")
		"hop":
			text = tr("SP_NAME_HOP") + " ×%d" % uses.get("hop", 0)
			hint = tr("HINT_HOP")
		"brake":
			text = tr("SP_NAME_BRAKE") + " ×%d" % uses.get("brake", 0)
			hint = tr("HINT_BRAKE")
	hud.set_special(text, opts.size() > 1, special != "", hint)


func _use_special(id: String) -> void:
	var p := _player()
	p["uses"][id] = maxi(int(p["uses"].get(id, 0)) - 1, 0)


## Salto o freno mientras la bola rueda (segundo toque del botón).
func _trigger_special() -> void:
	if special_armed == "":
		return
	var ok := false
	if special_armed == "hop":
		ok = ball.hop()
		if ok:
			Sfx.play("jump")
			_puff(ball.global_position)
			_shout_key("SHOUT_HOP", Color(0.6, 1, 0.7))
	elif special_armed == "brake":
		ok = ball.brake()
		if ok:
			Sfx.play("wall", -4.0, 0.6)
			_burst(ball.global_position, 14, [Color(1, 1, 1), Color(0.8, 0.9, 1)], 1.2, 2.0, 0.5, 0.04)
			_shout_key("SHOUT_BRAKE", Color(1, 0.8, 0.5))
	if ok:
		_use_special(special_armed)
		special_armed = ""
		hud.roll_action = ""
		hud.set_phase("rolling")


## Prueba automática de los golpes especiales: en cada tiro elige uno al azar.
func _auto_special() -> void:
	specials_open = ["curve", "hop", "brake"]
	var opts := _special_options()
	special = opts[randi() % opts.size()]
	var chosen := special
	_strike()
	if chosen in ["hop", "brake"]:
		var my := flow
		await get_tree().create_timer(0.35 if chosen == "hop" else 0.8, false).timeout
		if my == flow and state == State.ROLLING:
			print("    especial: ", chosen)
			_trigger_special()
	elif chosen != "":
		print("    especial: ", chosen)


## Avisa de los golpes y mundos que se acaban de desbloquear.
func _announce_unlocks(before: int, after: int) -> void:
	if unlock_all or autotest or after <= before:
		return
	var items := []
	for s in SPECIALS:
		if before < int(s["stars"]) and after >= int(s["stars"]):
			var id := str(s["id"]).to_upper()
			items.append([tr("UNLOCK_SPECIAL"), tr("SP_NAME_" + id), tr("DESC_" + id)])
	for w in Holes.WORLDS:
		if before < int(w["stars_needed"]) and after >= int(w["stars_needed"]):
			items.append([tr("UNLOCK_WORLD"), tr(w["name"]), ""])
	var delay := 2.8
	for it in items:
		get_tree().create_timer(delay, false).timeout.connect(
			func() -> void: hud.show_unlock(it[0], it[1], it[2]))
		delay += 4.5
	specials_open = _open_specials()


func _out_text(water: bool) -> String:
	if water:
		return tr("SHOUT_SPLASH")
	return tr("SHOUT_CLOUDS") if builder.theme == 2 else tr("SHOUT_OUT")


## Fuerza para que la bola llegue a "target" y ruede "extra" metros más,
## contando lo que frena cada superficie (hielo, arena, nieve) y la subida.
func _power_to(from: Vector3, target: Vector3, extra: float) -> float:
	var dist := _flat_dist(from, target)
	var n := maxi(1, int(ceil(dist / 0.25)))
	var work := 0.0
	for i in n:
		work += _decel_at(from.lerp(target, (i + 0.5) / n)) * dist / n
	work += _decel_at(target) * extra
	var climb := target.y - from.y
	work += climb * 5.0 / 7.0 * 9.8 * (1.0 if climb > 0.0 else 0.5)
	return maxf(work, 0.0) / (Ball.ROLL_DECEL * MAX_DIST)


func _decel_at(p: Vector3) -> float:
	match builder.tile_at(p.x, p.z):
		"s":
			return Ball.decel_of("snow" if builder.theme == 3 else "sand")
		"i", "j":
			return Ball.decel_of("ice")
	return Ball.ROLL_DECEL


# --- Entrada ---------------------------------------------------------------

func _process(delta: float) -> void:
	var p: Dictionary = _player() if not players.is_empty() and state != State.MENU else {}
	match state:
		State.AIM:
			if not p.is_empty() and _local_turn():
				var k: float = hud.aim_hold + Input.get_axis("ui_left", "ui_right")
				if k != 0.0:
					aim_yaw -= k * AIM_SPEED * delta
			_update_aim()
		State.POWER:
			_prev_meter = meter
			meter += meter_dir * POWER_RISE * delta
			if meter >= POWER_MAX:
				meter = POWER_MAX
				meter_dir = -1.0
			elif meter <= 0.0:
				meter = 0.0
				meter_dir = 1.0
			hud.set_meter(meter, power_guide)
			hud.set_shot(_shot_text(meter))
			p["char"].backswing(meter)
		State.ACCURACY:
			_prev_meter = meter
			meter += meter_dir * ACC_SPEED * _meter_speed(meter) * delta
			if meter >= POWER_MAX:
				meter = POWER_MAX
				meter_dir = -1.0
			elif meter <= 0.0:
				meter = 0.0
				meter_dir = 1.0
			hud.set_meter(meter, power_guide, power, ACC_ZONE, ACC_PERFECT)
	if not p.is_empty() and p["cpu"] and state in [State.POWER, State.ACCURACY]:
		_cpu_update()
	if online:
		_online_process(delta)
	if info.has("flag"):
		var near: bool = ball.visible and ball.global_position.distance_to(info["cup"]) < 1.6
		info["flag"].visible = state in [State.INTRO, State.MENU] or not near


func _unhandled_input(event: InputEvent) -> void:
	if state == State.MENU or players.is_empty() or not _local_turn():
		return
	if event is InputEventScreenDrag:
		if state == State.AIM:
			aim_yaw -= event.relative.x * DRAG_AIM
		elif state == State.ROLLING and spin_left > 0:
			drag_accum += event.relative.x
			if absf(drag_accum) > 80.0:
				var side := signf(drag_accum)
				if ball.apply_spin(side):
					spin_left -= 1
					hud.flash(tr("SPIN") + "  >" if side > 0.0 else "<  " + tr("SPIN"), Color(0.6, 0.9, 1))
				drag_accum = 0.0
	elif event is InputEventScreenTouch:
		drag_accum = 0.0
	elif event.is_action_pressed("ui_accept"):
		_on_action()
	elif event.is_action_released("ui_accept"):
		_on_action_released()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_on_view()
		elif event.keycode == KEY_E:
			_on_special()


func _on_action_released() -> void:
	waiting_release = false


func _on_view() -> void:
	if state == State.AIM:
		top_view = not top_view
		cam.mode = CamRig.Mode.TOP if top_view else CamRig.Mode.AIM
	elif state == State.ROLLING and not slowmo:
		top_view = not top_view
		cam.mode = CamRig.Mode.TOP if top_view else CamRig.Mode.FOLLOW


# --- Apuntado --------------------------------------------------------------

func _dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _yaw_to(p: Vector3) -> float:
	var b: Vector3 = ball.global_position
	return atan2(-(p.x - b.x), -(p.z - b.z))


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _shot_text(p: float) -> String:
	return tr("HUD_SHOT") % (p * MAX_DIST)


## Punto de la ruta más avanzado que se ve sin bordes de por medio, sin
## volver nunca a puntos que la bola ya ha dejado atrás.
func _auto_target() -> Vector3:
	var b: Vector3 = ball.global_position
	var pts: Array = info["path"]
	var start := 0
	var best := INF
	for i in pts.size():
		var d := _flat_dist(b, _path_point(pts[i]))
		if d < best:
			best = d
			start = i
	if best < 0.9:
		start = mini(start + 1, pts.size() - 1)
	var space := get_world_3d().direct_space_state
	var lift := Vector3.UP * 0.03
	for i in range(pts.size() - 1, start - 1, -1):
		var target := _path_point(pts[i])
		if _clear_line(space, b + lift, target + lift) and _dry_line(b, target):
			return target
	return _path_point(pts[start])


## Hay paso para la bola (no solo para un rayo fino): se comprueban tres
## rayos, el central y dos a los lados separados el radio de la bola.
## Los rayos siguen el terreno por tramos, a la altura de la bola: si fueran
## en línea recta hacia un hoyo en alto pasarían por encima de las vallas.
func _clear_line(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var d := to - from
	d.y = 0.0
	var side := d.normalized().cross(Vector3.UP) * (Ball.RADIUS + 0.03)
	var n := maxi(1, int(ceil(d.length() / 0.3)))
	var prev := from
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n)
		p.y = builder.h(p.x, p.z) + Ball.RADIUS + 0.03 if i < n else to.y
		for off in [Vector3.ZERO, side, -side]:
			var q := PhysicsRayQueryParameters3D.create(prev + off, p + off, HoleBuilder.LAYER_WALLS)
			if not space.intersect_ray(q).is_empty():
				return false
		prev = p
	return true


## La línea recta entre dos puntos no pasa por agua ni fuera del recorrido.
func _dry_line(a: Vector3, b: Vector3) -> bool:
	var n := int(ceil(_flat_dist(a, b) / 0.2))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		if not builder.is_floor_char(builder.tile_at(p.x, p.z)):
			return false
	return true


func _path_point(p: Vector2) -> Vector3:
	return Vector3(p.x, builder.h(p.x, p.y) + Ball.RADIUS, p.y)


func _update_aim() -> void:
	var dir := _dir(aim_yaw)
	cam.aim_dir = dir
	var b: Vector3 = ball.global_position
	var ch = _player()["char"]
	ch.stand_at(b, dir, _floor_under(b - dir.cross(Vector3.UP).normalized() * 0.32, b))
	var show: bool = state == State.AIM and not _player()["cpu"]
	# Con efecto, la mira se curva hacia el lado elegido.
	var bend := 0.0
	if special == "curve_l":
		bend = CURVE_PREVIEW
	elif special == "curve_r":
		bend = -CURVE_PREVIEW
	var yaw := aim_yaw
	var x := b.x
	var z := b.z
	for i in aim_dots.size():
		var step := 0.25 if i == 0 else 0.2
		yaw += bend * step
		x += _dir(yaw).x * step
		z += _dir(yaw).z * step
		if show and not builder.is_floor_char(builder.tile_at(x, z)):
			show = false
		aim_dots[i].visible = show
		if show:
			aim_dots[i].global_position = Vector3(x, builder.h(x, z) + 0.025, z)


func _floor_under(p: Vector3, fallback: Vector3) -> float:
	if builder.is_floor_char(builder.tile_at(p.x, p.z)):
		return builder.h(p.x, p.z)
	return fallback.y - Ball.RADIUS


## Guía de fuerza (línea amarilla), solo en tiros rasos cerca del hoyo y con
## el hoyo a la vista, como la guía de los putts en el green de Neo Turf Masters.
func _update_guide() -> void:
	power_guide = -1.0
	var d := _flat_dist(ball.global_position, info["cup"])
	if d <= GUIDE_DIST and _flat_dist(_auto_target(), info["cup"]) < 0.3:
		power_guide = (d + 0.3) / MAX_DIST
	hud.set_meter(0.0, power_guide)


func _hide_aim() -> void:
	for d in aim_dots:
		d.visible = false


# --- Prueba automática y capturas -------------------------------------------

func _auto_shot() -> void:
	var my := flow
	await get_tree().create_timer(1.3 if shot_dir != "" else 0.05, false).timeout
	if my != flow or state != State.AIM:
		return
	await get_tree().physics_frame
	var b: Vector3 = ball.global_position
	var target := _auto_target()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--straight="):
			# Prueba: tiro recto con esa fuerza (en %) al hoyo o a "x,z".
			var parts := a.substr(11).split(",")
			aim_yaw = _yaw_to(info["cup"] if parts.size() < 3
				else Vector3(float(parts[1]), b.y, float(parts[2])))
			power = float(parts[0]) / 100.0
			meter = power
			_strike()
			return
	aim_yaw = _yaw_to(target)
	var is_cup := _flat_dist(target, info["cup"]) < 0.3
	if OS.get_cmdline_user_args().has("--debug-aim"):
		print("    desde (%.2f, %.2f) apunta a (%.2f, %.2f)" % [b.x, b.z, target.x, target.z])
	# En llano basta la distancia; cuesta arriba hay que sumar la subida.
	power = clampf(_power_to(b, target, 0.4 if is_cup else 0.5), 0.03, 1.0)
	meter = power
	if "--try-specials" in OS.get_cmdline_user_args():
		_auto_special()
		return
	_strike()


func _screenshot(tag: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	var key := "%d_%d_%s" % [hole_index + 1, cur, tag]
	if _shots_taken.has(key):
		return
	_shots_taken[key] = true
	await get_tree().create_timer(1.0, false).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join("hoyo%s.png" % key))


# --- Progreso guardado --------------------------------------------------------------

func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg


## La prueba automática nunca toca el progreso guardado del jugador.
func _save_cfg(cfg: ConfigFile) -> void:
	if not autotest:
		cfg.save(SAVE_PATH)


func _save_stars(hole: int, got: int) -> void:
	var cfg := _cfg()
	var key := "w%d_h%d" % [world, hole]
	if got > int(cfg.get_value("stars", key, 0)):
		cfg.set_value("stars", key, got)
		_save_cfg(cfg)


func _world_stars(w: int) -> int:
	var cfg := _cfg()
	var total := 0
	for h in 6:
		total += int(cfg.get_value("stars", "w%d_h%d" % [w, h], 0))
	return total


func _total_stars() -> int:
	var total := 0
	for w in Holes.WORLDS.size():
		total += _world_stars(w)
	return total


func _load_best() -> int:
	return int(_cfg().get_value("records", "best_total", 0))


func _save_best(total: int) -> void:
	var cfg := _cfg()
	cfg.set_value("records", "best_total", total)
	_save_cfg(cfg)



# --- Duelo por Wi-Fi ------------------------------------------------------------------

func _local_turn() -> bool:
	if players.is_empty():
		return false
	var p := _player()
	return not p["cpu"] and not p["remote"]


## Grita una frase (por su clave de traducción) y, en línea, la muestra también
## en el otro móvil, en su propio idioma.
func _shout_key(key: String, col: Color) -> void:
	hud.shout(tr(key), col)
	Net.send_event("shout", [key, col.to_html()])


func _ball_states() -> Array:
	var list := [hole_serial_net()]
	for q in _active_players():
		list.append([q["ball"].global_position, q["ball"].visible])
	return list


## Identifica el hoyo en los mensajes (los dos móviles cuentan igual).
func hole_serial_net() -> int:
	return world * 100 + hole_index


func _sync_data() -> Dictionary:
	var list := []
	for q in _active_players():
		list.append({"strokes": q["strokes"], "done": q["done"], "started": q["started"],
			"scores": q["scores"], "rest": q["last_rest"], "pos": q["ball"].global_position,
			"vis": q["ball"].visible})
	return {"hole": hole_serial_net(), "cur": cur, "players": list}


## Turno del otro jugador: se ve su apuntado, su barra y sus bolas en directo.
func _watch() -> void:
	state = State.WATCH
	var p := _player()
	ball = p["ball"]
	cam.ball = ball
	top_view = false
	for q in players:
		q["char"].visible = false
	p["char"].visible = true
	grid.visible = false
	_hide_aim()
	cam.mode = CamRig.Mode.AIM
	hud.set_phase("watch")
	hud.set_meter(0.0, -1.0)
	hud.set_strokes(p["name"], p["strokes"], holes[hole_index]["par"])
	var turn := tr("HUD_TURN") % str(p["name"]).to_upper()
	hud.set_turn(turn)
	hud.shout(turn, p["color"])
	_update_aim()
	_screenshot("mira")


func _online_process(delta: float) -> void:
	# Tu turno: envía hacia dónde apuntas y la barra.
	if _local_turn() and state in [State.AIM, State.POWER, State.ACCURACY]:
		_aim_tick -= delta
		if _aim_tick <= 0.0:
			_aim_tick = 0.066
			var phase := "aim"
			if state == State.POWER:
				phase = "power"
			elif state == State.ACCURACY:
				phase = "accuracy"
			Net.send_aim(aim_yaw, meter, power, phase)
	# Turno del otro: las bolas se deslizan hasta la posición recibida.
	if state != State.WATCH and not (state in [State.TURN_DONE, State.DANCE]):
		return
	var k := 1.0 - exp(-18.0 * delta)
	for idx in net_targets:
		var b = players[idx]["ball"]
		var target: Vector3 = net_targets[idx]
		if b.global_position.distance_to(target) > 1.5:
			b.global_position = target
		else:
			b.global_position = b.global_position.lerp(target, k)


func _on_net_aim(yaw: float, p_meter: float, p_power: float, phase: String) -> void:
	if state != State.WATCH:
		return
	aim_yaw = yaw
	meter = p_meter
	if phase == "accuracy":
		hud.set_meter(meter, -1.0, p_power, ACC_ZONE, ACC_PERFECT)
	else:
		hud.set_meter(meter, -1.0)
	var ch = _player()["char"]
	if phase == "aim":
		ch.address()
		cam.mode = CamRig.Mode.AIM
		_update_aim()
	elif phase == "power":
		ch.backswing(meter)


func _on_net_balls(states: Array) -> void:
	if states.is_empty() or int(states[0]) != hole_serial_net() or _local_turn():
		return
	var act := _active_players()
	for i in mini(act.size(), states.size() - 1):
		var st: Array = states[i + 1]
		var b = act[i]["ball"]
		if bool(st[1]):
			if not b.visible:
				b.visible = true
				b.place(st[0])
			net_targets[i] = st[0]
		else:
			b.visible = false
			net_targets.erase(i)


func _on_net_event(event_name: String, args: Array) -> void:
	if not online or info.is_empty():
		return
	match event_name:
		"strike":
			var p: Dictionary = players[int(args[0])]
			p["char"].strike()
			Sfx.play("hit", linear_to_db(0.35 + 0.4 * float(args[1])))
			_puff(p["ball"].global_position)
			cam.ball = p["ball"]
			cam.follow_dir = _dir(aim_yaw)
			cam.mode = CamRig.Mode.FOLLOW
			hud.set_phase("")
		"shout":
			hud.shout(tr(str(args[0])), Color.html(str(args[1])))
		"penalty":
			Sfx.play("splash" if bool(args[1]) else "wall")
			hud.shout(_out_text(bool(args[1])), Color(0.5, 0.8, 1))
			hud.show_message("", tr("PENALTY"), Color.WHITE, 1.2)
		"sink":
			Sfx.play("cup")
			_confetti(info["cup"], 60)
		"dance":
			_dance_visual(players[int(args[0])], str(args[1]))
		"finished":
			var p: Dictionary = players[int(args[0])]
			_finish_visual(p, int(args[1]))
		"turn":
			# El otro ha terminado su tiro; el estado ya ha llegado con "sync".
			cur = int(args[0])
			_begin_turn()
		"hole_complete":
			_hole_complete(true)


func _on_net_sync(data: Dictionary) -> void:
	if not online or int(data.get("hole", -1)) != hole_serial_net():
		return
	var act := _active_players()
	var list: Array = data["players"]
	for i in mini(act.size(), list.size()):
		var q: Dictionary = act[i]
		var d: Dictionary = list[i]
		q["strokes"] = int(d["strokes"])
		q["done"] = bool(d["done"])
		q["started"] = bool(d["started"])
		q["scores"] = d["scores"]
		q["last_rest"] = d["rest"]
		net_targets.erase(i)
		if bool(d["vis"]):
			q["ball"].visible = true
			q["ball"].place(d["pos"])
		else:
			_park(q["ball"])
	cur = int(data["cur"])
	_update_total()


## "Otra vez" en la tarjeta final: contra Kaze se repite; en línea, el
## anfitrión vuelve a empezar con la misma persona.
func _on_restart() -> void:
	if not online:
		_on_play(duel, world, hotseat)
	elif Net.is_host():
		Net.start_game(world)
	else:
		hud.show_message("", tr("NET_WAITING_HOST"), Color(1, 0.9, 0.7), 2.5)


# --- Sala ----------------------------------------------------------------------------

func _open_lobby() -> void:
	lobby_status = ""
	Net.start_discovery()
	_refresh_lobby()


func _refresh_lobby() -> void:
	if state != State.MENU:
		return
	var view := {"name": _player_name(), "status": lobby_status, "games": Net.found_games,
		"ip": str(_cfg().get_value("settings", "last_ip", ""))}
	if Net.is_online() and not Net.players.is_empty():
		view["mode"] = "room"
		var names := []
		for slot in 2:
			if Net.players.size() > slot:
				names.append(Net.name_of_slot(slot))
		view["players"] = names
		view["host"] = Net.is_host()
		view["ips"] = Net.local_ips()
		var worlds := []
		for w in Holes.WORLDS.size():
			if not db.world_holes(w).is_empty():
				worlds.append(Holes.WORLDS[w]["name"])
		view["worlds"] = worlds
		view["world"] = lobby_world
	elif Net.is_online():
		view["mode"] = "search"
		view["status"] = tr("NET_CONNECTING")
	else:
		view["mode"] = "search"
	hud.show_lobby(view)


func _player_name() -> String:
	return str(_cfg().get_value("settings", "name", tr("NAME_YOU")))


func _save_name(n: String) -> String:
	n = n.strip_edges()
	if n == "":
		n = tr("NAME_YOU")
	var cfg := _cfg()
	cfg.set_value("settings", "name", n)
	_save_cfg(cfg)
	return n


func _on_lobby_host(player_name: String) -> void:
	lobby_status = ""
	if Net.host(_save_name(player_name)) != OK:
		lobby_status = tr("NET_CONNECT_FAILED")
	_refresh_lobby()


func _on_lobby_join(ip: String, player_name: String) -> void:
	if not ip.is_valid_ip_address():
		lobby_status = tr("NET_IP_HINT")
		_refresh_lobby()
		return
	var cfg := _cfg()
	cfg.set_value("settings", "last_ip", ip)
	_save_cfg(cfg)
	lobby_status = ""
	if Net.join(ip, _save_name(player_name)) != OK:
		lobby_status = tr("NET_CONNECT_FAILED")
	_refresh_lobby()


## Mundo elegido (negativo = solo seleccionarlo, -1 es el primero) o empezar.
func _on_lobby_start(w: int) -> void:
	if w < 0:
		lobby_world = -1 - w
		_refresh_lobby()
		return
	Net.start_game(lobby_world)


func _on_lobby_back() -> void:
	Net.stop_discovery()
	Net.leave()
	hud.hide_lobby()
	_show_menu()


func _on_net_left(reason: String) -> void:
	if autotest:
		print("RED: conexión perdida (%s), vuelta al menú" % reason)
	var was_playing := online
	online = false
	if was_playing:
		_show_menu()
		hud.show_message("", tr(reason), Color(1, 0.8, 0.6), 3.0)
	elif state == State.MENU and hud.lobby != null:
		lobby_status = tr(reason)
		_refresh_lobby()


## Empieza el duelo en línea: el anfitrión es el puesto 0 y el invitado el 1.
func _start_online(p_world: int) -> void:
	Net.stop_discovery()
	hud.hide_lobby()
	duel = true
	online = true
	hotseat = false
	me_idx = Net.my_slot()
	for i in 2:
		var q: Dictionary = players[i]
		q["cpu"] = false
		q["remote"] = i != me_idx
		q["name"] = tr("NAME_YOU") if i == me_idx else Net.name_of_slot(i)
	world = p_world
	holes = db.world_holes(world)
	decor.set_theme(world)
	Music.play_track(world)
	hud.hide_menu()
	hud.hide_scorecard()
	for q in players:
		q["scores"] = []
	hole_index = 0
	_update_total()
	_load_hole(0)
