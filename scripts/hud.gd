extends CanvasLayer
## Interfaz táctil: menú, marcador, barra de potencia, botones, comentarista
## (textos grandes que saltan), estrellas y tarjeta final.

signal action
signal action_released
signal view_toggled
signal special_toggled
signal skip_pressed
signal play_pressed(duel: bool, world: int)
signal play_hotseat(world: int)
signal menu_pressed
signal restart
signal pause_pressed
signal resume_pressed
signal quit_pressed
signal language_pressed
signal language_chosen(code: String)
signal wifi_pressed
signal quit_game_pressed
signal lobby_host(player_name: String)
signal lobby_join(ip: String, player_name: String)
signal lobby_start(world: int)
signal lobby_back

const Meter = preload("res://scripts/meter.gd")
const Stars = preload("res://scripts/stars.gd")

const CREAM := Color(1.0, 0.97, 0.9)
const INK := Color(0.2, 0.15, 0.12)
const RED := Color(0.86, 0.3, 0.24)
const GREEN := Color(0.3, 0.6, 0.32)
const BLUE := Color(0.25, 0.45, 0.7)
const PURPLE := Color(0.55, 0.38, 0.72)
const GRAY := Color(0.4, 0.36, 0.42)

var aim_hold := 0.0
## Vídeo y capturas de la tienda: sin botones de saltar turno ni de pausa.
var showcase := false
## Texto del botón grande mientras rueda la bola con un salto o un freno
## preparados (vacío si no hay ninguno).
var roll_action := ""
var special_btn: Button
var _special_avail := false
var _special_hint := ""
var _unlock_panel: Control
var root: Control
var game_ui: Control
var hole_label: Label
var strokes_label: Label
var seeds_label: Label
var total_label: Label
var msg_label: Label
var sub_label: Label
var flash_label: Label
var shout_label: Label
var turn_label: Label
var hint_label: Label
var dist_label: Label
var shot_label: Label
var stars: Control
var meter: Control
var shoot_btn: Button
var view_btn: Button
var left_btn: Button
var right_btn: Button
var skip_btn: Button
var card: Control
var menu: Control
var lobby: Control
var pause_btn: Button
var pause_panel: Control
var lang_panel: Control
var _msg_tween: Tween
var _flash_tween: Tween
var _shout_tween: Tween


func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_safe_area()
	get_viewport().size_changed.connect(_fit_safe_area)
	game_ui = Control.new()
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_ui)
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top_panel := _panel(Color(0.1, 0.12, 0.08, 0.35), 18)
	game_ui.add_child(top_panel)
	_place(top_panel, 0, 0, 0, 0, 12, 8, 520, 122)
	hole_label = _label(28)
	_place(hole_label, 0, 0, 0, 0, 28, 12, 520, 50)
	strokes_label = _label(22)
	_place(strokes_label, 0, 0, 0, 0, 28, 50, 520, 82)
	seeds_label = _label(22)
	_place(seeds_label, 0, 0, 0, 0, 28, 82, 520, 114)
	seeds_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	total_label = _label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(total_label, 0.5, 0, 1, 0, 0, 12, -100, 50)
	turn_label = _label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(turn_label, 0.5, 0, 1, 0, 0, 52, -100, 86)
	turn_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	msg_label = _label(72, HORIZONTAL_ALIGNMENT_CENTER)
	_place(msg_label, 0, 0.22, 1, 0.22, 0, -50, 0, 50)
	sub_label = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(sub_label, 0, 0.22, 1, 0.22, 0, 50, 0, 130)
	shout_label = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_place(shout_label, 0, 0.42, 1, 0.42, 0, -45, 0, 45)
	flash_label = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_place(flash_label, 0, 0.62, 1, 0.62, 0, -30, 0, 30)
	hint_label = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_place(hint_label, 0.2, 0, 0.8, 0, 0, 128, 0, 158)
	hint_label.modulate.a = 0.85
	dist_label = _label(22, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(dist_label, 1, 0, 1, 0, -360, 104, -100, 136)
	shot_label = _label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(shot_label, 1, 0, 1, 0, -360, 138, -100, 174)
	stars = Stars.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(stars)
	_place(stars, 0.5, 0.22, 0.5, 0.22, -150, 135, 150, 215)
	stars.visible = false

	meter = Meter.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(meter)
	_place(meter, 1, 0, 1, 0, -84, 110, -32, 470)

	shoot_btn = _button("", 34, RED, 90)
	game_ui.add_child(shoot_btn)
	_place(shoot_btn, 1, 1, 1, 1, -300, -200, -120, -20)
	shoot_btn.button_down.connect(func() -> void: action.emit())
	shoot_btn.button_up.connect(func() -> void: action_released.emit())
	skip_btn = _button("", 28, BLUE, 20)
	game_ui.add_child(skip_btn)
	_place(skip_btn, 1, 1, 1, 1, -250, -110, -30, -30)
	skip_btn.pressed.connect(func() -> void: skip_pressed.emit())
	skip_btn.visible = false

	left_btn = _button("<", 44, BLUE, 50)
	game_ui.add_child(left_btn)
	_place(left_btn, 0, 1, 0, 1, 20, -130, 120, -30)
	left_btn.button_down.connect(func() -> void: aim_hold = -1.0)
	left_btn.button_up.connect(func() -> void: aim_hold = 0.0)
	right_btn = _button(">", 44, BLUE, 50)
	game_ui.add_child(right_btn)
	_place(right_btn, 0, 1, 0, 1, 132, -130, 232, -30)
	right_btn.button_down.connect(func() -> void: aim_hold = 1.0)
	right_btn.button_up.connect(func() -> void: aim_hold = 0.0)

	view_btn = _button("", 26, Color(0.4, 0.36, 0.42), 18)
	game_ui.add_child(view_btn)
	_place(view_btn, 0, 1, 0, 1, 252, -112, 402, -44)
	view_btn.pressed.connect(func() -> void: view_toggled.emit())
	special_btn = _button("", 24, GRAY, 18)
	game_ui.add_child(special_btn)
	_place(special_btn, 0, 1, 0, 1, 414, -112, 660, -44)
	special_btn.pressed.connect(func() -> void: special_toggled.emit())
	special_btn.visible = false

	pause_btn = _button("II", 28, Color(0.4, 0.36, 0.42), 18)
	game_ui.add_child(pause_btn)
	_place(pause_btn, 1, 0, 1, 0, -86, 12, -24, 72)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	refresh_texts()


## Textos fijos de los botones (se repiten al cambiar de idioma).
func refresh_texts() -> void:
	skip_btn.text = tr("BTN_SKIP")
	view_btn.text = tr("BTN_VIEW")


# --- Marcador -----------------------------------------------------------------

func set_hole(n: int, total: int, hole_name: String) -> void:
	hole_label.text = tr("HUD_HOLE") % [n, total, tr(hole_name)]


func set_strokes(who: String, strokes: int, par: int) -> void:
	strokes_label.text = tr("HUD_STROKES") % [par, who.to_upper(), strokes]


func set_seeds(got: int, total: int) -> void:
	seeds_label.text = tr("HUD_SEEDS") % [got, total]


func set_total(text: String) -> void:
	total_label.text = text


func set_turn(text: String) -> void:
	turn_label.text = text


func set_distance(d: float) -> void:
	dist_label.text = tr("HUD_TO_HOLE") % d


func set_shot(text: String) -> void:
	shot_label.text = text


## Botón de golpe especial: texto, si hay alguno disponible, si hay uno
## elegido (cambia de color) y la ayuda que se muestra al apuntar.
func set_special(text: String, available: bool, active: bool, hint: String) -> void:
	special_btn.text = text
	_special_avail = available
	_special_hint = hint
	_style_button(special_btn, PURPLE if active else GRAY, 18)
	if left_btn.visible:
		special_btn.visible = available
		hint_label.text = hint if hint != "" else tr("HINT_AIM")


func set_meter(v: float, guide: float, locked: float = -1.0, zone: float = 0.0,
		perfect: float = 0.0) -> void:
	meter.value = v
	meter.guide = guide
	meter.locked = locked
	meter.zone = zone
	meter.perfect = perfect
	meter.queue_redraw()


## Fases: aim, power, accuracy, rolling, cpu (turno del rival) o vacía.
func set_phase(phase: String) -> void:
	var aiming := phase == "aim"
	left_btn.visible = aiming
	right_btn.visible = aiming
	special_btn.visible = aiming and _special_avail
	view_btn.visible = aiming or phase == "rolling"
	var swinging := phase in ["aim", "power", "accuracy"]
	shoot_btn.visible = swinging or (phase == "rolling" and roll_action != "")
	meter.visible = swinging or phase == "cpu"
	dist_label.visible = swinging
	shot_label.visible = swinging
	skip_btn.visible = phase == "cpu" and not showcase
	pause_btn.visible = not showcase
	if phase == "watch":
		meter.visible = true
	match phase:
		"aim":
			shoot_btn.text = tr("BTN_SWING")
			hint_label.text = _special_hint if _special_hint != "" else tr("HINT_AIM")
		"power":
			shoot_btn.text = tr("BTN_POWER")
			hint_label.text = tr("HINT_POWER")
		"accuracy":
			shoot_btn.text = tr("BTN_NOW")
			hint_label.text = tr("HINT_ACCURACY")
		"rolling":
			if roll_action != "":
				shoot_btn.text = roll_action
				hint_label.text = tr("HINT_ROLL_SPECIAL")
			else:
				hint_label.text = tr("HINT_ROLLING")
		_:
			hint_label.text = ""


# --- Mensajes -------------------------------------------------------------------

func show_message(title: String, sub: String, col: Color, duration: float) -> void:
	msg_label.text = title
	msg_label.add_theme_color_override("font_color", col)
	sub_label.text = sub
	msg_label.modulate.a = 1.0
	sub_label.modulate.a = 1.0
	_pop(msg_label, 0.6)
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.4)
	_msg_tween.parallel().tween_property(sub_label, "modulate:a", 0.0, 0.4)


func flash(text: String, col: Color) -> void:
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", col)
	flash_label.modulate.a = 1.0
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.9)
	_flash_tween.tween_property(flash_label, "modulate:a", 0.0, 0.35)


## Comentarista: texto grande que salta y se desvanece.
func shout(text: String, col: Color = Color(1, 0.9, 0.35)) -> void:
	shout_label.text = text
	shout_label.add_theme_color_override("font_color", col)
	shout_label.modulate.a = 1.0
	_pop(shout_label, 0.3)
	if _shout_tween:
		_shout_tween.kill()
	_shout_tween = create_tween()
	_shout_tween.tween_interval(1.1)
	_shout_tween.tween_property(shout_label, "modulate:a", 0.0, 0.3)


func _pop(l: Control, from: float) -> void:
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE * from
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## Aviso de algo nuevo desbloqueado (golpe especial o mundo).
func show_unlock(title: String, item: String, desc: String) -> void:
	if _unlock_panel:
		_unlock_panel.queue_free()
	var panel := _panel(Color(0.12, 0.1, 0.2, 0.92), 22)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 0.85, 0.35)
	root.add_child(panel)
	_place(panel, 0.5, 0, 0.5, 0, -360, 170, 360, 360)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_cell(title, 26, Color(1, 0.85, 0.35)))
	vb.add_child(_cell(item, 44, CREAM))
	if desc != "":
		var d := _cell(desc, 22, Color(0.85, 0.9, 1.0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(660, 0)
		vb.add_child(d)
	_unlock_panel = panel
	panel.pivot_offset = Vector2(360, 0)
	panel.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free())
	Sfx.play("big_fanfare", -4.0)


func show_stars(count: int, duration: float) -> void:
	stars.visible = true
	stars.show_count(count)
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: stars.visible = false)


# --- Menú principal ---------------------------------------------------------------

func show_menu(worlds: Array, star_counts: Array, total_stars: int, language_text: String,
		unlock_all: bool = false, specials: Array = []) -> void:
	hide_menu()
	hide_scorecard()
	game_ui.visible = false
	menu = Control.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.1, 0.12, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _cell(tr("GAME_TITLE").to_upper(), 84, CREAM)
	menu.add_child(title)
	_place(title, 0, 0, 1, 0, 0, 26, 0, 126)
	var sub := _cell(tr("MENU_STARS") % total_stars, 28, Color(1, 0.88, 0.4))
	menu.add_child(sub)
	_place(sub, 0, 0, 1, 0, 0, 132, 0, 168)
	# Golpes especiales: los conseguidos y cuántas estrellas faltan para el resto.
	if not specials.is_empty():
		var parts := []
		for s in specials:
			if s["open"]:
				parts.append(tr(s["name"]))
			else:
				parts.append(tr(s["name"]) + " " + tr("MENU_SP_LOCKED") % s["stars"])
		var sp := _cell(tr("MENU_SPECIALS") + "   " + "   ·   ".join(parts), 22, Color(0.8, 0.9, 1.0))
		menu.add_child(sp)
		_place(sp, 0, 0, 1, 0, 0, 168, 0, 200)

	for i in worlds.size():
		var w: Dictionary = worlds[i]
		var unlocked := unlock_all or total_stars >= int(w["stars_needed"])
		var playable := unlocked and int(star_counts[i]) >= 0
		var cardp := _panel(Color(1, 0.97, 0.9, 0.92) if unlocked else Color(0.5, 0.5, 0.5, 0.7), 22)
		var sbc: StyleBoxFlat = cardp.get_theme_stylebox("panel")
		sbc.set_content_margin_all(14)
		menu.add_child(cardp)
		# Cuatro tarjetas en fila, centradas.
		var cw := 296
		var gap := 14
		var x0 := -(cw * worlds.size() + gap * (worlds.size() - 1)) / 2 + i * (cw + gap)
		_place(cardp, 0.5, 0.5, 0.5, 0.5, x0, -150, x0 + cw, 262)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		cardp.add_child(vb)
		vb.add_child(_cell(tr("MENU_WORLD") % (i + 1), 20, INK.lightened(0.3)))
		var wname := _cell(tr(w["name"]), 25, INK)
		wname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wname.custom_minimum_size = Vector2(cw - 28, 74)
		wname.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vb.add_child(wname)
		if not unlocked:
			var lk := _cell(tr("MENU_LOCKED") % w["stars_needed"], 20, INK)
			lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lk.custom_minimum_size = Vector2(cw - 28, 0)
			vb.add_child(lk)
		elif not playable:
			vb.add_child(_cell(tr("MENU_SOON"), 20, INK))
		else:
			vb.add_child(_cell(tr("MENU_WORLD_STARS") % star_counts[i], 20, INK))
			var duel := _button(tr("MENU_DUEL"), 21, RED, 16)
			duel.custom_minimum_size = Vector2(0, 62)
			duel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			duel.pressed.connect(func() -> void: play_pressed.emit(true, i))
			vb.add_child(duel)
			var solo := _button(tr("MENU_PRACTICE"), 21, GREEN, 16)
			solo.custom_minimum_size = Vector2(0, 54)
			solo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			solo.pressed.connect(func() -> void: play_pressed.emit(false, i))
			vb.add_child(solo)
			var two := _button(tr("MENU_TWO_PLAYERS"), 21, BLUE, 16)
			two.custom_minimum_size = Vector2(0, 54)
			two.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			two.pressed.connect(func() -> void: play_hotseat.emit(i))
			vb.add_child(two)
	var lang := _button(language_text, 22, Color(0.4, 0.36, 0.42), 16)
	menu.add_child(lang)
	_place(lang, 0.5, 1, 0.5, 1, -300, -86, 300, -24)
	lang.pressed.connect(func() -> void: language_pressed.emit())
	var wifi := _button(tr("MENU_WIFI"), 24, BLUE, 16)
	menu.add_child(wifi)
	_place(wifi, 0, 1, 0, 1, 24, -86, 330, -24)
	wifi.pressed.connect(func() -> void: wifi_pressed.emit())
	# En iOS las apps no pueden cerrarse solas (norma de la App Store): sin botón Salir.
	if OS.get_name() != "iOS":
		var quit := _button(tr("BTN_QUIT"), 24, RED, 16)
		menu.add_child(quit)
		_place(quit, 1, 1, 1, 1, -330, -86, -24, -24)
		quit.pressed.connect(func() -> void: quit_game_pressed.emit())


func hide_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null
	game_ui.visible = true


# --- Tarjeta final ----------------------------------------------------------------

func hide_scorecard() -> void:
	if card:
		card.queue_free()
		card = null


## Con "aside" la tarjeta va a la derecha, para que se vea al personaje bailando.
func show_scorecard(holes: Array, rows: Array, note: String, aside: bool = false) -> void:
	hide_scorecard()
	set_phase("")
	var panel := _panel(Color(0.08, 0.14, 0.1, 0.94), 22)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 0.85, 0.35)
	root.add_child(panel)
	if aside:
		_place(panel, 1, 0.5, 1, 0.5, -780, -230, -20, 230)
	else:
		_place(panel, 0.5, 0.5, 0.5, 0.5, -380, -230, 380, 230)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(_cell(tr("CARD_TITLE"), 40, Color(1, 0.85, 0.35)))

	var grid := GridContainer.new()
	grid.columns = holes.size() + 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(grid)
	var gray := Color(0.7, 0.75, 0.7)
	grid.add_child(_cell(tr("CARD_HOLE"), 22, gray))
	for i in holes.size():
		grid.add_child(_cell(str(i + 1), 22, gray))
	grid.add_child(_cell(tr("CARD_TOTAL"), 22, gray))
	var par_total := 0
	grid.add_child(_cell(tr("CARD_PAR"), 26, Color.WHITE))
	for h in holes:
		par_total += int(h["par"])
		grid.add_child(_cell(str(h["par"]), 26, Color.WHITE))
	grid.add_child(_cell(str(par_total), 26, Color.WHITE))
	for row in rows:
		var total := 0
		grid.add_child(_cell(str(row["name"]).to_upper(), 28, row["color"]))
		var scores: Array = row["scores"]
		for i in scores.size():
			var s: int = scores[i]
			var par: int = holes[i]["par"]
			total += s
			var col := Color.WHITE
			if s < par:
				col = Color(0.45, 1, 0.5)
			elif s > par:
				col = Color(1, 0.6, 0.4)
			grid.add_child(_cell(str(s), 28, col))
		grid.add_child(_cell(str(total), 28, row["color"]))

	vb.add_child(_cell(note, 30, Color(0.75, 1, 0.75)))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var again := _button(tr("BTN_AGAIN"), 28, GREEN, 18)
	again.custom_minimum_size = Vector2(240, 68)
	again.pressed.connect(func() -> void: restart.emit())
	hb.add_child(again)
	var back := _button(tr("BTN_MENU"), 28, BLUE, 18)
	back.custom_minimum_size = Vector2(200, 68)
	back.pressed.connect(func() -> void: menu_pressed.emit())
	hb.add_child(back)
	card = panel


## Lluvia de confeti por encima de todo (en la tarjeta final).
func confetti(duration: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = 160
	p.lifetime = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var vp := root.get_viewport_rect().size
	p.position = Vector2(vp.x * 0.5, -30)
	p.emission_rect_extents = Vector2(vp.x * 0.55, 10)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 180)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 11.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array()
	grad.colors = PackedColorArray()
	var cols := [Color(1, 0.35, 0.3), Color(1, 0.85, 0.3), Color(0.4, 0.8, 1.0),
		Color(0.5, 0.95, 0.5), Color(1, 0.6, 0.85)]
	for i in cols.size():
		grad.add_point(float(i) / (cols.size() - 1), cols[i])
	p.color_initial_ramp = grad
	root.add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func() -> void: p.emitting = false)
	tw.tween_interval(p.lifetime + 0.5)
	tw.tween_callback(p.queue_free)


# --- Sala de Wi-Fi -------------------------------------------------------------------

## Pantalla de la sala. `view` lleva: mode ("search" o "room"), name, games
## (ip -> {name, players}), status (texto), y en la sala: players (nombres),
## host (bool), ips, worlds (nombres de los mundos disponibles), world.
func show_lobby(view: Dictionary) -> void:
	hide_menu()
	hide_lobby()
	game_ui.visible = false
	lobby = Control.new()
	root.add_child(lobby)
	lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.1, 0.12, 0.45)
	lobby.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(Color(0.08, 0.14, 0.1, 0.95), 22)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.set_border_width_all(3)
	sb.border_color = CREAM
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby.add_child(panel)
	_place(panel, 0.5, 0.5, 0.5, 0.5, -440, -320, 440, 320)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	vb.add_child(_cell(tr("MENU_WIFI"), 38, Color(1, 0.85, 0.35)))
	if view.get("status", "") != "":
		vb.add_child(_cell(view["status"], 22, Color(1, 0.75, 0.6)))
	if view["mode"] == "search":
		vb.add_child(_cell(tr("NET_SAME_WIFI"), 20, Color(0.8, 0.85, 0.8)))
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 12)
		vb.add_child(name_row)
		name_row.add_child(_cell(tr("NET_NAME"), 24, CREAM))
		var name_edit := _line_edit(view["name"], tr("NET_NAME"))
		name_row.add_child(name_edit)
		var create := _button(tr("NET_CREATE"), 26, GREEN, 16)
		create.custom_minimum_size = Vector2(0, 62)
		create.pressed.connect(func() -> void: lobby_host.emit(name_edit.text))
		vb.add_child(create)
		vb.add_child(_cell(tr("NET_FOUND"), 22, CREAM))
		var games: Dictionary = view.get("games", {})
		if games.is_empty():
			vb.add_child(_cell(tr("NET_SEARCHING"), 20, Color(0.75, 0.8, 0.75)))
		for ip in games:
			var g: Dictionary = games[ip]
			var join := _button(tr("NET_JOIN_GAME") % g["name"], 24, BLUE, 16)
			join.custom_minimum_size = Vector2(0, 56)
			join.pressed.connect(func() -> void: lobby_join.emit(ip, name_edit.text))
			vb.add_child(join)
		var ip_row := HBoxContainer.new()
		ip_row.add_theme_constant_override("separation", 12)
		vb.add_child(ip_row)
		var ip_edit := _line_edit(str(view.get("ip", "")), tr("NET_IP_HINT"))
		ip_row.add_child(ip_edit)
		var by_ip := _button(tr("NET_JOIN_IP"), 22, BLUE, 16)
		by_ip.custom_minimum_size = Vector2(260, 54)
		by_ip.pressed.connect(func() -> void: lobby_join.emit(ip_edit.text.strip_edges(), name_edit.text))
		ip_row.add_child(by_ip)
	else:
		for n in view.get("players", []):
			vb.add_child(_cell("•  " + str(n), 28, CREAM))
		if view.get("host", false):
			var ips: Array = view.get("ips", [])
			if not ips.is_empty():
				vb.add_child(_cell(tr("NET_YOUR_IP") % ips[0], 20, Color(0.75, 0.8, 0.75)))
			var worlds: Array = view.get("worlds", [])
			var wrow := HBoxContainer.new()
			wrow.alignment = BoxContainer.ALIGNMENT_CENTER
			wrow.add_theme_constant_override("separation", 12)
			vb.add_child(wrow)
			for w in worlds.size():
				var wb := _button(tr(worlds[w]), 22, RED if w == view.get("world", 0) else Color(0.4, 0.36, 0.42), 16)
				wb.custom_minimum_size = Vector2(300, 56)
				wb.pressed.connect(func() -> void: lobby_start.emit(-1 - w))
				wrow.add_child(wb)
			if view.get("players", []).size() < 2:
				vb.add_child(_cell(tr("NET_WAITING_GUEST"), 22, Color(0.8, 0.85, 0.8)))
			else:
				var start := _button(tr("NET_START"), 28, GREEN, 16)
				start.custom_minimum_size = Vector2(0, 66)
				start.pressed.connect(func() -> void: lobby_start.emit(view.get("world", 0)))
				vb.add_child(start)
		else:
			vb.add_child(_cell(tr("NET_WAITING_HOST"), 22, Color(0.8, 0.85, 0.8)))
	var back := _button(tr("BTN_BACK"), 24, Color(0.4, 0.36, 0.42), 16)
	back.custom_minimum_size = Vector2(0, 54)
	back.pressed.connect(func() -> void: lobby_back.emit())
	vb.add_child(back)


func hide_lobby() -> void:
	if lobby:
		lobby.queue_free()
		lobby = null


func _line_edit(text: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.max_length = 20
	e.custom_minimum_size = Vector2(0, 54)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_size_override("font_size", 24)
	return e


# --- Selector de idioma -------------------------------------------------------------

## Muestra todos los idiomas a la vez; el actual aparece resaltado.
func show_language_picker(options: Array, current: String) -> void:
	hide_language_picker()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			hide_language_picker())
	var panel := _panel(Color(0.08, 0.14, 0.1, 0.95), 22)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.set_border_width_all(3)
	sb.border_color = CREAM
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(panel)
	_place(panel, 0.5, 0.5, 0.5, 0.5, -500, -205, 500, 205)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	vb.add_child(_cell(tr("LANGUAGE"), 36, CREAM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(grid)
	for opt in options:
		var code: String = opt[0]
		var chosen := code == current
		var b := _button(opt[1], 24, GREEN if chosen else Color(0.4, 0.36, 0.42), 16)
		b.custom_minimum_size = Vector2(228, 68)
		b.pressed.connect(func() -> void:
			hide_language_picker()
			language_chosen.emit(code))
		grid.add_child(b)
	lang_panel = shade


func hide_language_picker() -> void:
	if lang_panel:
		lang_panel.queue_free()
		lang_panel = null


# --- Pausa -------------------------------------------------------------------------

func show_pause() -> void:
	hide_pause()
	var panel := _panel(Color(0.08, 0.14, 0.1, 0.94), 22)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.set_border_width_all(3)
	sb.border_color = CREAM
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	_place(panel, 0.5, 0.5, 0.5, 0.5, -240, -170, 240, 170)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	vb.add_child(_cell(tr("PAUSE_TITLE"), 44, CREAM))
	var cont := _button(tr("BTN_CONTINUE"), 28, GREEN, 18)
	cont.custom_minimum_size = Vector2(0, 72)
	cont.pressed.connect(func() -> void: resume_pressed.emit())
	vb.add_child(cont)
	var quit := _button(tr("BTN_BACK_MENU"), 28, BLUE, 18)
	quit.custom_minimum_size = Vector2(0, 72)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	vb.add_child(quit)
	pause_panel = panel


func hide_pause() -> void:
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null


# --- Área segura (notch) ------------------------------------------------------------

## Encoge la interfaz para que nada quede bajo el notch, la cámara perforada o
## las esquinas redondeadas (en iPhone en horizontal, la barra de fuerza quedaba
## tapada). Se recalcula al girar el móvil.
func _fit_safe_area() -> void:
	var m := _safe_margins()
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -m.size.x
	root.offset_bottom = -m.size.y


## Márgenes seguros en unidades de la interfaz: position = izquierda/arriba,
## size = derecha/abajo. En escritorio no se aplica (el área segura es la del
## monitor, no la de la ventana).
func _safe_margins() -> Rect2:
	if not OS.has_feature("mobile"):
		return Rect2()
	var window := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window.x <= 0.0 or safe.size.x <= 0.0:
		return Rect2()
	var scale := get_viewport().get_visible_rect().size / window
	var left_top := safe.position * scale
	var right_bottom := (window - safe.end) * scale
	return Rect2(left_top.max(Vector2.ZERO), right_bottom.max(Vector2.ZERO))


# --- Utilidades ---------------------------------------------------------------------

func _panel(col: Color, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := _cell("", font_size, Color.WHITE)
	l.horizontal_alignment = align
	game_ui.add_child(l)
	return l


func _cell(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 5))
	return l


func _button(text: String, font_size: int, col: Color, radius: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, CREAM)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_color_override("font_outline_color", col.darkened(0.5))
	b.add_theme_constant_override("outline_size", 6)
	_style_button(b, col, radius)
	return b


func _style_button(b: Button, col: Color, radius: int) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var c := col
		match st:
			"pressed":
				c = col.darkened(0.3)
			"hover":
				c = col.lightened(0.08)
			"disabled":
				c = Color(col.r, col.g, col.b, 0.35)
		sb.bg_color = c
		sb.set_corner_radius_all(radius)
		sb.set_border_width_all(4)
		sb.border_color = CREAM
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		if st == "focus":
			sb.draw_center = false
			sb.set_border_width_all(0)
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)


func _place(c: Control, al: float, at: float, ar: float, ab: float,
		l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
