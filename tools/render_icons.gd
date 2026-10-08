extends SceneTree
## Herramienta: convierte los SVG de icons/ en los PNG de Android e iOS.
## Uso: godot --headless --path . -s res://tools/render_icons.gd


func _initialize() -> void:
	_raster("res://icons/full.svg", "res://icons/icon_192.png", 192)
	_raster("res://icons/full.svg", "res://icons/preview_512.png", 512)
	_raster("res://icons/foreground.svg", "res://icons/adaptive_fg_432.png", 432)
	_raster("res://icons/background.svg", "res://icons/adaptive_bg_432.png", 432)
	# App Store: 1024 px y sin canal alfa (Apple rechaza iconos con transparencia).
	_raster("res://icons/full.svg", "res://icons/icon_1024.png", 1024, true)
	quit()


func _raster(src: String, dst: String, px: int, opaque: bool = false) -> void:
	var text := FileAccess.get_file_as_string(src)
	var img := Image.new()
	img.load_svg_from_string(text, px / 432.0)
	if opaque:
		img.convert(Image.FORMAT_RGB8)
	print(dst, " ", img.get_size(), " ", img.save_png(dst))
