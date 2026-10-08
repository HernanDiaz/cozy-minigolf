extends MultiMeshInstance3D
## Rejilla de pendientes al estilo del green de Neo Turf Masters: flechas que
## se deslizan cuesta abajo, más rápidas y rojas cuanto más inclinado está.

var builder
var _points: Array = []
var _t := 0.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


func setup(b) -> void:
	builder = b
	_points.clear()
	for r in b.rows:
		for c in b.cols:
			if not b.is_floor_char(b.tile(c, r)):
				continue
			for i in 2:
				for j in 2:
					var x: float = c + 0.25 + i * 0.5
					var z: float = r + 0.25 + j * 0.5
					var e := 0.05
					var g := Vector2((b.h(x + e, z) - b.h(x - e, z)) / (2.0 * e),
						(b.h(x, z + e) - b.h(x, z - e)) / (2.0 * e))
					var s := g.length()
					_points.append([x, z, -g / s if s > 0.00001 else Vector2.ZERO, s])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _arrow_mesh()
	mm.instance_count = _points.size()
	for i in _points.size():
		var s: float = _points[i][3]
		var col := Color(1, 1, 1, 0.35)
		if s > 0.01:
			col = Color(1.0, 0.95, 0.3).lerp(Color(1.0, 0.2, 0.15), clampf(s / 0.15, 0.0, 1.0))
			col.a = 0.85
		mm.set_instance_color(i, col)
	multimesh = mm
	_update()


func _process(delta: float) -> void:
	if not visible or builder == null:
		return
	_t += delta
	_update()


func _update() -> void:
	if multimesh == null:
		return
	for i in _points.size():
		var p: Array = _points[i]
		var x: float = p[0]
		var z: float = p[1]
		var dir: Vector2 = p[2]
		var s: float = p[3]
		var basis := Basis().scaled(Vector3.ONE * 0.35)
		if s > 0.01:
			var off := fposmod(_t * (0.2 + s * 4.0), 0.5) - 0.25
			x += dir.x * off
			z += dir.y * off
			var sc := 0.8 + minf(s * 4.0, 0.8)
			basis = Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP).scaled(Vector3.ONE * sc)
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, builder.h(x, z) + 0.015, z)))


func _arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3(0, 0, -0.09))
	st.add_vertex(Vector3(0.05, 0, 0.05))
	st.add_vertex(Vector3(-0.05, 0, 0.05))
	return st.commit()
