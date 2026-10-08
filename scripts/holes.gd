extends RefCounted
## Catálogo de mundos y hoyos. Cada hoyo es un diccionario con: nombre (clave
## de traducción de locale/translations.csv), par,
## mapa de casillas (1 m cada una), niveles de altura opcionales, función de
## alturas suave, obstáculos y una ruta de puntos (x, z) hacia el hoyo que
## usan el apuntado inicial, el rival de la CPU y la prueba automática.
##
## Mapa: "." césped, "T" salida, "H" hoyo, "s" arena, "r" rampa, "~" agua,
## " " vacío. Niveles: dígito por casilla (x 0,25 m); las rampas unen niveles.
## Obstáculos: windmill (molino con túnel), stone (piedra), fence (valla de a
## a b), wind (viento con ráfagas), kicker (rampa de salto), pad (seta
## saltarina), bumper (seta rebotadora), pipe (tubería de a a b), sweeper
## (brazo giratorio), seed (semilla dorada; hay 3 por hoyo) y boost (flechas
## que lanzan la bola en su dirección). En los mundos 3 y 4 hay además hielo
## ("i"; "j" sin paredes) y nieve blanda ("s" en el tema 3).

const WORLDS := [
	{"name": "WORLD_1", "stars_needed": 0},
	{"name": "WORLD_2", "stars_needed": 12},
	{"name": "WORLD_3", "stars_needed": 24},
	{"name": "WORLD_4", "stars_needed": 40},
]


func world_holes(index: int) -> Array:
	if index == 0:
		return [colina(), arroyo(), pradera(), setas(), terrazas(), puente()]
	if index == 1:
		return [tronco(), espiritus(), estanque(), raices(), claro(), arbol()]
	if index == 2:
		return [puentes(), trampolin(), viento_alto(), escalera(), molino_cielo(), archipielago()]
	if index == 3:
		return [lago_helado(), tobogan(), ventisca(), terrazas_hielo(), glaciar(), cumbre()]
	return []


# --- Mundo 2: Bosque de los Espíritus ("theme": 1) -----------------------------------------

func tronco() -> Dictionary:
	# Un tronco hueco hace de túnel, con dos raíces dentro. Al salir, el hoyo
	# está a la derecha tras una valla: hay que dar la vuelta por arriba.
	return {
		"name": "HOLE_TRONCO",
		"theme": 1,
		"par": 3,
		"map": [
			"........",
			"......H.",
			"........",
			"  ...   ",
			"  ...   ",
			"  ...   ",
			"  ...   ",
			"  ...   ",
			"  .T.   ",
			"  ...   ",
		],
		"height": _h_tronco,
		"obstacles": [
			{"type": "log", "x": 3.5, "z": 5.5, "len": 3.0, "r": 1.75},
			{"type": "fence", "a": Vector2(5.4, 2.3), "b": Vector2(8.0, 2.3)},
			{"type": "bumper", "x": 4.6, "z": 1.0, "r": 0.18},
			{"type": "seed", "x": 2.6, "z": 5.5},
			{"type": "seed", "x": 0.5, "z": 0.5},
			{"type": "seed", "x": 7.5, "z": 2.7},
		],
		"path": [Vector2(3.5, 2.6), Vector2(3.8, 0.5), Vector2(6.5, 1.5)],
	}


func _h_tronco(x: float, z: float) -> float:
	var h := 0.0
	for rz in [4.9, 6.3]:
		h += 0.07 * exp(-pow(z - rz, 2.0) / 0.03) * (0.7 + 0.3 * sin(x * 2.7 + rz))
	h -= 0.04 * exp(-(pow(x - 6.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)
	return h


func espiritus() -> Dictionary:
	# Se entra en diagonal entre tres espíritus y el hoyo está dentro de un
	# reborde en anillo: hay que llegar con la fuerza justa.
	return {
		"name": "HOLE_ESPIRITUS",
		"theme": 1,
		"par": 3,
		"map": [
			".....",
			".....",
			"...H.",
			".....",
			".....",
			".....",
			".....",
			".....",
			".T...",
			".....",
		],
		"height": _h_espiritus,
		"obstacles": [
			{"type": "wisp", "a": Vector2(0.6, 6.0), "b": Vector2(4.4, 6.0), "period": 3.4,
				"phase": 0.0, "color": Color(0.7, 1.0, 0.85)},
			{"type": "wisp", "a": Vector2(4.4, 4.4), "b": Vector2(0.6, 4.4), "period": 2.8,
				"phase": 0.3, "color": Color(0.75, 0.85, 1.0)},
			{"type": "wisp", "a": Vector2(1.0, 1.4), "b": Vector2(1.0, 3.6), "period": 2.2,
				"phase": 0.6, "color": Color(1.0, 0.8, 0.95)},
			{"type": "seed", "x": 4.5, "z": 7.0},
			{"type": "seed", "x": 0.5, "z": 0.5},
			{"type": "seed", "x": 4.5, "z": 0.5},
		],
		"path": [Vector2(3.5, 2.5)],
	}


func _h_espiritus(x: float, z: float) -> float:
	# Reborde en anillo alrededor del hoyo.
	var d := sqrt(pow(x - 3.5, 2.0) + pow(z - 2.5, 2.0))
	return 0.06 * exp(-pow(d - 0.55, 2.0) / 0.02) - 0.01 * exp(-d * d / 0.2)


func estanque() -> Dictionary:
	# Un estanque en medio. Camino seguro: rodearlo por la izquierda. Atajo:
	# la orilla derecha no tiene paredes y lleva al portal, que te deja junto
	# al hoyo.
	return {
		"name": "HOLE_ESTANQUE",
		"theme": 1,
		"par": 3,
		"map": [
			"......",
			"..H...",
			"......",
			".~~~~o",
			".~~~~o",
			".~~~~o",
			"......",
			"....T.",
			"......",
		],
		"height": _h_estanque,
		"obstacles": [
			{"type": "pipe", "style": "portal", "a": Vector2(5.5, 3.6), "b": Vector2(2.5, 2.75),
				"out": Vector2(0, -1)},
			{"type": "seed", "x": 0.5, "z": 4.0},
			{"type": "seed", "x": 5.5, "z": 5.2},
			{"type": "seed", "x": 4.5, "z": 0.5},
		],
		"path": [Vector2(0.5, 6.5), Vector2(0.5, 2.6), Vector2(2.5, 1.5)],
	}


func _h_estanque(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 2.5, 2.0) + pow(z - 1.5, 2.0)) / 0.8)


func raices() -> Dictionary:
	# Terrazas unidas por rampas en zigzag; troncos caídos cierran los atajos.
	return {
		"name": "HOLE_RAICES",
		"theme": 1,
		"par": 4,
		"map": [
			"...T...",
			".......",
			"rr.....",
			".......",
			".....rr",
			".......",
			"rr.....",
			".......",
			"...H...",
		],
		"levels": [
			"3333333",
			"3333333",
			"  22222",
			"2222222",
			"11111  ",
			"1111111",
			"  00000",
			"0000000",
			"0000000",
		],
		"height": _h_raices,
		"obstacles": [
			{"type": "fence", "style": "log", "a": Vector2(2, 2), "b": Vector2(7, 2)},
			{"type": "fence", "style": "log", "a": Vector2(0, 4), "b": Vector2(5, 4)},
			{"type": "fence", "style": "log", "a": Vector2(2, 6), "b": Vector2(7, 6)},
			{"type": "wisp", "a": Vector2(2.3, 3.0), "b": Vector2(5.7, 3.0), "period": 3.0,
				"color": Color(0.8, 1.0, 0.7)},
			{"type": "seed", "x": 6.5, "z": 0.6},
			{"type": "seed", "x": 0.5, "z": 4.6},
			{"type": "seed", "x": 6.5, "z": 7.5},
		],
		"path": [Vector2(1.0, 1.5), Vector2(1.0, 3.3), Vector2(5.9, 3.5), Vector2(5.9, 5.3),
			Vector2(1.0, 5.5), Vector2(1.0, 7.3), Vector2(3.5, 8.5)],
	}


func _h_raices(x: float, z: float) -> float:
	return -0.035 * exp(-(pow(x - 3.5, 2.0) + pow(z - 8.5, 2.0)) / 0.6)


func claro() -> Dictionary:
	# Un claro lleno de setas rebotadoras, como un pinball. La seta saltarina
	# permite pasar por encima (y coger la semilla del aire).
	return {
		"name": "HOLE_CLARO",
		"theme": 1,
		"par": 3,
		"map": [
			".....",
			"..H..",
			".....",
			".....",
			".....",
			".....",
			".....",
			"..T..",
			".....",
		],
		"height": _h_claro,
		"obstacles": [
			{"type": "bumper", "x": 1.3, "z": 4.1, "r": 0.2, "kick": 2.0},
			{"type": "bumper", "x": 3.7, "z": 4.1, "r": 0.2, "kick": 2.0},
			{"type": "bumper", "x": 2.5, "z": 4.9, "r": 0.2, "kick": 2.0},
			{"type": "bumper", "x": 1.7, "z": 2.7, "r": 0.18, "kick": 2.0},
			{"type": "bumper", "x": 3.3, "z": 2.7, "r": 0.18, "kick": 2.0},
			{"type": "pad", "x": 2.5, "z": 6.1, "up": 3.8},
			{"type": "seed", "x": 0.5, "z": 5.5},
			{"type": "seed", "x": 4.5, "z": 5.5},
			{"type": "seed", "x": 2.5, "z": 3.7, "y": 0.55},
		],
		"path": [Vector2(0.6, 4.0), Vector2(0.6, 1.5), Vector2(2.5, 1.5)],
	}


func _h_claro(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 2.5, 2.0) + pow(z - 1.5, 2.0)) / 0.7)


func arbol() -> Dictionary:
	# Se juega alrededor de un árbol gigante: por la izquierda hay un espíritu;
	# por la derecha, un brazo giratorio.
	return {
		"name": "HOLE_ARBOL",
		"theme": 1,
		"par": 3,
		"map": [
			".......",
			".H.....",
			"..   ..",
			"..   ..",
			"..   ..",
			".......",
			"...T...",
		],
		"height": _h_arbol,
		"obstacles": [
			{"type": "tree", "x": 3.5, "z": 3.5, "r": 1.0},
			{"type": "wisp", "a": Vector2(1.0, 2.2), "b": Vector2(1.0, 4.8), "period": 2.6,
				"color": Color(0.7, 0.95, 1.0)},
			{"type": "sweeper", "x": 5.5, "z": 3.5, "len": 1.5, "speed": 1.4},
			{"type": "seed", "x": 6.5, "z": 0.5},
			{"type": "seed", "x": 0.5, "z": 5.5},
			{"type": "seed", "x": 3.5, "z": 0.5},
		],
		"path": [Vector2(1.0, 5.5), Vector2(1.0, 2.0), Vector2(1.5, 1.5)],
	}


func _h_arbol(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 1.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func colina() -> Dictionary:
	# Rampa, molino y, al salir del túnel, una valla tapa el hoyo: hay que
	# rebotar en la pared del fondo y entrar por el hueco de arriba.
	return {
		"name": "HOLE_COLINA",
		"par": 3,
		"map": [
			"......  ",
			"......  ",
			".H....  ",
			"   ...  ",
			"   ...  ",
			"   ...  ",
			"   rrr  ",
			"   rrr  ",
			"   ...  ",
			"   .T.  ",
			"   ...  ",
		],
		"levels": [
			"111111  ",
			"111111  ",
			"111111  ",
			"   222  ",
			"   222  ",
			"   222  ",
			"        ",
			"        ",
			"   000  ",
			"   000  ",
			"   000  ",
		],
		"height": _h_colina,
		"obstacles": [
			{"type": "windmill", "x": 4.5, "z": 3.6, "depth": 1.0, "gap": 0.6,
				"x0": 3.0, "x1": 6.0, "speed": 1.0},
			{"type": "fence", "a": Vector2(3.0, 1.0), "b": Vector2(3.0, 3.0)},
			{"type": "seed", "x": 3.4, "z": 7.0},
			{"type": "seed", "x": 5.5, "z": 0.5},
			{"type": "seed", "x": 0.5, "z": 0.5},
		],
		"path": [Vector2(4.5, 4.8), Vector2(4.5, 0.6), Vector2(2.2, 0.6), Vector2(1.5, 2.5)],
	}


func _h_colina(x: float, z: float) -> float:
	# La meseta cae un poco hacia el molino (si las aspas devuelven la bola no
	# rueda hasta la salida) y el green del hoyo se inclina hacia la izquierda.
	var h := 0.0
	if z >= 3.0 and z <= 6.0:
		h += 0.09 * (z - 3.0) / 3.0
	elif z > 6.0 and z <= 8.0:
		h += 0.09 * (8.0 - z) / 2.0
	if z < 3.0:
		h += 0.025 * x
	h -= 0.04 * exp(-(pow(x - 1.5, 2.0) + pow(z - 2.5, 2.0)) / 0.6)
	return h


func arroyo() -> Dictionary:
	# El arroyo cruza la pista. Se sale justo delante de la cuña: con fuerza,
	# salta el agua de un golpe. Camino seguro: ir a la derecha y cruzar por
	# el puentecillo.
	return {
		"name": "HOLE_ARROYO",
		"par": 3,
		"map": [
			".......",
			"....H..",
			".......",
			"~~~~~..",
			"~~~~~..",
			".......",
			".......",
			".T.....",
			".......",
		],
		"height": _h_arroyo,
		"obstacles": [
			{"type": "kicker", "x": 1.5, "z": 5.5, "dir": Vector2(0, -1), "len": 0.9,
				"w": 1.2, "h": 0.3, "launch": 4.4, "up": 2.6},
			{"type": "stone", "x": 3.0, "z": 2.2, "r": 0.24},
			{"type": "seed", "x": 1.5, "z": 4.0, "y": 0.75},
			{"type": "seed", "x": 6.5, "z": 3.5},
			{"type": "seed", "x": 0.5, "z": 0.5},
		],
		"path": [Vector2(5.8, 5.0), Vector2(5.8, 1.6), Vector2(4.5, 1.5)],
	}


func _h_arroyo(x: float, z: float) -> float:
	# El green del otro lado cae hacia el agua: si te pasas, vuelve.
	var h := 0.0
	if z < 3.0:
		h += 0.05 * (3.0 - z) / 3.0
	h -= 0.04 * exp(-(pow(x - 4.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)
	return h


func pradera() -> Dictionary:
	# Una valla obliga a subir por la izquierda atravesando el viento; el hoyo
	# está en lo alto de un montículo: ni corto ni largo.
	return {
		"name": "HOLE_PRADERA",
		"par": 3,
		"map": [
			".....",
			".....",
			"..H..",
			".....",
			".....",
			".....",
			".....",
			".....",
			"...T.",
			".....",
		],
		"height": _h_pradera,
		"obstacles": [
			{"type": "fence", "a": Vector2(1.4, 6.2), "b": Vector2(5.0, 6.2)},
			{"type": "bumper", "x": 1.3, "z": 4.3, "r": 0.2},
			{"type": "bumper", "x": 3.9, "z": 4.6, "r": 0.2},
			{"type": "wind", "rect": Rect2(0, 3.3, 5, 3.0), "dir": Vector2(1, 0),
				"strength": 1.7, "period": 4.5},
			{"type": "seed", "x": 4.5, "z": 5.2},
			{"type": "seed", "x": 0.5, "z": 0.6},
			{"type": "seed", "x": 4.5, "z": 0.6},
		],
		"path": [Vector2(0.7, 7.2), Vector2(0.7, 5.4), Vector2(2.5, 2.5)],
	}


func _h_pradera(x: float, z: float) -> float:
	return 0.27 * exp(-(pow(x - 2.5, 2.0) + pow(z - 2.5, 2.0)) / 0.9)


func setas() -> Dictionary:
	# La valla solo tiene un hueco estrecho a la derecha. La seta saltarina,
	# a la izquierda, te pasa por encima pero lejos del hoyo, que está al otro
	# lado protegido por el brazo giratorio.
	return {
		"name": "HOLE_SETAS",
		"par": 3,
		"map": [
			".....",
			"...H.",
			".....",
			".....",
			".....",
			".....",
			".....",
			".....",
			".....",
			"..T..",
			".....",
		],
		"height": _h_setas,
		"obstacles": [
			{"type": "fence", "a": Vector2(0.0, 5), "b": Vector2(4.45, 5)},
			{"type": "pad", "x": 1.2, "z": 6.3, "up": 3.6},
			{"type": "sweeper", "x": 3.2, "z": 2.6, "len": 2.0, "speed": 1.2},
			{"type": "bumper", "x": 4.3, "z": 7.6, "r": 0.18},
			{"type": "seed", "x": 1.1, "z": 5.0, "y": 0.6},
			{"type": "seed", "x": 4.72, "z": 4.2},
			{"type": "seed", "x": 0.5, "z": 0.5},
		],
		"path": [Vector2(4.72, 6.0), Vector2(4.72, 4.0), Vector2(3.5, 1.5)],
	}


func _h_setas(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 3.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func terrazas() -> Dictionary:
	return {
		"name": "HOLE_TERRAZAS",
		"par": 4,
		"map": [
			"...T...",
			".......",
			".......",
			"....s..",
			".......",
			".....ss",
			".......",
			"...H...",
		],
		"levels": [
			"3333333",
			"3333333",
			"2222222",
			"2222222",
			"1111111",
			"1111111",
			"0000000",
			"0000000",
		],
		"height": _h_terrazas,
		"obstacles": [
			{"type": "fence", "a": Vector2(0, 2), "b": Vector2(2.0, 2)},
			{"type": "fence", "a": Vector2(2.7, 2), "b": Vector2(5.3, 2)},
			{"type": "fence", "a": Vector2(1.7, 4), "b": Vector2(7, 4)},
			{"type": "fence", "a": Vector2(0, 6), "b": Vector2(2.8, 6)},
			{"type": "fence", "a": Vector2(4.2, 6), "b": Vector2(7, 6)},
			{"type": "stone", "x": 3.5, "z": 5.25, "r": 0.24},
			{"type": "stone", "x": 5.2, "z": 2.9, "r": 0.22},
			{"type": "pipe", "a": Vector2(6.5, 0.5), "b": Vector2(6.4, 7.5), "out": Vector2(-1, 0)},
			{"type": "seed", "x": 0.5, "z": 1.5},
			{"type": "seed", "x": 6.5, "z": 3.5},
			{"type": "seed", "x": 0.5, "z": 6.6},
		],
		"path": [Vector2(2.35, 2.6), Vector2(0.85, 3.4), Vector2(0.85, 4.7), Vector2(2.5, 5.5),
			Vector2(3.5, 6.6), Vector2(3.5, 7.5)],
	}


func _h_terrazas(x: float, z: float) -> float:
	return -0.035 * exp(-(pow(x - 3.5, 2.0) + pow(z - 7.5, 2.0)) / 0.6)


func puente() -> Dictionary:
	# En S: sales por la izquierda, cruzas un puente estrecho sin barandillas
	# y el hoyo está en la esquina contraria, tras un brazo giratorio.
	return {
		"name": "HOLE_PUENTE",
		"par": 3,
		"map": [
			".......",
			".....H.",
			".......",
			"~~~.~~~",
			"~~~.~~~",
			"~~~.~~~",
			".......",
			".T.....",
			".......",
		],
		"height": _h_puente,
		"obstacles": [
			{"type": "sweeper", "x": 4.5, "z": 1.6, "len": 1.2, "speed": -1.3},
			{"type": "seed", "x": 3.5, "z": 4.5, "y": 0.35},
			{"type": "seed", "x": 0.5, "z": 0.5},
			{"type": "seed", "x": 6.5, "z": 7.5},
		],
		"path": [Vector2(3.5, 6.4), Vector2(3.5, 3.0), Vector2(5.5, 1.5)],
	}


func _h_puente(x: float, z: float) -> float:
	var h := 0.0
	if z > 3.0 and z < 6.0:
		h = 0.12 * sin(PI * (z - 3.0) / 3.0)
	h -= 0.04 * exp(-(pow(x - 5.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)
	return h


# --- Mundo 3: Islas entre las Nubes ("theme": 2) ---------------------------------------
# Islas flotantes: si la bola se sale por un borde sin valla, cae a las nubes.

func puentes() -> Dictionary:
	# Dos islas unidas por puentes estrechos sin barandilla. Atajo: saltar el
	# hueco del centro con el golpe saltarín y coger la semilla del aire.
	return {
		"name": "HOLE_PUENTES",
		"theme": 2,
		"par": 3,
		"map": [
			".......",
			"..H....",
			".......",
			"o     o",
			"o     o",
			"o     o",
			".......",
			"...T...",
			".......",
		],
		"height": _h_puentes,
		"obstacles": [
			{"type": "bumper", "x": 4.6, "z": 1.0, "r": 0.18},
			{"type": "seed", "x": 3.5, "z": 4.5, "y": 0.35},
			{"type": "seed", "x": 0.5, "z": 4.5},
			{"type": "seed", "x": 6.5, "z": 0.5},
		],
		"path": [Vector2(6.5, 6.2), Vector2(6.5, 2.6), Vector2(2.5, 1.5)],
	}


func _h_puentes(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 2.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func trampolin() -> Dictionary:
	# El trampolín de nube lanza la bola por encima del vacío hasta el green.
	# Si se falla, queda el camino largo por el puente de la izquierda.
	return {
		"name": "HOLE_TRAMPOLIN",
		"theme": 2,
		"par": 3,
		"map": [
			"........",
			"......H.",
			"........",
			"o       ",
			"o       ",
			"o   ... ",
			"o   ... ",
			"o   .T. ",
			"oooo... ",
		],
		"height": _h_trampolin,
		"obstacles": [
			{"type": "pad", "x": 5.5, "z": 5.4, "up": 3.6, "min_speed": 4.4},
			{"type": "bumper", "x": 3.5, "z": 1.2, "r": 0.2},
			{"type": "seed", "x": 0.5, "z": 5.5},
			{"type": "seed", "x": 5.5, "z": 3.6, "y": 0.6},
			{"type": "seed", "x": 0.5, "z": 0.5},
		],
		"path": [Vector2(5.5, 5.4), Vector2(6.5, 1.5)],
	}


func _h_trampolin(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 6.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func viento_alto() -> Dictionary:
	# Pasarela en zigzag sin barandillas y con rachas de viento que empujan
	# hacia el vacío. Hay que apuntar contra el viento.
	return {
		"name": "HOLE_VIENTO_ALTO",
		"theme": 2,
		"par": 3,
		"map": [
			" ..... ",
			" ..H.. ",
			" ..... ",
			"  oo   ",
			"  oo   ",
			"   oo  ",
			"   oo  ",
			" ..... ",
			" ..T.. ",
			" ..... ",
		],
		"height": _h_viento_alto,
		"obstacles": [
			{"type": "wind", "rect": Rect2(1, 3, 5, 2), "dir": Vector2(1, 0),
				"strength": 1.3, "period": 4.0},
			{"type": "wind", "rect": Rect2(1, 5, 5, 2), "dir": Vector2(-1, 0),
				"strength": 1.3, "period": 3.6},
			{"type": "seed", "x": 2.4, "z": 3.5},
			{"type": "seed", "x": 4.6, "z": 6.5},
			{"type": "seed", "x": 5.5, "z": 0.5},
		],
		"path": [Vector2(3.5, 6.0), Vector2(3.0, 3.2), Vector2(3.5, 1.5)],
	}


func _h_viento_alto(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 3.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func escalera() -> Dictionary:
	# Tres islas a distinta altura. Las flechas dan impulso para subir las
	# rampas; arriba, el hoyo está tras un brazo giratorio.
	return {
		"name": "HOLE_ESCALERA",
		"theme": 2,
		"par": 4,
		"map": [
			"......",
			"....H.",
			"......",
			"r     ",
			"r     ",
			"......",
			"......",
			"     r",
			"     r",
			"......",
			".T....",
			"......",
		],
		"levels": [
			"444444",
			"444444",
			"444444",
			"      ",
			"      ",
			"222222",
			"222222",
			"      ",
			"      ",
			"000000",
			"000000",
			"000000",
		],
		"height": _h_escalera,
		"obstacles": [
			{"type": "boost", "x": 5.5, "z": 9.5, "dir": Vector2(0, -1), "speed": 4.6},
			{"type": "boost", "x": 0.5, "z": 5.5, "dir": Vector2(0, -1), "speed": 4.6},
			{"type": "sweeper", "x": 3.0, "z": 6.0, "len": 1.1, "speed": 1.2},
			{"type": "stone", "x": 2.4, "z": 1.3, "r": 0.22},
			{"type": "seed", "x": 0.5, "z": 10.5},
			{"type": "seed", "x": 4.5, "z": 5.4},
			{"type": "seed", "x": 0.5, "z": 0.5},
		],
		"path": [Vector2(5.5, 9.7), Vector2(5.5, 6.4), Vector2(0.5, 5.8), Vector2(0.5, 2.4),
			Vector2(4.5, 1.5)],
	}


func _h_escalera(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 4.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func molino_cielo() -> Dictionary:
	# Molino sobre la isla grande y un puente de una casilla hasta la isla del
	# hoyo, donde una valla obliga a rodear. El portal de la esquina lleva a la
	# isla del hoyo por el otro lado.
	return {
		"name": "HOLE_MOLINO_CIELO",
		"theme": 2,
		"par": 3,
		"map": [
			"  .....",
			"  ...H.",
			"  .....",
			"   o   ",
			"   o   ",
			".......",
			".......",
			".......",
			"...T...",
			".......",
		],
		"height": _h_molino_cielo,
		"obstacles": [
			{"type": "windmill", "x": 3.5, "z": 5.6, "depth": 1.0, "gap": 0.6,
				"x0": 0.0, "x1": 7.0, "speed": 1.1},
			{"type": "fence", "a": Vector2(4.0, 2.4), "b": Vector2(7.0, 2.4)},
			{"type": "pipe", "style": "portal", "a": Vector2(0.5, 7.0), "b": Vector2(2.5, 2.6),
				"out": Vector2(1, -0.4)},
			{"type": "seed", "x": 0.5, "z": 8.5},
			{"type": "seed", "x": 6.5, "z": 6.5},
			{"type": "seed", "x": 2.5, "z": 0.5},
		],
		"path": [Vector2(3.5, 4.4), Vector2(3.4, 1.4), Vector2(5.5, 1.5)],
	}


func _h_molino_cielo(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 5.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func archipielago() -> Dictionary:
	# Muchas islas pequeñas. Por los puentes es largo (y el viento empuja en el
	# más largo); con un buen salto se cruza el vacío hacia el hoyo.
	return {
		"name": "HOLE_ARCHIPIELAGO",
		"theme": 2,
		"par": 4,
		"map": [
			"...    ...",
			".H.    ...",
			"...    ...",
			" o      o ",
			" o      o ",
			" oooo.....",
			" oooo.....",
			"    ......",
			"      o   ",
			"     ...  ",
			"     ..T  ",
			"     ...  ",
		],
		"height": _h_archipielago,
		"obstacles": [
			{"type": "bumper", "x": 7.6, "z": 6.4, "r": 0.2},
			{"type": "wind", "rect": Rect2(1, 4.6, 3.6, 2.4), "dir": Vector2(0, 1),
				"strength": 0.7, "period": 4.2},
			{"type": "pipe", "style": "portal", "a": Vector2(8.5, 1.0), "b": Vector2(1.5, 2.6),
				"out": Vector2(0, -1)},
			{"type": "seed", "x": 8.5, "z": 3.5},
			{"type": "seed", "x": 9.5, "z": 0.5},
			{"type": "seed", "x": 3.2, "z": 3.4, "y": 0.4},
		],
		"path": [Vector2(6.5, 8.5), Vector2(6.0, 6.2), Vector2(4.2, 5.8), Vector2(1.5, 5.6),
			Vector2(1.5, 3.0), Vector2(1.5, 1.5)],
	}


func _h_archipielago(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 1.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


# --- Mundo 4: Cumbre Nevada ("theme": 3) ------------------------------------------------
# El hielo apenas frena (el golpe con freno es tu amigo) y la nieve blanda
# frena mucho.

func lago_helado() -> Dictionary:
	# Un lago helado entre la salida y el hoyo, con piedras encima, y una
	# franja de nieve blanda justo delante del hoyo.
	return {
		"name": "HOLE_LAGO_HELADO",
		"theme": 3,
		"par": 3,
		"map": [
			".......",
			"...H...",
			".sssss.",
			"iiiiiii",
			"iiiiiii",
			"iiiiiii",
			"iiiiiii",
			".......",
			"...T...",
			".......",
		],
		"height": _h_lago_helado,
		"obstacles": [
			{"type": "stone", "x": 2.3, "z": 4.4, "r": 0.24},
			{"type": "stone", "x": 4.8, "z": 5.3, "r": 0.22},
			{"type": "stone", "x": 3.6, "z": 3.4, "r": 0.2},
			{"type": "seed", "x": 0.5, "z": 4.0},
			{"type": "seed", "x": 6.5, "z": 5.5},
			{"type": "seed", "x": 6.5, "z": 0.5},
		],
		"path": [Vector2(3.0, 6.2), Vector2(3.0, 2.6), Vector2(3.5, 1.5)],
	}


func _h_lago_helado(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 3.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func tobogan() -> Dictionary:
	# Tobogán de hielo en zigzag cuesta abajo: la bola no para hasta llegar al
	# llano del hoyo. Frena a tiempo o rebotará contra el fondo.
	return {
		"name": "HOLE_TOBOGAN",
		"theme": 3,
		"par": 3,
		"map": [
			"....  ",
			".T..  ",
			"....  ",
			"iii   ",
			" iii  ",
			"  iii ",
			"   iii",
			"  iii ",
			" iii  ",
			"......",
			"...H..",
			"......",
		],
		"height": _h_tobogan,
		"obstacles": [
			{"type": "bumper", "x": 1.4, "z": 10.6, "r": 0.18},
			{"type": "seed", "x": 0.5, "z": 3.5},
			{"type": "seed", "x": 5.5, "z": 6.5},
			{"type": "seed", "x": 5.5, "z": 10.5},
		],
		"path": [Vector2(1.5, 3.6), Vector2(2.8, 5.5), Vector2(4.4, 6.5), Vector2(2.6, 8.5),
			Vector2(3.5, 10.5)],
	}


func _h_tobogan(x: float, z: float) -> float:
	# Baja 0,05 por metro hasta el llano del hoyo.
	var h := -0.05 * clampf(z - 2.5, 0.0, 6.5)
	h -= 0.04 * exp(-(pow(x - 3.5, 2.0) + pow(z - 10.5, 2.0)) / 0.6)
	return h


func ventisca() -> Dictionary:
	# Agua helada a los dos lados y una ventisca que sopla sobre el hielo. Una
	# valla corta el paso por el centro: hay que ir por un lado, junto al agua
	# (contra el viento por la izquierda o a favor por la derecha).
	return {
		"name": "HOLE_VENTISCA",
		"theme": 3,
		"par": 3,
		"map": [
			"~.....~",
			"~...H.~",
			"~.....~",
			"~iiiii~",
			"~iiiii~",
			"~iiiii~",
			"~.....~",
			"~..T..~",
			"~.....~",
		],
		"height": _h_ventisca,
		"obstacles": [
			{"type": "wind", "rect": Rect2(1, 3, 5, 3), "dir": Vector2(1, 0),
				"strength": 1.5, "period": 4.0},
			{"type": "fence", "a": Vector2(2.3, 4.5), "b": Vector2(5.0, 4.5)},
			{"type": "stone", "x": 3.5, "z": 2.4, "r": 0.24},
			{"type": "bumper", "x": 2.3, "z": 3.4, "r": 0.18},
			{"type": "seed", "x": 1.5, "z": 5.4},
			{"type": "seed", "x": 5.5, "z": 3.4},
			{"type": "seed", "x": 5.5, "z": 0.5},
		],
		"path": [Vector2(1.8, 6.4), Vector2(1.8, 2.6), Vector2(4.5, 1.5)],
	}


func _h_ventisca(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 4.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func terrazas_hielo() -> Dictionary:
	# Terrazas de hielo en zigzag unidas por rampas; troncos nevados cierran
	# los atajos. En el hielo la bola corre hasta el fondo de cada terraza.
	return {
		"name": "HOLE_TERRAZAS_HIELO",
		"theme": 3,
		"par": 4,
		"map": [
			"...T...",
			".......",
			"rr.....",
			"..iii..",
			"..iiirr",
			".......",
			"rr.....",
			"..iii..",
			"...H...",
		],
		"levels": [
			"3333333",
			"3333333",
			"  22222",
			"2222222",
			"11111  ",
			"1111111",
			"  00000",
			"0000000",
			"0000000",
		],
		"height": _h_terrazas_hielo,
		"obstacles": [
			{"type": "fence", "style": "log", "a": Vector2(2, 2), "b": Vector2(7, 2)},
			{"type": "fence", "style": "log", "a": Vector2(0, 4), "b": Vector2(5, 4)},
			{"type": "fence", "style": "log", "a": Vector2(2, 6), "b": Vector2(7, 6)},
			{"type": "bumper", "x": 5.7, "z": 7.6, "r": 0.18},
			{"type": "seed", "x": 6.5, "z": 0.6},
			{"type": "seed", "x": 0.5, "z": 4.6},
			{"type": "seed", "x": 6.5, "z": 7.5},
		],
		"path": [Vector2(1.0, 1.5), Vector2(1.0, 3.3), Vector2(5.9, 3.5), Vector2(5.9, 5.3),
			Vector2(1.0, 5.5), Vector2(1.0, 7.3), Vector2(3.5, 8.5)],
	}


func _h_terrazas_hielo(x: float, z: float) -> float:
	return -0.035 * exp(-(pow(x - 3.5, 2.0) + pow(z - 8.5, 2.0)) / 0.6)


func glaciar() -> Dictionary:
	# Dos pasos sobre el agua helada: a la derecha, nieve blanda con pared
	# (seguro, pero hay que darle fuerte y luego girar); a la izquierda, hielo
	# sin barandillas que lleva directo al hoyo. Con el salto se puede cruzar
	# el agua en diagonal.
	return {
		"name": "HOLE_GLACIAR",
		"theme": 3,
		"par": 3,
		"map": [
			"......",
			".H....",
			"......",
			"jj~~ss",
			"jj~~ss",
			"jj~~ss",
			"......",
			"....T.",
			"......",
		],
		"height": _h_glaciar,
		"obstacles": [
			{"type": "bumper", "x": 3.5, "z": 1.2, "r": 0.2},
			{"type": "seed", "x": 0.5, "z": 4.5},
			{"type": "seed", "x": 5.5, "z": 4.0},
			{"type": "seed", "x": 5.5, "z": 0.5},
		],
		"path": [Vector2(4.8, 6.2), Vector2(4.8, 2.6), Vector2(1.5, 1.5)],
	}


func _h_glaciar(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 1.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)


func cumbre() -> Dictionary:
	# El gran final: hielo con un brazo giratorio, flechas para subir la rampa
	# a la cima y un molino que guarda el hoyo.
	return {
		"name": "HOLE_CUMBRE",
		"theme": 3,
		"par": 4,
		"map": [
			"........",
			".H......",
			"........",
			"  rrr   ",
			"  rrr   ",
			"iiiiiiii",
			"iiiiiiii",
			"........",
			"......T.",
			"........",
		],
		"levels": [
			"44444444",
			"44444444",
			"44444444",
			"        ",
			"        ",
			"00000000",
			"00000000",
			"00000000",
			"00000000",
			"00000000",
		],
		"height": _h_cumbre,
		"obstacles": [
			{"type": "boost", "x": 3.5, "z": 5.6, "dir": Vector2(0, -1), "speed": 5.2},
			{"type": "sweeper", "x": 1.4, "z": 6.0, "len": 1.2, "speed": 1.3},
			{"type": "windmill", "x": 3.5, "z": 2.3, "depth": 0.7, "gap": 0.6,
				"x0": 0.0, "x1": 8.0, "speed": 0.9},
			{"type": "seed", "x": 7.5, "z": 5.5},
			{"type": "seed", "x": 0.5, "z": 7.5},
			{"type": "seed", "x": 7.5, "z": 0.5},
		],
		"path": [Vector2(3.5, 6.2), Vector2(3.5, 3.4), Vector2(3.5, 1.2), Vector2(1.5, 1.5)],
	}


func _h_cumbre(x: float, z: float) -> float:
	return -0.04 * exp(-(pow(x - 1.5, 2.0) + pow(z - 1.5, 2.0)) / 0.6)
