extends RefCounted
## Construye la geometría de un hoyo a partir de su mapa de casillas (1x1 m):
## suelo con niveles y rampas, bordes, desniveles, agua, obstáculos y decorado.
##
## Mapa: "." césped, "T" salida, "H" hoyo, "s" arena, "r" rampa, "~" agua,
## "o" césped sin paredes (la bola se puede caer), "i" hielo, "j" hielo sin
## paredes, " " vacío. En la nieve (tema 3) la "s" es nieve blanda. El mapa opcional "levels" da a cada casilla una altura
## (dígito x LEVEL_H); las rampas suben o bajan entre las casillas vecinas.
## Entre casillas de distinta altura se forma un desnivel por el que la bola
## puede caer al nivel de abajo (a menos que haya una valla).

const Looks = preload("res://scripts/looks.gd")
const Windmill = preload("res://scripts/windmill.gd")
const WindZone = preload("res://scripts/wind_zone.gd")
const Bobber = preload("res://scripts/bobber.gd")
const Wisp = preload("res://scripts/wisp.gd")

const SUB := 4
const LEVEL_H := 0.25
const WALL_H := 0.2
const WALL_T := 0.12
const GROUND_Y := -0.45
const WATER_Y := -0.22
const CUP_R := 0.15

const LAYER_FLOOR := 1
const LAYER_WALLS := 2
const LAYER_MOVING := 4
const LAYER_CLIFFS := 16  # desniveles: chocan con la bola pero no tapan la vista de la CPU

const GRASS_A := Color(0.40, 0.66, 0.27)
const GRASS_B := Color(0.37, 0.62, 0.25)
const SAND_A := Color(0.95, 0.86, 0.62)
const SAND_B := Color(0.92, 0.82, 0.57)
const WOOD := Color(0.58, 0.38, 0.22)
const WOOD_DARK := Color(0.44, 0.27, 0.15)
const RAIL := Color(0.93, 0.86, 0.70)
const STONE := Color(0.66, 0.64, 0.58)
const MOSS := Color(0.36, 0.55, 0.24)
const EARTH := Color(0.52, 0.38, 0.25)
const ICE_A := Color(0.80, 0.92, 0.98)
const ICE_B := Color(0.74, 0.88, 0.96)
const SNOW_A := Color(0.97, 0.98, 1.0)
const SNOW_B := Color(0.92, 0.94, 0.98)
const ROCK := Color(0.55, 0.5, 0.52)
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var map: Array = []
var levels: Array = []
var rows := 0
var cols := 0
var height: Callable
var min_h := INF
var max_h := -INF
var winds: Array = []
var triggers: Array = []
var theme := 0
var _grass_a := GRASS_A
var _grass_b := GRASS_B
var _wood_c := WOOD
var _wood_dark_c := WOOD_DARK
var _rail_c := RAIL
var _wall_st: SurfaceTool
var _wall_body: StaticBody3D
var _cliff_body: StaticBody3D
var _ramp_cache := {}
var _rng := RandomNumberGenerator.new()


# --- Consultas del terreno ---------------------------------------------------

func tile(c: int, r: int) -> String:
	if r < 0 or r >= rows:
		return " "
	var line: String = map[r]
	if c < 0 or c >= line.length():
		return " "
	return line[c]


func tile_at(x: float, z: float) -> String:
	return tile(floori(x), floori(z))


func is_floor_char(ch: String) -> bool:
	return ch in [".", "T", "H", "s", "r", "o", "i", "j"]


## Casilla sin paredes alrededor: la bola se puede caer por sus bordes.
func _open_edge(ch: String) -> bool:
	return ch == "o" or ch == "j"


func level(c: int, r: int) -> int:
	if r < 0 or r >= levels.size():
		return 0
	var line: String = levels[r]
	if c < 0 or c >= line.length():
		return 0
	var ch := line[c]
	return int(ch) if ch.is_valid_int() else 0


## Altura del suelo de la casilla (c, r) en el punto (x, z).
func _max_level() -> int:
	var m := 0
	for line in levels:
		for ch in (line as String):
			if ch.is_valid_int():
				m = maxi(m, int(ch))
	return m


func th(c: int, r: int, x: float, z: float) -> float:
	var base := level(c, r) * LEVEL_H
	if tile(c, r) == "r":
		base = _ramp_height(c, r, x, z)
	return base + height.call(x, z)


func h(x: float, z: float) -> float:
	return th(floori(x), floori(z), x, z)


func normal_at(x: float, z: float) -> Vector3:
	var c := floori(x)
	var r := floori(z)
	var e := 0.05
	var gx := (th(c, r, x + e, z) - th(c, r, x - e, z)) / (2.0 * e)
	var gz := (th(c, r, x, z + e) - th(c, r, x, z - e)) / (2.0 * e)
	return Vector3(-gx, 1.0, -gz).normalized()


func _ramp_height(c: int, r: int, x: float, z: float) -> float:
	var key := Vector2i(c, r)
	if not _ramp_cache.has(key):
		_ramp_cache[key] = _ramp_info(c, r)
	var info: Array = _ramp_cache[key]
	var t := x if info[0] == 0 else z
	var k := clampf((t - float(info[1])) / (float(info[2]) - float(info[1])), 0.0, 1.0)
	return lerpf(info[3], info[4], k)


## La rampa une las casillas no-rampa más cercanas a ambos lados, primero en x
## y si no, en z: [eje, inicio, fin, altura_inicio, altura_fin].
func _ramp_info(c: int, r: int) -> Array:
	var lc := c - 1
	while tile(lc, r) == "r":
		lc -= 1
	var rc := c + 1
	while tile(rc, r) == "r":
		rc += 1
	if is_floor_char(tile(lc, r)) and is_floor_char(tile(rc, r)) and level(lc, r) != level(rc, r):
		return [0, float(lc + 1), float(rc), level(lc, r) * LEVEL_H, level(rc, r) * LEVEL_H]
	var ur := r - 1
	while tile(c, ur) == "r":
		ur -= 1
	var dr := r + 1
	while tile(c, dr) == "r":
		dr += 1
	if is_floor_char(tile(c, ur)) and is_floor_char(tile(c, dr)):
		return [1, float(ur + 1), float(dr), level(c, ur) * LEVEL_H, level(c, dr) * LEVEL_H]
	var flat := level(c, r) * LEVEL_H
	return [0, float(c), float(c + 1), flat, flat]


# --- Construcción -------------------------------------------------------------

func build(data: Dictionary) -> Dictionary:
	map = data["map"]
	levels = data.get("levels", [])
	rows = map.size()
	for line in map:
		cols = maxi(cols, (line as String).length())
	height = data["height"]
	_rng.seed = str(data["name"]).hash()
	theme = int(data.get("theme", 0))
	if theme == 1:
		# Bosque: césped con musgo y bordes de troncos.
		_grass_a = Color(0.34, 0.56, 0.25)
		_grass_b = Color(0.31, 0.52, 0.23)
		_wood_c = Color(0.46, 0.31, 0.19)
		_wood_dark_c = Color(0.33, 0.22, 0.13)
		_rail_c = Color(0.52, 0.64, 0.34)
	elif theme == 2:
		# Islas entre las nubes: césped claro y bordes de piedra blanca.
		_grass_a = Color(0.47, 0.72, 0.3)
		_grass_b = Color(0.44, 0.68, 0.28)
		_wood_c = Color(0.86, 0.82, 0.74)
		_wood_dark_c = Color(0.74, 0.7, 0.64)
		_rail_c = Color(0.98, 0.95, 0.86)
	elif theme == 3:
		# Cumbre nevada: césped escarchado, madera oscura y nieve en los bordes.
		_grass_a = Color(0.42, 0.62, 0.42)
		_grass_b = Color(0.39, 0.58, 0.40)
		_wood_c = Color(0.42, 0.28, 0.2)
		_wood_dark_c = Color(0.3, 0.2, 0.15)
		_rail_c = Color(0.96, 0.97, 1.0)

	var root := Node3D.new()
	root.name = "Course"
	_wall_st = SurfaceTool.new()
	_wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall_body = StaticBody3D.new()
	_wall_body.name = "Walls"
	_wall_body.collision_layer = LAYER_WALLS
	_wall_body.collision_mask = 0
	var wall_pm := PhysicsMaterial.new()
	wall_pm.bounce = 0.72
	wall_pm.friction = 0.0
	_wall_body.physics_material_override = wall_pm
	_wall_body.set_meta("kind", "wall")
	root.add_child(_wall_body)
	_cliff_body = StaticBody3D.new()
	_cliff_body.name = "Cliffs"
	_cliff_body.collision_layer = LAYER_CLIFFS
	_cliff_body.collision_mask = 0
	_cliff_body.physics_material_override = wall_pm
	_cliff_body.set_meta("kind", "wall")
	root.add_child(_cliff_body)

	var grass_st := SurfaceTool.new()
	grass_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sand_st := SurfaceTool.new()
	sand_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_st := SurfaceTool.new()
	water_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ice_st := SurfaceTool.new()
	ice_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_ice := 0
	var n_grass := 0
	var n_sand := 0
	var n_water := 0
	var tee := Vector3.ZERO
	var cup := Vector3.ZERO
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)

	for r in rows:
		for c in cols:
			var ch := tile(c, r)
			if ch != "~" and not is_floor_char(ch):
				continue
			bmin = Vector2(minf(bmin.x, c), minf(bmin.y, r))
			bmax = Vector2(maxf(bmax.x, c + 1), maxf(bmax.y, r + 1))
			if ch == "~":
				n_water += 1
				_quad(water_st, Vector3(c, WATER_Y, r), Vector3(c + 1, WATER_Y, r),
					Vector3(c + 1, WATER_Y, r + 1), Vector3(c, WATER_Y, r + 1),
					Vector3.UP, Color.WHITE)
				_water_rim(c, r)
				continue
			# Bandas de césped recién cortado; las terrazas bajas algo más oscuras
			# para que se lean los niveles desde arriba.
			var checker := r % 2 == 0
			var shade := 0.06 * (_max_level() - level(c, r)) if ch != "r" else 0.0
			if ch == "s":
				n_sand += 1
				if theme == 3:
					_floor_tile(sand_st, c, r, (SNOW_A if checker else SNOW_B).darkened(shade * 0.5))
				else:
					_floor_tile(sand_st, c, r, (SAND_A if checker else SAND_B).darkened(shade))
			elif ch == "i" or ch == "j":
				n_ice += 1
				_floor_tile(ice_st, c, r, (ICE_A if checker else ICE_B).darkened(shade * 0.6))
			else:
				n_grass += 1
				_floor_tile(grass_st, c, r, (_grass_a if checker else _grass_b).darkened(shade))
			if ch == "T":
				tee = Vector3(c + 0.5, h(c + 0.5, r + 0.5), r + 0.5)
			elif ch == "H":
				cup = Vector3(c + 0.5, h(c + 0.5, r + 0.5), r + 0.5)
			_tile_edges(c, r)

	if n_grass > 0:
		root.add_child(_floor_body(grass_st, "grass", 0.22))
	if n_sand > 0:
		root.add_child(_floor_body(sand_st, "snow" if theme == 3 else "sand", 0.3))
	if n_ice > 0:
		var ice := _floor_body(ice_st, "ice", 0.05)
		var im: ShaderMaterial = (ice.get_child(0) as MeshInstance3D).material_override
		im.set_shader_parameter("rim_strength", 0.5)
		root.add_child(ice)
	if theme == 2:
		_island_roots(root)
	if n_water > 0:
		var water := MeshInstance3D.new()
		water.mesh = water_st.commit()
		water.material_override = Looks.water()
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(water)

	winds.clear()
	triggers.clear()
	for ob in data.get("obstacles", []):
		match ob["type"]:
			"kicker":
				_kicker(root, ob)
			"pad":
				_pad(root, ob)
			"bumper":
				_bumper(root, ob)
			"pipe":
				_pipe(root, ob)
			"sweeper":
				_sweeper(root, ob)
			"seed":
				_seed(root, ob)
			"windmill":
				_windmill(root, ob)
			"stone":
				_stone(root, ob)
			"fence":
				_fence(root, ob["a"], ob["b"], ob.get("style", ""))
			"log":
				_log_tunnel(root, ob)
			"wisp":
				_wisp(root, ob)
			"tree":
				_giant_tree(root, ob)
			"wind":
				_wind(root, ob)
			"boost":
				_boost(root, ob)

	var walls := MeshInstance3D.new()
	walls.mesh = _wall_st.commit()
	walls.material_override = Looks.toon_vc(0.12, 2.5)
	root.add_child(walls)

	var flag := _cup_visual(root, cup)
	_tee_visual(root, tee)
	var bounds := AABB(Vector3(bmin.x, min_h, bmin.y),
		Vector3(bmax.x - bmin.x, maxf(max_h - min_h, 0.01), bmax.y - bmin.y))
	_scenery(root, bounds)

	return {
		"root": root,
		"tee": tee,
		"cup": cup,
		"flag": flag,
		"bounds": bounds,
		"min_h": min_h,
		"winds": winds,
		"triggers": triggers,
		"path": data.get("path", [Vector2(cup.x, cup.z)]),
	}


# --- Suelo -----------------------------------------------------------------

func _p(c: int, r: int, x: float, z: float) -> Vector3:
	var y := th(c, r, x, z)
	min_h = minf(min_h, y)
	max_h = maxf(max_h, y)
	return Vector3(x, y, z)


func _floor_tile(st: SurfaceTool, c: int, r: int, col: Color) -> void:
	var s := 1.0 / SUB
	for i in SUB:
		for j in SUB:
			var x0 := c + i * s
			var z0 := r + j * s
			var p00 := _p(c, r, x0, z0)
			var p10 := _p(c, r, x0 + s, z0)
			var p11 := _p(c, r, x0 + s, z0 + s)
			var p01 := _p(c, r, x0, z0 + s)
			_tri(st, p00, p10, p11, Vector3.UP, col)
			_tri(st, p00, p11, p01, Vector3.UP, col)


func _floor_body(st: SurfaceTool, surface: String, noise: float) -> StaticBody3D:
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = "Floor_" + surface
	body.collision_layer = LAYER_FLOOR
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	body.physics_material_override = pm
	body.set_meta("surface", surface)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Looks.toon_vc(noise, 1.4)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	return body


# --- Bordes y desniveles ------------------------------------------------------

func _edge_points(c: int, r: int, k: int) -> Array:
	match k:
		0:
			return [Vector2(c, r), Vector2(c + 1, r)]
		1:
			return [Vector2(c + 1, r), Vector2(c + 1, r + 1)]
		2:
			return [Vector2(c, r + 1), Vector2(c + 1, r + 1)]
	return [Vector2(c, r), Vector2(c, r + 1)]


func _tile_edges(c: int, r: int) -> void:
	var wall_on := [false, false, false, false]
	for k in 4:
		var d: Vector2i = DIRS[k]
		var n := tile(c + d.x, r + d.y)
		var e := _edge_points(c, r, k)
		if is_floor_char(n):
			_cliff(c, r, c + d.x, r + d.y, e[0], e[1], Vector2(d))
		elif n == "~" or _open_edge(tile(c, r)):
			# Agua o casilla "o" (pasarela sin paredes): la bola puede caerse.
			_skirt(c, r, e[0], e[1], Vector2(d))
		else:
			wall_on[k] = true
			_wall_edge(c, r, e[0], e[1], Vector2(d))
	# Postes en las esquinas exteriores para cerrar el hueco entre bordes.
	for k in 4:
		var k2 := (k + 1) % 4
		if not (wall_on[k] and wall_on[k2]):
			continue
		var corner: Vector2
		match k:
			0: corner = Vector2(c + 1, r)
			1: corner = Vector2(c + 1, r + 1)
			2: corner = Vector2(c, r + 1)
			_: corner = Vector2(c, r)
		var o := Vector2(DIRS[k]) + Vector2(DIRS[k2])
		var ctr := corner + o * WALL_T * 0.5
		var top := th(c, r, corner.x, corner.y) + WALL_H
		_wall_box(Vector3(ctr.x, (top + GROUND_Y) * 0.5, ctr.y),
			Vector3(WALL_T, top - GROUND_Y, WALL_T), _wood(), _rail_c)


func _wood() -> Color:
	return _wood_c.lerp(_wood_dark_c, _rng.randf() * 0.6)


func _wall_edge(c: int, r: int, a: Vector2, b: Vector2, out: Vector2) -> void:
	var ha := th(c, r, a.x, a.y)
	var flat := true
	for i in SUB + 1:
		var p := a.lerp(b, float(i) / SUB)
		if absf(th(c, r, p.x, p.y) - ha) > 0.004:
			flat = false
			break
	if flat:
		_wall_segment(a, b, out, maxf(ha, th(c, r, b.x, b.y)) + WALL_H, _wood(), _rail_c)
		return
	var col := _wood()
	for i in SUB:
		var p0 := a.lerp(b, float(i) / SUB)
		var p1 := a.lerp(b, float(i + 1) / SUB)
		_wall_segment(p0, p1, out, maxf(th(c, r, p0.x, p0.y), th(c, r, p1.x, p1.y)) + WALL_H, col,
			_rail_c)


func _wall_segment(p0: Vector2, p1: Vector2, out: Vector2, top: float,
		col: Color = WOOD, top_col: Color = RAIL, bottom: float = GROUND_Y,
		collide: bool = true, offset: float = 0.5, visual: bool = true) -> void:
	var mid := (p0 + p1) * 0.5 + out * WALL_T * offset
	var along := p1 - p0
	var length := along.length() + 0.004
	var size := Vector3(length, top - bottom, WALL_T)
	if absf(along.y) > absf(along.x):
		size = Vector3(WALL_T, top - bottom, length)
	_wall_box(Vector3(mid.x, (top + bottom) * 0.5, mid.y), size, col, top_col, collide, visual)


## Desnivel entre dos casillas de suelo: cara de piedra desde el borde alto
## hasta el bajo y un bloque de colisión bajo el suelo de la casilla alta.
func _cliff(c: int, r: int, nc: int, nr: int, a: Vector2, b: Vector2, out: Vector2) -> void:
	for i in SUB:
		var p0 := a.lerp(b, float(i) / SUB)
		var p1 := a.lerp(b, float(i + 1) / SUB)
		var hi0 := th(c, r, p0.x, p0.y)
		var hi1 := th(c, r, p1.x, p1.y)
		var lo0 := th(nc, nr, p0.x, p0.y)
		var lo1 := th(nc, nr, p1.x, p1.y)
		if hi0 < lo0 + 0.02 and hi1 < lo1 + 0.02:
			continue
		var t0 := Vector3(p0.x, hi0, p0.y)
		var t1 := Vector3(p1.x, hi1, p1.y)
		var b0 := Vector3(p0.x, minf(lo0, hi0), p0.y)
		var b1 := Vector3(p1.x, minf(lo1, hi1), p1.y)
		var face := Vector3(out.x, 0, out.y)
		var stone := STONE.lerp(STONE.darkened(0.2), _rng.randf())
		_quad(_wall_st, t0, t1, b1, b0, face, stone)
		# Franja de musgo en el borde superior.
		var m0 := t0 - Vector3(0, 0.035, 0)
		var m1 := t1 - Vector3(0, 0.035, 0)
		_quad(_wall_st, t0 + face * 0.002, t1 + face * 0.002, m1 + face * 0.002,
			m0 + face * 0.002, face, MOSS)
		var top := minf(hi0, hi1) - 0.002
		var walls := _wall_body
		_wall_body = _cliff_body
		_wall_segment(p0, p1, -out, top, stone, stone, GROUND_Y, true, 0.5, false)
		_wall_body = walls


func _skirt(c: int, r: int, a: Vector2, b: Vector2, out: Vector2) -> void:
	# Lateral de tierra donde el césped da al agua (sin borde: la bola cae).
	for i in SUB:
		var p0 := a.lerp(b, float(i) / SUB)
		var p1 := a.lerp(b, float(i + 1) / SUB)
		var t0 := Vector3(p0.x, th(c, r, p0.x, p0.y), p0.y)
		var t1 := Vector3(p1.x, th(c, r, p1.x, p1.y), p1.y)
		var b0 := Vector3(p0.x, GROUND_Y, p0.y)
		var b1 := Vector3(p1.x, GROUND_Y, p1.y)
		_quad(_wall_st, t0, t1, b1, b0, Vector3(out.x, 0, out.y), EARTH)


func _water_rim(c: int, r: int) -> void:
	for k in 4:
		var d: Vector2i = DIRS[k]
		var n := tile(c + d.x, r + d.y)
		if n == "~" or is_floor_char(n):
			continue
		var e := _edge_points(c, r, k)
		_wall_segment(e[0], e[1], Vector2(d), WATER_Y + 0.08, STONE, MOSS, GROUND_Y, false)


func _wall_box(center: Vector3, size: Vector3, col: Color, top_col: Color,
		collide: bool = true, visual: bool = true) -> void:
	if visual:
		_add_box(_wall_st, center, size, col, top_col)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = center
		_wall_body.add_child(cs)


# --- Obstáculos -------------------------------------------------------------

## Valla recta (horizontal o vertical) sobre una línea de casillas; su altura
## sigue la casilla más alta de las dos que separa.
func _fence(root: Node3D, a: Vector2, b: Vector2, style: String = "") -> void:
	var along := (b - a).normalized()
	var side := Vector2(-along.y, along.x) * 0.3
	var n := maxi(1, int(ceil((b - a).length() / 0.5)))
	var col := _wood()
	var is_log := style == "log"
	var base := -INF
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		var m := (p0 + p1) * 0.5
		var hm := maxf(h(m.x + side.x, m.y + side.y), h(m.x - side.x, m.y - side.y))
		base = maxf(base, hm)
		_wall_segment(p0, p1, Vector2.ZERO, hm + WALL_H, col, _rail_c, GROUND_Y, true, 0.5,
			not is_log)
	if is_log:
		# Tronco caído a lo largo de la valla, con musgo encima.
		var length := (b - a).length()
		var mid := (a + b) * 0.5
		var logm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.13
		cm.bottom_radius = 0.13
		cm.height = length + 0.1
		cm.radial_segments = 9
		logm.mesh = cm
		logm.material_override = Looks.toon(_wood_c, 0.3)
		logm.position = Vector3(mid.x, base + 0.1, mid.y)
		# El cilindro va a lo largo de Y: se gira para que siga la valla.
		logm.basis = Basis(Quaternion(Vector3.UP, Vector3(along.x, 0, along.y)))
		root.add_child(logm)
		var moss := Looks.toon(MOSS, 0.3)
		for k in int(length / 0.8) + 1:
			var mp := a.lerp(b, (k + 0.5) / (int(length / 0.8) + 1))
			var ms := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 8
			sm.rings = 4
			ms.mesh = sm
			ms.material_override = moss
			ms.scale = Vector3(0.14, 0.05, 0.14)
			ms.position = Vector3(mp.x, base + 0.22, mp.y)
			root.add_child(ms)


func _stone(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var rad: float = ob.get("r", 0.25)
	var y := h(x, z)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WALLS
	body.collision_mask = 0
	body.set_meta("kind", "wall")
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.85
	pm.friction = 0.0
	body.physics_material_override = pm
	body.position = Vector3(x, y, z)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rad
	cyl.height = 0.8
	cs.shape = cyl
	body.add_child(cs)
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad * 1.08
	sm.height = rad * 1.5
	sm.radial_segments = 7
	sm.rings = 4
	rock.mesh = sm
	rock.material_override = Looks.toon(STONE, 0.25)
	rock.position.y = rad * 0.35
	rock.rotation.y = _rng.randf() * TAU
	body.add_child(rock)
	var moss := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = rad * 0.8
	mm.height = rad * 0.5
	mm.radial_segments = 7
	mm.rings = 3
	moss.mesh = mm
	moss.material_override = Looks.toon(MOSS, 0.3)
	moss.position.y = rad * 0.95
	body.add_child(moss)
	root.add_child(body)


func _wind(root: Node3D, ob: Dictionary) -> void:
	var wz := WindZone.new()
	var rect: Rect2 = ob["rect"]
	var y := h(rect.get_center().x, rect.get_center().y)
	root.add_child(wz)
	wz.setup(rect, ob.get("dir", Vector2.RIGHT), ob.get("strength", 1.5),
		ob.get("period", 4.5), y)
	winds.append(wz)


## Molino de piedra que hace de túnel sobre el recorrido, con aspas de tela
## que giran delante de la entrada.
func _windmill(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var depth: float = ob.get("depth", 1.0)
	var gap: float = ob.get("gap", 0.6)
	var x0: float = ob.get("x0", x - 1.5)
	var x1: float = ob.get("x1", x + 1.5)
	var z0 := z - depth * 0.5
	var z1 := z + depth * 0.5
	var hb := maxf(h(x, z0), h(x, z1))
	var top := hb + 0.8
	var stone := Color(0.86, 0.82, 0.72)
	_block(Vector3(x0 - WALL_T, GROUND_Y, z0), Vector3(x - gap * 0.5, top, z1), stone, MOSS)
	_block(Vector3(x + gap * 0.5, GROUND_Y, z0), Vector3(x1 + WALL_T, top, z1), stone, MOSS)
	_block(Vector3(x - gap * 0.5, hb + 0.36, z0), Vector3(x + gap * 0.5, top, z1), stone, MOSS)

	# Torre troncocónica encalada con tejado cónico de tejas.
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.bottom_radius = 0.5
	tm.top_radius = 0.38
	tm.height = 1.5
	tm.radial_segments = 10
	tower.mesh = tm
	tower.material_override = Looks.toon(Color(0.96, 0.93, 0.85), 0.2)
	tower.position = Vector3(x, top + 0.75, z)
	root.add_child(tower)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.bottom_radius = 0.52
	rm.top_radius = 0.0
	rm.height = 0.75
	rm.radial_segments = 10
	roof.mesh = rm
	roof.material_override = Looks.toon(Color(0.78, 0.36, 0.24), 0.15)
	roof.position = Vector3(x, top + 1.5 + 0.37, z)
	root.add_child(roof)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.22, 0.34, 0.04)
	door.mesh = dm
	door.material_override = Looks.toon(WOOD_DARK)
	door.position = Vector3(x, top + 0.2, z + 0.47)
	root.add_child(door)

	var wm := Windmill.new()
	wm.name = "Windmill"
	wm.collision_layer = LAYER_MOVING
	wm.collision_mask = 0
	wm.speed = ob.get("speed", 1.0)
	wm.set_meta("kind", "wall")
	var bpm := PhysicsMaterial.new()
	bpm.bounce = 0.5
	bpm.friction = 0.0
	wm.physics_material_override = bpm
	var hub_y := top + 0.9
	wm.position = Vector3(x, hub_y, z + 0.62)
	var reach := hub_y - hb - 0.07
	var arm := BoxMesh.new()
	arm.size = Vector3(0.07, reach, 0.05)
	var sail := BoxMesh.new()
	sail.size = Vector3(0.3, reach * 0.72, 0.02)
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.34, reach - 0.1, 0.07)
	var wood_mat := Looks.toon(WOOD_DARK)
	var sail_mat := Looks.toon(Color(0.97, 0.94, 0.86), 0.1)
	for k in 4:
		var basis := Basis(Vector3(0, 0, 1), k * PI * 0.5)
		var am := MeshInstance3D.new()
		am.mesh = arm
		am.material_override = wood_mat
		am.transform = Transform3D(basis, basis * Vector3(0, reach * 0.5, 0))
		wm.add_child(am)
		var sm := MeshInstance3D.new()
		sm.mesh = sail
		sm.material_override = sail_mat
		sm.transform = Transform3D(basis, basis * Vector3(0.17, reach * 0.58, 0.02))
		wm.add_child(sm)
		var cs := CollisionShape3D.new()
		cs.shape = sh
		cs.transform = Transform3D(basis, basis * Vector3(0.1, 0.05 + (reach - 0.1) * 0.5, 0))
		wm.add_child(cs)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.09
	hm.bottom_radius = 0.09
	hm.height = 0.16
	hm.radial_segments = 8
	hub.mesh = hm
	hub.material_override = wood_mat
	hub.rotation = Vector3(PI * 0.5, 0, 0)
	wm.add_child(hub)
	wm.rotation.z = 0.4
	root.add_child(wm)


## Rampa de salto (cuña de madera) que lanza la bola por el aire.
func _kicker(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var d: Vector2 = (ob.get("dir", Vector2(0, -1)) as Vector2).normalized()
	var length: float = ob.get("len", 0.9)
	var w: float = ob.get("w", 1.2)
	var hgt: float = ob.get("h", 0.3)
	var f := Vector3(d.x, 0, d.y)
	var sd := Vector3(-d.y, 0, d.x)
	var c := Vector3(x, 0, z)
	var b0 := _ground_pt(c - f * length * 0.5 - sd * w * 0.5, -0.01)
	var b1 := _ground_pt(c - f * length * 0.5 + sd * w * 0.5, -0.01)
	var f0 := _ground_pt(c + f * length * 0.5 - sd * w * 0.5, 0.0)
	var f1 := _ground_pt(c + f * length * 0.5 + sd * w * 0.5, 0.0)
	var t0 := f0 + Vector3.UP * hgt
	var t1 := f1 + Vector3.UP * hgt
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_ramp := (t0 - b0).cross(b1 - b0).normalized()
	if n_ramp.y < 0.0:
		n_ramp = -n_ramp
	# Tablones alternos en la superficie de la rampa.
	for i in 4:
		var a0 := b0.lerp(t0, i / 4.0)
		var a1 := b1.lerp(t1, i / 4.0)
		var e0 := b0.lerp(t0, (i + 1) / 4.0)
		var e1 := b1.lerp(t1, (i + 1) / 4.0)
		_quad(st, a0, a1, e1, e0, n_ramp, WOOD if i % 2 == 0 else WOOD.lightened(0.15))
	_quad(st, f0, f1, t1, t0, f, WOOD_DARK)
	_tri(st, b0, f0, t0, -sd, WOOD_DARK)
	_tri(st, b1, f1, t1, sd, WOOD_DARK)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_FLOOR
	body.collision_mask = 0
	body.set_meta("surface", "grass")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	body.physics_material_override = pm
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Looks.toon_vc(0.1, 3.0)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([b0, b1, f0, f1, t0, t1])
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	# Con "launch", al llegar arriba la bola sale lanzada con fuerza por el aire.
	if ob.has("launch"):
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 8
		area.monitorable = false
		var top := (t0 + t1) * 0.5
		area.position = top - f * 0.12 + Vector3.UP * 0.05
		area.basis = Basis(Vector3.UP, atan2(-d.x, -d.y))
		var acs := CollisionShape3D.new()
		var ash := BoxShape3D.new()
		ash.size = Vector3(w, 0.3, 0.25)
		acs.shape = ash
		area.add_child(acs)
		root.add_child(area)
		triggers.append({"type": "launch", "area": area, "dir": f,
			"speed": float(ob["launch"]), "up": float(ob.get("up", 2.6))})


func _ground_pt(p: Vector3, dy: float) -> Vector3:
	return Vector3(p.x, h(p.x, p.z) + dy, p.z)


## Seta saltarina: al pasar por encima lanza la bola hacia arriba.
func _pad(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var y := h(x, z)
	var holder := Node3D.new()
	holder.position = Vector3(x, y, z)
	root.add_child(holder)
	var cap := _mushroom_cap(0.32, 0.07, _pad_color())
	cap.position.y = 0.01
	holder.add_child(cap)
	var area := _trigger_area(0.3, Vector3(x, y + 0.08, z))
	root.add_child(area)
	triggers.append({"type": "pad", "area": area, "node": cap, "up": ob.get("up", 3.6),
		"min_speed": ob.get("min_speed", 2.2)})


## Seta rebotadora: un hongo grande que devuelve la bola con fuerza.
func _bumper(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var rad: float = ob.get("r", 0.22)
	var y := h(x, z)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WALLS
	body.collision_mask = 0
	body.set_meta("kick", ob.get("kick", 1.6))
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.6
	pm.friction = 0.0
	body.physics_material_override = pm
	body.position = Vector3(x, y, z)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rad
	cyl.height = 0.8
	cs.shape = cyl
	body.add_child(cs)
	var look := Node3D.new()
	body.add_child(look)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = rad * 0.75
	sm.bottom_radius = rad
	sm.height = 0.3
	sm.radial_segments = 10
	stem.mesh = sm
	stem.material_override = Looks.toon(Color(0.97, 0.93, 0.82))
	stem.position.y = 0.15
	look.add_child(stem)
	var cap := _mushroom_cap(rad * 1.7, 0.2, _pad_color())
	cap.position.y = 0.28
	look.add_child(cap)
	if theme >= 2:
		stem.material_override = Looks.toon(Color(0.85, 0.92, 1.0) if theme == 3 else Color(1, 1, 1))
	body.set_meta("pop", look)
	root.add_child(body)


func _pad_color() -> Color:
	match theme:
		2:
			return Color(0.55, 0.75, 1.0)
		3:
			return Color(0.45, 0.7, 0.95)
	return Color(0.9, 0.3, 0.25)


## Flechas de impulso: la bola que pasa por encima sale disparada en su
## dirección.
func _boost(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var d: Vector2 = (ob.get("dir", Vector2(0, -1)) as Vector2).normalized()
	var holder := Node3D.new()
	holder.position = Vector3(x, h(x, z) + 0.006, z)
	holder.basis = Basis(Quaternion(Vector3.UP, normal_at(x, z))) \
		* Basis(Vector3.UP, atan2(-d.x, -d.y))
	root.add_child(holder)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.01, 0.8)
	base.mesh = bm
	base.material_override = Looks.toon(Color(0.25, 0.3, 0.42))
	holder.add_child(base)
	var arrow := Looks.glow(Color(1.0, 0.75, 0.25), 1.6)
	var arrows := Node3D.new()
	holder.add_child(arrows)
	for i in 3:
		for s in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(0.3, 0.012, 0.07)
			bar.mesh = am
			bar.material_override = arrow
			# Dos barras inclinadas forman una flecha que apunta hacia -z.
			bar.position = Vector3(s * 0.1, 0.008, 0.22 - i * 0.22)
			bar.rotation.y = -s * 0.7
			arrows.add_child(bar)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 8
	area.monitorable = false
	area.position = holder.position + Vector3.UP * 0.08
	area.basis = holder.basis
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 0.2, 0.7)
	cs.shape = sh
	area.add_child(cs)
	root.add_child(area)
	triggers.append({"type": "boost", "area": area, "node": arrows,
		"dir": Vector3(d.x, 0, d.y), "speed": float(ob.get("speed", 4.5))})


## Raíces de roca bajo las islas flotantes: bloques que cuelgan más o menos.
func _island_roots(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows:
		for c in cols:
			if not is_floor_char(tile(c, r)):
				continue
			var depth := 0.35 + _rng.randf() * 0.5
			# Más hondo en el centro de la isla (casillas con suelo alrededor).
			var inner := 0
			for d: Vector2i in DIRS:
				if is_floor_char(tile(c + d.x, r + d.y)):
					inner += 1
			depth += inner * 0.25
			var top := GROUND_Y
			var w := 1.0
			var col := ROCK.lerp(EARTH, _rng.randf() * 0.5)
			for k in 3:
				var hk := depth / 3.0
				_add_box(st, Vector3(c + 0.5, top - hk * 0.5, r + 0.5), Vector3(w, hk, w),
					col.darkened(k * 0.08), col)
				top -= hk
				w *= 0.72
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Looks.toon_vc(0.2, 2.0)
	root.add_child(mi)


func _mushroom_cap(rad: float, hgt: float, col: Color) -> Node3D:
	var cap := Node3D.new()
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = rad
	dm.height = hgt
	dm.is_hemisphere = true
	dm.radial_segments = 14
	dm.rings = 4
	dome.mesh = dm
	dome.material_override = Looks.toon(col, 0.1)
	cap.add_child(dome)
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 8
	dot.rings = 4
	var white := Looks.toon(Color(1, 0.98, 0.94))
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		var r2 := rad * (0.55 if i % 2 == 0 else 0.3)
		var spot := MeshInstance3D.new()
		spot.mesh = dot
		spot.material_override = white
		# Una semiesfera de Godot mide la mitad de "height".
		var yy := hgt * 0.5 * sqrt(maxf(0.0, 1.0 - pow(r2 / rad, 2.0)))
		spot.position = Vector3(cos(a) * r2, yy + 0.006, sin(a) * r2)
		spot.scale = Vector3(rad * 0.2, rad * 0.07, rad * 0.2)
		cap.add_child(spot)
	return cap


## Tubería: la bola entra por un agujero y sale por otro punto del recorrido.
func _pipe(root: Node3D, ob: Dictionary) -> void:
	var a: Vector2 = ob["a"]
	var b: Vector2 = ob["b"]
	var out: Vector2 = (ob.get("out", Vector2(0, -1)) as Vector2).normalized()
	var clay := Color(0.78, 0.45, 0.3)
	var portal: bool = ob.get("style", "") == "portal"
	if portal:
		_portal_look(root, a, Color(0.55, 0.85, 1.0))
		_portal_look(root, b, Color(0.8, 0.6, 1.0))
	for p: Vector2 in ([] if portal else [a, b]):
		var y := h(p.x, p.y)
		var hole := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.2
		hm.bottom_radius = 0.2
		hm.height = 0.02
		hm.radial_segments = 16
		hole.mesh = hm
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.06, 0.05, 0.05)
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hole.material_override = dark
		hole.position = Vector3(p.x, y + 0.004, p.y)
		root.add_child(hole)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.27
		tm.rings = 18
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = Looks.toon(clay, 0.15)
		ring.position = Vector3(p.x, y + 0.01, p.y)
		ring.scale = Vector3(1, 0.6, 1)
		root.add_child(ring)
	var area := _trigger_area(0.16, Vector3(a.x, h(a.x, a.y) + 0.06, a.y))
	root.add_child(area)
	triggers.append({"type": "pipe", "area": area, "portal": portal,
		"exit": Vector3(b.x + out.x * 0.05, h(b.x, b.y) + 0.09, b.y + out.y * 0.05),
		"out": Vector3(out.x, 0, out.y)})


func _portal_look(root: Node3D, p: Vector2, col: Color) -> void:
	var y := h(p.x, p.y)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.22
	dm.bottom_radius = 0.22
	dm.height = 0.01
	dm.radial_segments = 20
	disc.mesh = dm
	disc.material_override = Looks.glow(col.darkened(0.55), 0.8)
	disc.position = Vector3(p.x, y + 0.006, p.y)
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.28
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = Looks.glow(col, 2.0)
	ring.position = Vector3(p.x, y + 0.015, p.y)
	ring.scale = Vector3(1, 0.5, 1)
	root.add_child(ring)
	var motes := CPUParticles3D.new()
	motes.amount = 18
	motes.lifetime = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	motes.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = col
	motes.material_override = mat
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = 0.24
	motes.emission_ring_inner_radius = 0.18
	motes.emission_ring_height = 0.01
	motes.direction = Vector3.UP
	motes.spread = 5.0
	motes.initial_velocity_min = 0.25
	motes.initial_velocity_max = 0.45
	motes.gravity = Vector3.ZERO
	motes.position = Vector3(p.x, y + 0.02, p.y)
	root.add_child(motes)


## Tronco hueco tumbado sobre la pista: la bola pasa por dentro.
func _log_tunnel(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var length: float = ob.get("len", 3.0)
	var rad: float = ob.get("r", 1.75)
	var cy := h(x, z) + 0.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.4, 0.27, 0.16)
	var inner := Color(0.62, 0.45, 0.28)
	var ring := Color(0.78, 0.62, 0.42)
	var segs := 16
	var a0 := -0.25
	var a1 := PI + 0.25
	var z0 := z - length * 0.5
	var z1 := z + length * 0.5
	var ri := rad - 0.14
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var d0 := Vector3(cos(t0), sin(t0), 0)
		var d1 := Vector3(cos(t1), sin(t1), 0)
		var c := Vector3(x, cy, 0)
		var shade := bark.darkened(_rng.randf() * 0.15)
		var o0 := c + d0 * rad
		var o1 := c + d1 * rad
		var n0 := c + d0 * ri
		var n1 := c + d1 * ri
		var nrm := (d0 + d1).normalized()
		_quad(st, Vector3(o0.x, o0.y, z0), Vector3(o1.x, o1.y, z0), Vector3(o1.x, o1.y, z1),
			Vector3(o0.x, o0.y, z1), nrm, shade)
		_quad(st, Vector3(n0.x, n0.y, z0), Vector3(n1.x, n1.y, z0), Vector3(n1.x, n1.y, z1),
			Vector3(n0.x, n0.y, z1), -nrm, inner)
		for zz in [z0, z1]:
			var face := Vector3(0, 0, -1) if zz == z0 else Vector3(0, 0, 1)
			_quad(st, Vector3(o0.x, o0.y, zz), Vector3(o1.x, o1.y, zz), Vector3(n1.x, n1.y, zz),
				Vector3(n0.x, n0.y, zz), face, ring)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Looks.toon_vc(0.25, 2.0)
	root.add_child(mi)
	# Musgo y alguna seta brillante encima.
	var moss := Looks.toon(MOSS, 0.3)
	for k in 5:
		var ms := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 8
		sm.rings = 4
		ms.mesh = sm
		ms.material_override = moss
		var ang := PI * 0.5 + _rng.randf_range(-0.9, 0.9)
		ms.position = Vector3(x + cos(ang) * rad, cy + sin(ang) * rad, _rng.randf_range(z0 + 0.2, z1 - 0.2))
		ms.scale = Vector3(_rng.randf_range(0.2, 0.4), 0.06, _rng.randf_range(0.2, 0.4))
		root.add_child(ms)
	for k in 3:
		_glow_mushroom(root, Vector3(x + rad * 0.3 * (k - 1), cy + rad * 0.96, z1 - 0.3 - k * 0.2),
			0.9)


func _wisp(root: Node3D, ob: Dictionary) -> void:
	var a: Vector2 = ob["a"]
	var b: Vector2 = ob["b"]
	var w := Wisp.new()
	root.add_child(w)
	w.setup(Vector3(a.x, h(a.x, a.y) + 0.2, a.y), Vector3(b.x, h(b.x, b.y) + 0.2, b.y),
		ob.get("period", 3.0), ob.get("phase", 0.0), ob.get("color", Color(0.7, 1.0, 0.85)))


## Árbol anciano gigante (decorado) en el hueco central de un hoyo.
func _giant_tree(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var rad: float = ob.get("r", 1.2)
	var y := GROUND_Y
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.bottom_radius = rad
	tm.top_radius = rad * 0.7
	tm.height = 12.0
	tm.radial_segments = 12
	trunk.mesh = tm
	trunk.material_override = Looks.toon(Color(0.42, 0.29, 0.18), 0.35)
	trunk.position = Vector3(x, y + 6.0, z)
	root.add_child(trunk)
	var bark := Looks.toon(Color(0.38, 0.26, 0.16), 0.3)
	for k in 6:
		var ang := k * TAU / 6.0 + 0.3
		var root_m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 8
		sm.rings = 4
		root_m.mesh = sm
		root_m.material_override = bark
		root_m.position = Vector3(x + cos(ang) * rad * 1.05, y + 0.25, z + sin(ang) * rad * 1.05)
		root_m.scale = Vector3(0.55, 0.3, 0.25)
		root_m.rotation.y = -ang
		root.add_child(root_m)
	var leaves := [Looks.toon(Color(0.2, 0.42, 0.2), 0.25, 0.01), Looks.toon(Color(0.26, 0.5, 0.22), 0.25, 0.01)]
	for k in 7:
		var blob := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 1.0
		bm.height = 2.0
		bm.radial_segments = 10
		bm.rings = 5
		blob.mesh = bm
		blob.material_override = leaves[k % 2]
		var ang := k * TAU / 6.0
		var off := Vector3(cos(ang), 0, sin(ang)) * (1.4 if k < 6 else 0.0)
		# La copa queda por encima de la cámara de la vista general, para no tapar el hoyo.
		blob.position = Vector3(x, y + 12.5 + (1.2 if k == 6 else 0.0), z) + off * 1.5
		blob.scale = Vector3.ONE * (2.4 if k == 6 else 2.0)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(blob)
	for k in 5:
		var ang := k * TAU / 5.0 + 0.6
		_glow_mushroom(root, Vector3(x + cos(ang) * (rad + 0.15), y + 0.45, z + sin(ang) * (rad + 0.15)),
			1.2)


## Seta pequeña que brilla (decorado del bosque).
func _glow_mushroom(root: Node3D, pos: Vector3, s: float) -> void:
	var cols := [Color(0.55, 0.9, 1.0), Color(1.0, 0.6, 0.85), Color(0.95, 0.9, 0.45)]
	var col: Color = cols[_rng.randi() % cols.size()]
	var m := Node3D.new()
	m.position = pos
	m.scale = Vector3.ONE * s
	root.add_child(m)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.02
	sm.bottom_radius = 0.028
	sm.height = 0.1
	sm.radial_segments = 6
	stem.mesh = sm
	stem.material_override = Looks.toon(Color(0.95, 0.92, 0.85))
	stem.position.y = 0.05
	m.add_child(stem)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.07
	cm.height = 0.07
	cm.is_hemisphere = true
	cm.radial_segments = 10
	cm.rings = 3
	cap.mesh = cm
	cap.material_override = Looks.glow(col, 1.6)
	cap.position.y = 0.095
	m.add_child(cap)


## Brazo barredor que gira sobre un poste en medio del recorrido.
func _sweeper(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var length: float = ob.get("len", 1.6)
	var y := h(x, z)
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.09
	pm.height = 0.34
	pm.radial_segments = 8
	post.mesh = pm
	post.material_override = Looks.toon(WOOD_DARK)
	post.position = Vector3(x, y + 0.17, z)
	root.add_child(post)
	var sw := Windmill.new()
	sw.axis = Vector3.UP
	sw.speed = ob.get("speed", 1.2)
	sw.collision_layer = LAYER_MOVING
	sw.collision_mask = 0
	sw.set_meta("kind", "wall")
	var bpm := PhysicsMaterial.new()
	bpm.bounce = 0.6
	bpm.friction = 0.0
	sw.physics_material_override = bpm
	sw.position = Vector3(x, y + 0.1, z)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(length, 0.14, 0.09)
	cs.shape = sh
	sw.add_child(cs)
	var post_cs := CollisionShape3D.new()
	var pc := CylinderShape3D.new()
	pc.radius = 0.09
	pc.height = 0.3
	post_cs.shape = pc
	sw.add_child(post_cs)
	for i in 6:
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(length / 6.0, 0.12, 0.08)
		seg.mesh = bm
		seg.material_override = Looks.toon(Color(0.88, 0.28, 0.22) if i % 2 == 0 \
			else Color(0.97, 0.95, 0.9))
		seg.position.x = -length * 0.5 + length / 12.0 + i * length / 6.0
		sw.add_child(seg)
	sw.rotation.y = 0.7
	root.add_child(sw)


## Semilla dorada: se recoge al pasar la bola por ella (también en el aire).
func _seed(root: Node3D, ob: Dictionary) -> void:
	var x: float = ob["x"]
	var z: float = ob["z"]
	var y := h(x, z) + float(ob.get("y", 0.14))
	var node := Bobber.new()
	node.position = Vector3(x, y, z)
	node.scale = Vector3.ONE * 1.6
	var gold := Looks.toon(Color(1.0, 0.8, 0.25))
	gold.set_shader_parameter("rim_strength", 0.6)
	gold.set_shader_parameter("shadow_tint", Color(1.0, 0.6, 0.3))
	var nut := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 0.06
	nm.height = 0.14
	nm.radial_segments = 10
	nm.rings = 6
	nut.mesh = nm
	nut.material_override = gold
	node.add_child(nut)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.065
	cm.height = 0.065
	cm.is_hemisphere = true
	cm.radial_segments = 10
	cm.rings = 3
	cap.mesh = cm
	cap.material_override = Looks.toon(Color(0.55, 0.36, 0.18))
	cap.position.y = 0.03
	node.add_child(cap)
	var leaf := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 1.0
	lm.height = 2.0
	lm.radial_segments = 8
	lm.rings = 4
	leaf.mesh = lm
	leaf.material_override = Looks.toon(Color(0.45, 0.75, 0.3))
	leaf.scale = Vector3(0.035, 0.008, 0.018)
	leaf.position = Vector3(0.025, 0.075, 0)
	node.add_child(leaf)
	root.add_child(node)
	var area := _trigger_area(0.24, Vector3(x, y, z))
	root.add_child(area)
	triggers.append({"type": "seed", "area": area, "node": node})


func _trigger_area(radius: float, pos: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 8
	area.monitorable = false
	area.position = pos
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	area.add_child(cs)
	return area


func _block(from: Vector3, to: Vector3, col: Color, top_col: Color) -> void:
	_wall_box((from + to) * 0.5, to - from, col, top_col)


# --- Hoyo, salida y decorado ---------------------------------------------------

func _cup_visual(root: Node3D, cup: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.position = cup
	holder.basis = Basis(Quaternion(Vector3.UP, normal_at(cup.x, cup.z)))
	root.add_child(holder)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = CUP_R
	cm.bottom_radius = CUP_R
	cm.height = 0.02
	cm.radial_segments = 24
	disc.mesh = cm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.07, 0.05)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dark
	holder.add_child(disc)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = CUP_R
	tm.outer_radius = CUP_R + 0.025
	tm.rings = 24
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = Looks.toon(Color(0.97, 0.96, 0.92))
	holder.add_child(rim)

	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = cup
	root.add_child(flag)
	var pole := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.012
	pmesh.bottom_radius = 0.012
	pmesh.height = 1.1
	pmesh.radial_segments = 6
	pole.mesh = pmesh
	pole.material_override = Looks.toon(Color(0.97, 0.96, 0.92))
	pole.position.y = 0.55
	flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(0.36, 0.24, 0.012)
	cloth.mesh = cmesh
	cloth.material_override = Looks.toon(Color(0.9, 0.3, 0.22), 0.0, 0.05)
	cloth.position = Vector3(0.19, 0.96, 0)
	flag.add_child(cloth)
	return flag


func _tee_visual(root: Node3D, tee: Vector3) -> void:
	var mat := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.012, 0.55)
	mat.mesh = bm
	mat.material_override = Looks.toon(Color(0.28, 0.5, 0.22))
	mat.position = tee
	mat.basis = Basis(Quaternion(Vector3.UP, normal_at(tee.x, tee.z)))
	root.add_child(mat)


## Árboles de copa redonda, matas de hierba, flores y semillas flotando.
func _scenery(root: Node3D, bounds: AABB) -> void:
	if theme == 1:
		_forest_scenery(root, bounds)
		return
	if theme == 2:
		_sky_scenery(root, bounds)
		return
	if theme == 3:
		_snow_scenery(root, bounds)
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.13
	trunk.height = 1.0
	trunk.radial_segments = 6
	var blob := SphereMesh.new()
	blob.radius = 0.6
	blob.height = 1.1
	blob.radial_segments = 9
	blob.rings = 5
	var trunk_mat := Looks.toon(Color(0.45, 0.3, 0.18))
	var leaf_mats := [Looks.toon(Color(0.24, 0.52, 0.2), 0.25, 0.02),
		Looks.toon(Color(0.33, 0.6, 0.22), 0.25, 0.02),
		Looks.toon(Color(0.2, 0.45, 0.24), 0.25, 0.02)]
	var placed := 0
	var tries := 0
	while placed < 22 and tries < 500:
		tries += 1
		var p := Vector3(_rng.randf_range(bounds.position.x - 11.0, bounds.end.x + 11.0),
			GROUND_Y, _rng.randf_range(bounds.position.z - 11.0, bounds.end.z + 11.0))
		if p.x > bounds.position.x - 2.2 and p.x < bounds.end.x + 2.2 \
				and p.z > bounds.position.z - 2.2 and p.z < bounds.end.z + 2.2:
			continue
		var s := _rng.randf_range(0.9, 1.6)
		var tree := Node3D.new()
		tree.position = p
		tree.scale = Vector3.ONE * s
		tree.rotation.y = _rng.randf() * TAU
		root.add_child(tree)
		var t := MeshInstance3D.new()
		t.mesh = trunk
		t.material_override = trunk_mat
		t.position.y = 0.5
		tree.add_child(t)
		var mat: Material = leaf_mats[_rng.randi() % leaf_mats.size()]
		var tall := _rng.randf() < 0.3
		for k in (3 if tall else 4):
			var b := MeshInstance3D.new()
			b.mesh = blob
			b.material_override = mat
			if tall:
				b.position = Vector3(0, 1.3 + k * 0.55, 0)
				b.scale = Vector3(0.75, 0.9, 0.75) * (1.0 - k * 0.15)
			else:
				var a := k * TAU / 3.0
				b.position = Vector3(cos(a) * 0.4, 1.35 + (0.35 if k == 3 else 0.0), sin(a) * 0.4) \
					if k < 3 else Vector3(0, 1.75, 0)
				b.scale = Vector3.ONE * _rng.randf_range(0.8, 1.05)
			tree.add_child(b)
		placed += 1

	# Hierba y flores alrededor del recorrido (y en los huecos del mapa).
	var grass_pts: Array[Transform3D] = []
	var grass_cols: Array[Color] = []
	var flower_pts: Array[Transform3D] = []
	var flower_cols: Array[Color] = []
	var petals := [Color(1, 1, 1), Color(1, 0.9, 0.35), Color(1, 0.7, 0.8), Color(0.75, 0.8, 1.0)]
	for i in 2600:
		var x := _rng.randf_range(bounds.position.x - 7.0, bounds.end.x + 7.0)
		var z := _rng.randf_range(bounds.position.z - 7.0, bounds.end.z + 7.0)
		if _near_course(x, z):
			continue
		var s := _rng.randf_range(0.7, 1.4)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
			Vector3(x, GROUND_Y, z))
		if _rng.randf() < 0.12:
			flower_pts.append(xf.translated(Vector3(0, 0.18 * s, 0)))
			flower_cols.append(petals[_rng.randi() % petals.size()])
		else:
			grass_pts.append(xf)
			grass_cols.append(Color.WHITE.darkened(_rng.randf() * 0.25))
	root.add_child(_multimesh(_grass_mesh(), Looks.grass(), grass_pts, grass_cols))
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.07
	fm.radial_segments = 6
	fm.rings = 3
	root.add_child(_multimesh(fm, Looks.toon_vc(), flower_pts, flower_cols))

	# Semillas de diente de león flotando con la brisa.
	var seeds := CPUParticles3D.new()
	seeds.amount = 40
	seeds.lifetime = 12.0
	seeds.preprocess = 12.0
	seeds.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	seeds.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(1, 1, 0.95, 0.85)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	seeds.material_override = sm
	seeds.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var c := bounds.get_center()
	seeds.position = Vector3(c.x - 4.0, max_h + 1.0, c.z)
	seeds.emission_box_extents = Vector3(bounds.size.x * 0.5 + 4.0, 1.0, bounds.size.z * 0.5 + 3.0)
	seeds.direction = Vector3(1, 0.2, 0.3)
	seeds.spread = 25.0
	seeds.initial_velocity_min = 0.25
	seeds.initial_velocity_max = 0.6
	seeds.gravity = Vector3(0, -0.02, 0)
	root.add_child(seeds)


func _near_course(x: float, z: float) -> bool:
	for dx in [-0.35, 0.0, 0.35]:
		for dz in [-0.35, 0.0, 0.35]:
			var ch := tile_at(x + dx, z + dz)
			if ch == "~" or is_floor_char(ch):
				return true
	return false


func _multimesh(mesh: Mesh, mat: Material, xfs: Array[Transform3D], cols: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _grass_mesh() -> ArrayMesh:
	# Mata de 5 hojas en abanico.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.025
		var base := d * 0.03
		var tip := d * 0.12 + Vector3(0, 0.28 + 0.08 * (i % 2), 0)
		var n := side.cross(tip - base).normalized()
		for p in [base - side, base + side, tip]:
			st.set_normal(n if n.y > 0 else -n)
			st.add_vertex(p)
	return st.commit()


# --- Utilidades de malla -------------------------------------------------------

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n_hint: Vector3,
		col: Color) -> void:
	# Godot usa orden horario para las caras frontales: se corrige el orden
	# para que la cara mire hacia n_hint.
	var cr := (b - a).cross(c - a)
	if cr.dot(n_hint) > 0.0:
		var tmp := b
		b = c
		c = tmp
		cr = -cr
	var n := (-cr).normalized()
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n: Vector3, col: Color) -> void:
	_tri(st, a, b, c, n, col)
	_tri(st, a, c, d, n, col)


func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, top_col: Color) -> void:
	var hx := s.x * 0.5
	var hy := s.y * 0.5
	var hz := s.z * 0.5
	var p := [
		c + Vector3(-hx, -hy, -hz), c + Vector3(hx, -hy, -hz),
		c + Vector3(hx, -hy, hz), c + Vector3(-hx, -hy, hz),
		c + Vector3(-hx, hy, -hz), c + Vector3(hx, hy, -hz),
		c + Vector3(hx, hy, hz), c + Vector3(-hx, hy, hz),
	]
	_quad(st, p[4], p[5], p[6], p[7], Vector3.UP, top_col)
	_quad(st, p[0], p[1], p[5], p[4], Vector3(0, 0, -1), col)
	_quad(st, p[3], p[7], p[6], p[2], Vector3(0, 0, 1), col)
	_quad(st, p[0], p[4], p[7], p[3], Vector3(-1, 0, 0), col.darkened(0.06))
	_quad(st, p[1], p[2], p[6], p[5], Vector3(1, 0, 0), col.darkened(0.06))


## Bosque: árboles altos y oscuros muy juntos, helechos, setas que brillan y
## luciérnagas.
func _forest_scenery(root: Node3D, bounds: AABB) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.22
	trunk.height = 3.0
	trunk.radial_segments = 7
	var blob := SphereMesh.new()
	blob.radius = 0.9
	blob.height = 1.6
	blob.radial_segments = 9
	blob.rings = 5
	var trunk_mat := Looks.toon(Color(0.36, 0.25, 0.16), 0.25)
	var leaf_mats := [Looks.toon(Color(0.16, 0.36, 0.2), 0.25, 0.015),
		Looks.toon(Color(0.22, 0.44, 0.2), 0.25, 0.015),
		Looks.toon(Color(0.14, 0.32, 0.24), 0.25, 0.015)]
	var placed := 0
	var tries := 0
	while placed < 40 and tries < 800:
		tries += 1
		var p := Vector3(_rng.randf_range(bounds.position.x - 10.0, bounds.end.x + 10.0),
			GROUND_Y, _rng.randf_range(bounds.position.z - 10.0, bounds.end.z + 10.0))
		if p.x > bounds.position.x - 2.0 and p.x < bounds.end.x + 2.0 \
				and p.z > bounds.position.z - 2.0 and p.z < bounds.end.z + 2.0:
			continue
		var s := _rng.randf_range(1.1, 2.0)
		var tree := Node3D.new()
		tree.position = p
		tree.scale = Vector3.ONE * s
		tree.rotation.y = _rng.randf() * TAU
		root.add_child(tree)
		var t := MeshInstance3D.new()
		t.mesh = trunk
		t.material_override = trunk_mat
		t.position.y = 1.5
		tree.add_child(t)
		var mat: Material = leaf_mats[_rng.randi() % leaf_mats.size()]
		for k in 4:
			var b := MeshInstance3D.new()
			b.mesh = blob
			b.material_override = mat
			var a := k * TAU / 3.0
			b.position = Vector3(cos(a) * 0.55, 3.0, sin(a) * 0.55) if k < 3 else Vector3(0, 3.6, 0)
			b.scale = Vector3.ONE * _rng.randf_range(0.8, 1.1)
			tree.add_child(b)
		placed += 1

	# Helechos (matas grandes y oscuras) y florecillas azules.
	var fern_pts: Array[Transform3D] = []
	var fern_cols: Array[Color] = []
	var flower_pts: Array[Transform3D] = []
	var flower_cols: Array[Color] = []
	for i in 1800:
		var x := _rng.randf_range(bounds.position.x - 7.0, bounds.end.x + 7.0)
		var z := _rng.randf_range(bounds.position.z - 7.0, bounds.end.z + 7.0)
		if _near_course(x, z):
			continue
		var s := _rng.randf_range(1.2, 2.3)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
			Vector3(x, GROUND_Y, z))
		if _rng.randf() < 0.07:
			flower_pts.append(xf.scaled_local(Vector3.ONE * 0.5).translated(Vector3(0, 0.12, 0)))
			flower_cols.append([Color(0.6, 0.75, 1.0), Color(1, 1, 1)][_rng.randi() % 2])
		else:
			fern_pts.append(xf)
			fern_cols.append(Color.WHITE.darkened(_rng.randf() * 0.3))
	root.add_child(_multimesh(_grass_mesh(), Looks.grass(Color(0.08, 0.22, 0.1), Color(0.34, 0.58, 0.26)),
		fern_pts, fern_cols))
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.07
	fm.radial_segments = 6
	fm.rings = 3
	root.add_child(_multimesh(fm, Looks.toon_vc(), flower_pts, flower_cols))
	# Setas que brillan junto a los bordes del recorrido.
	var n := 0
	for i in 400:
		if n >= 26:
			break
		var x := _rng.randf_range(bounds.position.x - 1.5, bounds.end.x + 1.5)
		var z := _rng.randf_range(bounds.position.z - 1.5, bounds.end.z + 1.5)
		if _near_course(x, z) or not _near_course(x + 0.6, z) and not _near_course(x - 0.6, z) \
				and not _near_course(x, z + 0.6) and not _near_course(x, z - 0.6):
			continue
		_glow_mushroom(root, Vector3(x, GROUND_Y, z), _rng.randf_range(0.9, 1.6))
		n += 1

	# Luciérnagas.
	var flies := CPUParticles3D.new()
	flies.amount = 60
	flies.lifetime = 6.0
	flies.preprocess = 6.0
	flies.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	flies.mesh = q
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.albedo_color = Color(1.0, 0.95, 0.55)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.9, 0.4)
	fmat.emission_energy_multiplier = 3.0
	flies.material_override = fmat
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var c := bounds.get_center()
	flies.position = Vector3(c.x, max_h + 0.8, c.z)
	flies.emission_box_extents = Vector3(bounds.size.x * 0.5 + 3.0, 0.8, bounds.size.z * 0.5 + 3.0)
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.initial_velocity_min = 0.05
	flies.initial_velocity_max = 0.2
	flies.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	flies.scale_amount_curve = curve
	root.add_child(flies)


## Cielo: islotes flotantes con árboles alrededor del recorrido y nubecillas
## que pasan por debajo.
func _sky_scenery(root: Node3D, bounds: AABB) -> void:
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 8
	rock.rings = 4
	var top := CylinderMesh.new()
	top.top_radius = 1.0
	top.bottom_radius = 0.92
	top.height = 0.2
	top.radial_segments = 10
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 0.9
	blob.radial_segments = 8
	blob.rings = 4
	var rock_mat := Looks.toon(ROCK, 0.2)
	var grass_mat := Looks.toon(Color(0.45, 0.72, 0.3), 0.15)
	var leaf_mat := Looks.toon(Color(0.3, 0.6, 0.26), 0.2, 0.02)
	var trunk_mat := Looks.toon(Color(0.45, 0.3, 0.18))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.05
	trunk.bottom_radius = 0.08
	trunk.height = 0.6
	trunk.radial_segments = 6
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 400:
		tries += 1
		var p := Vector3(_rng.randf_range(bounds.position.x - 9.0, bounds.end.x + 9.0),
			_rng.randf_range(-2.5, 1.5),
			_rng.randf_range(bounds.position.z - 9.0, bounds.end.z + 9.0))
		if p.x > bounds.position.x - 2.0 and p.x < bounds.end.x + 2.0 \
				and p.z > bounds.position.z - 2.0 and p.z < bounds.end.z + 2.0:
			continue
		var s := _rng.randf_range(0.6, 1.4)
		var isle := Node3D.new()
		isle.position = p
		isle.scale = Vector3.ONE * s
		root.add_child(isle)
		var g := MeshInstance3D.new()
		g.mesh = top
		g.material_override = grass_mat
		isle.add_child(g)
		var rk := MeshInstance3D.new()
		rk.mesh = rock
		rk.material_override = rock_mat
		rk.scale = Vector3(0.95, 1.2, 0.95)
		rk.position.y = -0.9
		isle.add_child(rk)
		for k in _rng.randi_range(1, 2):
			var tree := Node3D.new()
			tree.position = Vector3(_rng.randf_range(-0.4, 0.4), 0.1, _rng.randf_range(-0.4, 0.4))
			isle.add_child(tree)
			var t := MeshInstance3D.new()
			t.mesh = trunk
			t.material_override = trunk_mat
			t.position.y = 0.3
			tree.add_child(t)
			var b := MeshInstance3D.new()
			b.mesh = blob
			b.material_override = leaf_mat
			b.position.y = 0.75
			tree.add_child(b)
		placed += 1
	# Nubecillas sueltas a la altura del recorrido y por debajo.
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	var cmat := Looks.cloud()
	for i in 16:
		var p := Vector3(_rng.randf_range(bounds.position.x - 8.0, bounds.end.x + 8.0),
			_rng.randf_range(-3.5, -1.2),
			_rng.randf_range(bounds.position.z - 8.0, bounds.end.z + 8.0))
		var cl := Node3D.new()
		cl.position = p
		root.add_child(cl)
		for k in _rng.randi_range(3, 5):
			var m := MeshInstance3D.new()
			m.mesh = puff
			m.material_override = cmat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var r := _rng.randf_range(0.5, 1.1)
			m.scale = Vector3(r * 1.3, r * 0.6, r)
			m.position = Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-0.6, 0.6))
			cl.add_child(m)
	# Pétalos llevados por el viento.
	var petals := CPUParticles3D.new()
	petals.amount = 36
	petals.lifetime = 10.0
	petals.preprocess = 10.0
	petals.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.035)
	petals.mesh = q
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(1, 0.85, 0.9, 0.9)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	petals.material_override = pm
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var c := bounds.get_center()
	petals.position = Vector3(c.x - 4.0, max_h + 1.0, c.z)
	petals.emission_box_extents = Vector3(bounds.size.x * 0.5 + 4.0, 1.0, bounds.size.z * 0.5 + 3.0)
	petals.direction = Vector3(1, 0.1, 0.2)
	petals.spread = 30.0
	petals.initial_velocity_min = 0.3
	petals.initial_velocity_max = 0.7
	petals.gravity = Vector3(0, -0.03, 0)
	root.add_child(petals)


## Nieve: abetos nevados, montones de nieve y copos cayendo.
func _snow_scenery(root: Node3D, bounds: AABB) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.height = 0.9
	cone.radial_segments = 8
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 0.32
	cap.height = 0.42
	cap.radial_segments = 8
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.07
	trunk.bottom_radius = 0.1
	trunk.height = 0.5
	trunk.radial_segments = 6
	var pine_mats := [Looks.toon(Color(0.16, 0.36, 0.3), 0.2), Looks.toon(Color(0.2, 0.42, 0.32), 0.2)]
	var snow_mat := Looks.toon(Color(0.97, 0.98, 1.0))
	snow_mat.set_shader_parameter("shadow_tint", Color(0.7, 0.8, 1.0))
	var trunk_mat := Looks.toon(Color(0.36, 0.25, 0.17))
	var placed := 0
	var tries := 0
	while placed < 30 and tries < 600:
		tries += 1
		var p := Vector3(_rng.randf_range(bounds.position.x - 10.0, bounds.end.x + 10.0),
			GROUND_Y, _rng.randf_range(bounds.position.z - 10.0, bounds.end.z + 10.0))
		if p.x > bounds.position.x - 2.0 and p.x < bounds.end.x + 2.0 \
				and p.z > bounds.position.z - 2.0 and p.z < bounds.end.z + 2.0:
			continue
		var s := _rng.randf_range(1.0, 2.0)
		var tree := Node3D.new()
		tree.position = p
		tree.scale = Vector3.ONE * s
		tree.rotation.y = _rng.randf() * TAU
		root.add_child(tree)
		var t := MeshInstance3D.new()
		t.mesh = trunk
		t.material_override = trunk_mat
		t.position.y = 0.25
		tree.add_child(t)
		var mat: Material = pine_mats[_rng.randi() % pine_mats.size()]
		for k in 3:
			var layer := MeshInstance3D.new()
			layer.mesh = cone
			layer.material_override = mat
			layer.position.y = 0.75 + k * 0.45
			layer.scale = Vector3.ONE * (1.0 - k * 0.22)
			tree.add_child(layer)
			var sn := MeshInstance3D.new()
			sn.mesh = cap
			sn.material_override = snow_mat
			sn.position.y = 0.75 + k * 0.45 + 0.26 * (1.0 - k * 0.22)
			sn.scale = Vector3.ONE * (1.0 - k * 0.22)
			tree.add_child(sn)
		placed += 1
	# Montones de nieve.
	var mound := SphereMesh.new()
	mound.radius = 1.0
	mound.height = 2.0
	mound.radial_segments = 10
	mound.rings = 5
	var pts: Array[Transform3D] = []
	var cols: Array[Color] = []
	for i in 400:
		if pts.size() >= 60:
			break
		var x := _rng.randf_range(bounds.position.x - 7.0, bounds.end.x + 7.0)
		var z := _rng.randf_range(bounds.position.z - 7.0, bounds.end.z + 7.0)
		if _near_course(x, z):
			continue
		var s := _rng.randf_range(0.3, 0.8)
		pts.append(Transform3D(Basis.from_scale(Vector3(s * 1.4, s * 0.45, s)), Vector3(x, GROUND_Y, z)))
		cols.append(Color(0.97, 0.98, 1.0).darkened(_rng.randf() * 0.05))
	root.add_child(_multimesh(mound, Looks.toon_vc(0.05), pts, cols))
	# Copos de nieve.
	var flakes := CPUParticles3D.new()
	flakes.amount = 160
	flakes.lifetime = 8.0
	flakes.preprocess = 8.0
	flakes.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	flakes.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_color = Color(1, 1, 1, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flakes.material_override = fm
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var c := bounds.get_center()
	flakes.position = Vector3(c.x, max_h + 3.0, c.z)
	flakes.emission_box_extents = Vector3(bounds.size.x * 0.5 + 5.0, 0.5, bounds.size.z * 0.5 + 5.0)
	flakes.direction = Vector3(0.3, -1, 0)
	flakes.spread = 20.0
	flakes.initial_velocity_min = 0.3
	flakes.initial_velocity_max = 0.6
	flakes.gravity = Vector3(0, -0.05, 0)
	root.add_child(flakes)
