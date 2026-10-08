extends Control
## Barra de fuerza vertical al estilo Neo Turf Masters: sube y baja sola; un
## toque fija la fuerza (línea roja) y la marca sigue moviéndose: el tercer
## toque, cuanto más cerca de la línea roja, más recto sale el tiro.
## Por encima del 100 % está la zona roja (más fuerza, pero la bola se desvía).
## La línea amarilla es la guía de fuerza cerca del hoyo, como en los putts
## del original.

const VMAX := 1.1

var value := 0.0
var guide := -1.0
var locked := -1.0
var zone := 0.0
var perfect := 0.0


func _y(v: float) -> float:
	return size.y * (1.0 - v / VMAX)


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(Vector2(-6, -6), size + Vector2(12, 12)), Color(0, 0, 0, 0.45))
	# Zona roja por encima del 100 %.
	draw_rect(Rect2(0, 0, w, _y(1.0)), Color(0.9, 0.15, 0.1, 0.35))
	var bands := 24
	var fill := clampf(locked if locked >= 0.0 else value, 0.0, VMAX)
	for i in bands:
		var a := float(i) / bands * VMAX
		if a >= fill:
			break
		var top := minf(float(i + 1) / bands * VMAX, fill)
		var col := _band_color(a)
		if locked >= 0.0:
			col = col.darkened(0.4)
		draw_rect(Rect2(3, _y(top), w - 6, _y(a) - _y(top)), col)
	for k in range(1, 4):
		var yy := _y(k * 0.25)
		draw_line(Vector2(0, yy), Vector2(w * 0.3, yy), Color(1, 1, 1, 0.7), 2.0)
	draw_line(Vector2(-4, _y(1.0)), Vector2(w + 4, _y(1.0)), Color(1, 1, 1, 0.95), 3.0)
	if guide >= 0.0:
		var yg := _y(guide)
		draw_line(Vector2(-12, yg), Vector2(w + 12, yg), Color(1, 0.9, 0.2), 4.0)
	if locked >= 0.0:
		var y0 := _y(minf(locked + zone, VMAX))
		draw_rect(Rect2(-8, y0, w + 16, _y(maxf(locked - zone, 0.0)) - y0), Color(0.2, 0.8, 1.0, 0.5))
		var y1 := _y(minf(locked + perfect, VMAX))
		draw_rect(Rect2(-8, y1, w + 16, _y(maxf(locked - perfect, 0.0)) - y1), Color(1, 1, 1, 0.55))
		var yl := _y(locked)
		draw_line(Vector2(-12, yl), Vector2(w + 12, yl), Color(1, 0.2, 0.15), 4.0)
	if value > 0.0 or locked >= 0.0:
		var ym := _y(clampf(value, 0.0, VMAX))
		draw_colored_polygon(PackedVector2Array([Vector2(-20, ym - 11), Vector2(-3, ym),
			Vector2(-20, ym + 11)]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.9), false, 2.0)


func _band_color(t: float) -> Color:
	if t > 1.0:
		return Color(1.0, 0.2, 0.15)
	if t < 0.5:
		return Color(0.2, 0.85, 0.3).lerp(Color(1.0, 0.9, 0.2), t * 2.0)
	return Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.45, 0.15), (t - 0.5) * 2.0)
