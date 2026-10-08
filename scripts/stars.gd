extends Control
## Tres estrellas que aparecen una a una (las conseguidas, doradas).

var _count := 0
var _shown := 0.0


func show_count(count: int) -> void:
	_count = count
	_shown = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_shown", 3.0, 0.9)
	for i in count:
		tw.parallel().tween_callback(Sfx.play.bind("coin", -4.0, 1.0 + i * 0.15)).set_delay(0.3 * i)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	for i in 3:
		var k := clampf(_shown - i, 0.0, 1.0)
		if k <= 0.0:
			continue
		var c := Vector2(size.x * (0.2 + 0.3 * i), size.y * 0.5)
		var r := 34.0 * (0.6 + 0.4 * k)
		var got := i < _count
		var pts := _star(c, r, r * 0.45)
		draw_colored_polygon(pts, Color(1, 0.82, 0.25) if got else Color(0.2, 0.2, 0.2, 0.55))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 0.97, 0.88), 3.0)


func _star(c: Vector2, ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var r := ro if k % 2 == 0 else ri
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
