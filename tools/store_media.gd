extends SceneTree
## Vídeo de vista previa y capturas para las tiendas, con el render real del juego.
## El jugador tira solo siguiendo un plan exacto (modo escaparate de main.gd) y se
## renderiza en un SubViewport del tamaño que piden las tiendas. Con --fixed-fps 30
## cada fotograma avanza exactamente 1/30 s, así que todo sale igual en cada pasada.
##
##   Vídeo:     godot --path . --resolution 640x300 --fixed-fps 30 -s res://tools/store_media.gd -- video es 1920x886
##              (escribe build/preview/<idioma>_<tamaño>/f00000000.png... y segments.txt;
##              python tools/make_preview.py build/preview/es_1920x886 monta el .mp4)
##   Capturas:  godot --path . --resolution 640x300 --fixed-fps 30 -s res://tools/store_media.gd -- shots es
##              (build/screenshots/<idioma>/<dispositivo>_<n>.png)
##   Prueba:    ... -- dry [n]   juega los planos (o solo el n) sin guardar nada y dice cómo acaban.

const VIDEO_DIR := "res://build/preview"
const SHOTS_DIR := "res://build/screenshots"

## Tamaños de captura de App Store Connect (horizontal). `ui`: interfaz de 720 de alto.
const DEVICES := {
	# iPhone con Dynamic Island (6,1" y 6,3"): el tamaño que pide ahora App Store Connect.
	"iphone63": {size = Vector2i(2622, 1206), ui = Vector2i(1565, 720)},
	# En 4:3 el juego amplía la interfaz a lo alto (el ancho mínimo es 1280).
	"ipad13": {size = Vector2i(2752, 2064), ui = Vector2i(1280, 960)},
}

const CAPTIONS := {
	"es": {
		"jump": "Salta el arroyo desde la cuña",
		"cloud": "Vuela de isla en isla entre las nubes",
		"hop": "¡Golpe saltarín por encima de la valla!",
		"ice": "Frena en seco sobre el hielo",
		"ace": "Rebota entre setas mágicas… ¡y hoyo en uno!",
		"menu": "4 mundos para jugar tranquilo",
	},
	"en": {
		"jump": "Jump the stream off the ramp",
		"cloud": "Fly from island to island in the clouds",
		"hop": "Hop shot right over the fence!",
		"ice": "Brake hard on the ice",
		"ace": "Bounce off magic mushrooms… hole in one!",
		"menu": "4 cozy worlds to play",
	},
}

## Planos: mundo y hoyo (desde 1), punto al que apunta (x, z), fuerza (0-1),
## golpe especial y cuándo se activa (s después del golpe), y cuánto dura el plano
## desde el inicio del swing.
var clips := [
	{key = "jump", world = 0, hole = 2, aim = Vector2(1.5, 0.0), power = 0.45, seconds = 4.0},
	{key = "cloud", world = 2, hole = 2, aim = Vector2(5.5, 0.0), power = 0.25, seconds = 4.2},
	{key = "hop", world = 0, hole = 4, aim = Vector2(3.5, 1.5), power = 0.45, special = "hop",
		trigger = 1.05, seconds = 4.0},
	{key = "ice", world = 3, hole = 1, aim = Vector2(3.0, 1.5), power = 0.5, special = "brake",
		trigger = 0.9, seconds = 3.6},
	{key = "ace", world = 1, hole = 5, aim = Vector2(2.5, 1.5), power = 0.35, seconds = 5.4},
	{key = "menu", menu = true, seconds = 2.6},
]

## Capturas: plano y momento (s desde el inicio del swing).
const SHOTS := [
	{clip = 0, at = 1.55},
	{clip = 1, at = 1.7},
	{clip = 2, at = 2.2},
	{clip = 3, at = 2.0},
	{clip = 4, at = 1.8},
	{clip = 4, at = 5.0},
	{clip = 5, at = 1.5},
]

var _mode := "dry"
var _locale := "es"
var _size := Vector2i(1920, 886)
var _ui := Vector2i(1560, 720)
var _out_dir := ""
var _only := -1
var _jobs: Array = []
var _job := -1
var _viewport: SubViewport
var _main: Node
var _caption: Label
var _clip_time := -1.0
var _waiting := 0
var _saved := 0
var _clip_start := 0
var _segments := PackedStringArray()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if _mode == "dry" and args.size() > 1:
		_only = int(args[1])
	elif args.size() > 1:
		_locale = args[1]
	if _mode == "video":
		if args.size() > 2:
			var p := args[2].split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		_ui = Vector2i(roundi(720.0 * _size.x / _size.y), 720)
		_out_dir = "%s/%s_%dx%d" % [VIDEO_DIR, _locale, _size.x, _size.y]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
		for i in clips.size():
			_jobs.append({clip = i})
	elif _mode == "shots":
		for device in DEVICES:
			for i in SHOTS.size():
				_jobs.append({clip = SHOTS[i].clip, at = SHOTS[i].at, device = device, n = i + 1})
	else:
		_size = Vector2i(640, 296)
		_ui = Vector2i(1560, 720)
		for i in clips.size():
			if _only < 0 or _only == i:
				_jobs.append({clip = i})


func _make_viewport(size: Vector2i, ui: Vector2i) -> void:
	if _viewport != null:
		_viewport.queue_free()
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.size_2d_override = ui
	_viewport.size_2d_override_stretch = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.showcase = true
	_main.unlock_all = true
	_viewport.add_child(_main)
	_main.players[0]["cpu"] = true
	# main.gd aplica el idioma guardado al arrancar: se pone después el de la tienda.
	TranslationServer.set_locale(_locale)
	_main.hud.refresh_texts()
	_caption = _add_caption()


func _process(delta: float) -> bool:
	if _job == -1:
		TranslationServer.set_locale(_locale)
		if _mode != "shots":
			_make_viewport(_size, _ui)
		_next()
		return false
	if _job >= _jobs.size():
		return false
	var job: Dictionary = _jobs[_job]
	var clip: Dictionary = clips[job.clip]
	if _clip_time < 0.0:
		# Espera al inicio del swing (o, en el menú, unos fotogramas a que se monte).
		var started: bool = _main.state == _main.State.POWER if not clip.get("menu", false) \
			else _waiting > 10
		_waiting += 1
		if not started:
			return false
		_clip_time = 0.0
		_clip_start = _saved
	else:
		_clip_time += delta
	if _mode == "video":
		_viewport.get_texture().get_image().save_png("%s/f%08d.png" % [_out_dir, _saved])
		_saved += 1
	elif _mode == "shots" and _clip_time >= float(job.at):
		var path := "%s/%s/%s_%d.png" % [SHOTS_DIR, _locale, job.device, job.n]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		_viewport.get_texture().get_image().save_png(path)
		print("  ", path)
		_next()
		return false
	if _clip_time >= float(clip.seconds):
		if _mode == "video":
			_segments.append("%d %d" % [_clip_start, _saved])
			print("plano %d (%s): fotogramas %d-%d" % [job.clip, clip.key, _clip_start, _saved])
		elif _mode == "dry":
			_report(job.clip, clip)
		_next()
	return false


## Cómo ha acabado el plano (para ajustar la fuerza y el punto de mira).
func _report(i: int, clip: Dictionary) -> void:
	if clip.get("menu", false):
		print("plano %d (%s): menú" % [i, clip.key])
		return
	var p: Dictionary = _main.players[0]
	var b: Vector3 = p["ball"].global_position
	print("plano %d (%s): estado %s, golpes %d, embocada %s, bola (%.2f, %.2f) a %.2f m del hoyo" % [
		i, clip.key, _main.State.keys()[_main.state], p["strokes"], str(p["done"]), b.x, b.z,
		Vector2(b.x - _main.info["cup"].x, b.z - _main.info["cup"].z).length()])


func _next() -> void:
	_job += 1
	if _job >= _jobs.size():
		if _mode == "video":
			var file := FileAccess.open(_out_dir + "/segments.txt", FileAccess.WRITE)
			file.store_string("\n".join(_segments) + "\n")
			file.close()
			print("Listo: %d planos en %s" % [clips.size(), ProjectSettings.globalize_path(_out_dir)])
		elif _mode == "shots":
			print("Listo: capturas en ", ProjectSettings.globalize_path(SHOTS_DIR))
		quit()
		return
	var job: Dictionary = _jobs[_job]
	var clip: Dictionary = clips[job.clip]
	if _mode == "shots":
		var dev: Dictionary = DEVICES[job.device]
		_make_viewport(dev.size, dev.ui)
	_clip_time = -1.0
	_waiting = 0
	_caption.text = CAPTIONS[_locale][clip.key]
	if clip.get("menu", false):
		_main.showcase_plan = {}
		_main._show_menu()
		return
	_main.showcase_plan = {aim = clip.aim, power = clip.power, special = clip.get("special", ""),
		trigger = clip.get("trigger", 0.5)}
	_main.start_hole = int(clip.hole) - 1
	_main._on_play(false, int(clip.world))


## Franja inferior con el texto del plano, con los colores del juego.
func _add_caption() -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var band := ColorRect.new()
	band.color = Color(0.08, 0.14, 0.1, 0.82)
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -112.0
	layer.add_child(band)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 48 if _viewport.size_2d_override.x > 1200 else 38)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	label.add_theme_constant_override("outline_size", 10)
	band.add_child(label)
	_viewport.add_child(layer)
	return label
