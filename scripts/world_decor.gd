extends Node3D
## Paisaje común a todos los hoyos de un mundo. Tema 0 (Colinas de la Brisa):
## cielo de verano, prado, colinas lejanas y nubes de algodón. Tema 1 (Bosque
## de los Espíritus): atardecer dorado, bruma y un anillo de árboles gigantes.
## Tema 2 (Islas entre las Nubes): sin suelo, un mar de nubes muy abajo. Tema 3
## (Cumbre Nevada): nieve, montañas blancas alrededor y cielo frío.

const Looks = preload("res://scripts/looks.gd")
const GROUND_Y := -0.45

var theme := -1
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _ground_mat: ShaderMaterial
var _hills_node: Node3D
var _forest_node: Node3D
var _clouds_node: Node3D
var _clouds: Array[Node3D] = []
var _ground_node: MeshInstance3D
var _sea_node: Node3D
var _peaks_node: Node3D


func _ready() -> void:
	_environment()
	_ground()
	_hills_node = Node3D.new()
	add_child(_hills_node)
	_hills()
	_clouds_node = Node3D.new()
	add_child(_clouds_node)
	_make_clouds()
	_forest_node = Node3D.new()
	add_child(_forest_node)
	_giant_forest()
	_sea_node = Node3D.new()
	add_child(_sea_node)
	_cloud_sea()
	_peaks_node = Node3D.new()
	add_child(_peaks_node)
	_peaks()
	set_theme(0)


func set_theme(t: int) -> void:
	if t == theme:
		return
	theme = t
	var forest := t == 1
	_hills_node.visible = t == 0
	_forest_node.visible = forest
	_clouds_node.visible = not forest
	_ground_node.visible = t != 2
	_sea_node.visible = t == 2
	_peaks_node.visible = t == 3
	if t == 2:
		_sky.sky_top_color = Color(0.3, 0.55, 0.95)
		_sky.sky_horizon_color = Color(0.78, 0.86, 0.98)
		_sky.ground_horizon_color = Color(0.78, 0.86, 0.98)
		_sky.ground_bottom_color = Color(0.62, 0.74, 0.95)
		_env.ambient_light_energy = 0.6
		_env.fog_light_color = Color(0.7, 0.8, 0.97)
		_env.fog_density = 0.004
		_env.glow_intensity = 0.4
		_sun.rotation_degrees = Vector3(-40, -20, 0)
		_sun.light_color = Color(1.0, 0.95, 0.88)
		_sun.light_energy = 1.2
	elif t == 3:
		_sky.sky_top_color = Color(0.3, 0.5, 0.82)
		_sky.sky_horizon_color = Color(0.86, 0.91, 0.98)
		_sky.ground_horizon_color = Color(0.86, 0.91, 0.98)
		_sky.ground_bottom_color = Color(0.9, 0.93, 0.98)
		_env.ambient_light_energy = 0.7
		_env.fog_light_color = Color(0.86, 0.9, 0.98)
		_env.fog_density = 0.01
		_env.glow_intensity = 0.4
		_sun.rotation_degrees = Vector3(-35, -50, 0)
		_sun.light_color = Color(1.0, 0.96, 0.92)
		_sun.light_energy = 1.1
		_ground_mat.set_shader_parameter("albedo", Color(0.93, 0.95, 1.0))
	elif forest:
		_sky.sky_top_color = Color(0.26, 0.34, 0.58)
		_sky.sky_horizon_color = Color(0.98, 0.74, 0.5)
		_sky.ground_horizon_color = Color(0.98, 0.74, 0.5)
		_sky.ground_bottom_color = Color(0.18, 0.28, 0.18)
		_env.ambient_light_energy = 0.58
		_env.fog_light_color = Color(0.68, 0.7, 0.58)
		_env.fog_density = 0.011
		_env.glow_intensity = 0.6
		_sun.rotation_degrees = Vector3(-22, -60, 0)
		_sun.light_color = Color(1.0, 0.8, 0.58)
		_sun.light_energy = 1.05
		_ground_mat.set_shader_parameter("albedo", Color(0.26, 0.42, 0.22))
	else:
		_sky.sky_top_color = Color(0.2, 0.47, 0.86)
		_sky.sky_horizon_color = Color(0.72, 0.86, 0.96)
		_sky.ground_horizon_color = Color(0.72, 0.86, 0.96)
		_sky.ground_bottom_color = Color(0.35, 0.55, 0.3)
		_env.ambient_light_energy = 0.6
		_env.fog_light_color = Color(0.74, 0.86, 0.96)
		_env.fog_density = 0.006
		_env.glow_intensity = 0.35
		_sun.rotation_degrees = Vector3(-48, -35, 0)
		_sun.light_color = Color(1.0, 0.95, 0.84)
		_sun.light_energy = 1.15
		_ground_mat.set_shader_parameter("albedo", Color(0.42, 0.66, 0.28))


func _environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_curve = 0.12
	_sky.sun_angle_max = 20.0
	sky.sky_material = _sky
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.95
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.0
	_env.glow_enabled = true
	_env.glow_bloom = 0.04
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)


func _ground() -> void:
	var ground := MeshInstance3D.new()
	_ground_node = ground
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	_ground_mat = Looks.toon(Color(0.42, 0.66, 0.28), 0.35)
	ground.material_override = _ground_mat
	ground.position = Vector3(5, GROUND_Y, 5)
	add_child(ground)


func _hills() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 8
	var mats := [Looks.toon(Color(0.36, 0.6, 0.3), 0.2), Looks.toon(Color(0.3, 0.55, 0.32), 0.2),
		Looks.toon(Color(0.42, 0.64, 0.3), 0.2)]
	for i in 14:
		var a := i * TAU / 14.0 + rng.randf_range(-0.15, 0.15)
		var d := rng.randf_range(80.0, 130.0)
		var hill := MeshInstance3D.new()
		hill.mesh = sm
		hill.material_override = mats[i % mats.size()]
		var rad := rng.randf_range(30.0, 55.0)
		hill.scale = Vector3(rad, rng.randf_range(8.0, 20.0), rad * rng.randf_range(0.7, 1.2))
		hill.position = Vector3(5 + cos(a) * d, GROUND_Y - 2.0, 5 + sin(a) * d)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hills_node.add_child(hill)


## Anillo de árboles enormes alrededor del claro (fondo del bosque).
func _giant_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.6
	trunk.bottom_radius = 1.0
	trunk.height = 18.0
	trunk.radial_segments = 8
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 10
	blob.rings = 5
	var trunk_mat := Looks.toon(Color(0.3, 0.22, 0.15), 0.3)
	var leaf_mats := [Looks.toon(Color(0.14, 0.3, 0.18), 0.2), Looks.toon(Color(0.18, 0.36, 0.2), 0.2)]
	for i in 34:
		var a := i * TAU / 34.0 + rng.randf_range(-0.08, 0.08)
		var d := rng.randf_range(20.0, 42.0)
		var tree := Node3D.new()
		tree.position = Vector3(5 + cos(a) * d, GROUND_Y, 5 + sin(a) * d)
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
		var t := MeshInstance3D.new()
		t.mesh = trunk
		t.material_override = trunk_mat
		t.position.y = 9.0
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tree.add_child(t)
		for k in 3:
			var b := MeshInstance3D.new()
			b.mesh = blob
			b.material_override = leaf_mats[(i + k) % 2]
			b.position = Vector3(rng.randf_range(-2.0, 2.0), 16.0 + k * 2.5, rng.randf_range(-2.0, 2.0))
			b.scale = Vector3.ONE * rng.randf_range(4.0, 6.0)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tree.add_child(b)
		_forest_node.add_child(tree)


## Mar de nubes muy por debajo de las islas.
func _cloud_sea() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	var mat := Looks.cloud()
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	base.mesh = plane
	base.material_override = Looks.toon(Color(0.64, 0.76, 0.97))
	base.position = Vector3(5, -12.0, 5)
	_sea_node.add_child(base)
	for i in 45:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 90.0
		var p := MeshInstance3D.new()
		p.mesh = puff
		p.material_override = mat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := rng.randf_range(5.0, 11.0)
		p.scale = Vector3(r * 1.4, r * 0.45, r)
		p.position = Vector3(5 + cos(a) * d, rng.randf_range(-13.0, -10.0), 5 + sin(a) * d)
		_sea_node.add_child(p)


## Montañas nevadas alrededor.
func _peaks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 9
	var rock := Looks.toon(Color(0.5, 0.55, 0.66), 0.25)
	var snow := Looks.toon(Color(0.97, 0.98, 1.0), 0.1)
	snow.set_shader_parameter("shadow_tint", Color(0.7, 0.78, 1.0))
	for i in 16:
		var a := i * TAU / 16.0 + rng.randf_range(-0.12, 0.12)
		var d := rng.randf_range(70.0, 120.0)
		var w := rng.randf_range(22.0, 38.0)
		var hgt := rng.randf_range(26.0, 48.0)
		var peak := Node3D.new()
		peak.position = Vector3(5 + cos(a) * d, GROUND_Y - 1.0, 5 + sin(a) * d)
		peak.rotation.y = rng.randf() * TAU
		_peaks_node.add_child(peak)
		var body := MeshInstance3D.new()
		body.mesh = cone
		body.material_override = rock
		body.scale = Vector3(w, hgt, w)
		body.position.y = hgt * 0.5
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		peak.add_child(body)
		var cap := MeshInstance3D.new()
		cap.mesh = cone
		cap.material_override = snow
		cap.scale = Vector3(w * 0.46, hgt * 0.46, w * 0.46)
		cap.position.y = hgt - hgt * 0.23 + 0.3
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		peak.add_child(cap)


func _make_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	var mat := Looks.cloud()
	for i in 12:
		var cloud := Node3D.new()
		var a := rng.randf() * TAU
		var d := rng.randf_range(55.0, 110.0)
		cloud.position = Vector3(5 + cos(a) * d, rng.randf_range(22.0, 40.0), 5 + sin(a) * d)
		var s := rng.randf_range(4.0, 8.0)
		for k in rng.randi_range(5, 8):
			var p := MeshInstance3D.new()
			p.mesh = puff
			p.material_override = mat
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var r := s * rng.randf_range(0.5, 1.0)
			p.scale = Vector3(r, r * 0.8, r)
			p.position = Vector3(rng.randf_range(-1.6, 1.6) * s, rng.randf_range(0.0, 0.5) * s,
				rng.randf_range(-0.6, 0.6) * s)
			cloud.add_child(p)
		_clouds_node.add_child(cloud)
		_clouds.append(cloud)


func _process(delta: float) -> void:
	if not _clouds_node.visible:
		return
	for c in _clouds:
		c.position.x += delta * 0.6
		if c.position.x > 140.0:
			c.position.x -= 270.0
