extends Node3D
## Cidade original construída com geometria nativa. Sem assets ou serviços remotos.
const Art = preload("res://scripts/art_geometry.gd")

var spawn_point: Vector3 = Vector3(0.0, 0.0, 16.0)
var tower_point: Vector3 = Vector3(0.0, 0.0, -24.0)
var evidence_points: Array = [
	{"id": "arquivo", "title": "ARQUIVO MUNICIPAL", "position": Vector3(-14.0, 0.0, 2.0), "description": "Um registro assinado liga o decreto ao fechamento da assembleia."},
	{"id": "gravacao", "title": "ESTAÇÃO DE RÁDIO", "position": Vector3(13.0, 0.0, -8.0), "description": "A gravação de uma testemunha confirma a operação desta noite."},
	{"id": "lista", "title": "A ÚLTIMA REDAÇÃO", "position": Vector3(-9.0, 0.0, -18.0), "description": "Uma lista de ordens e horários completa o dossiê."},
]
var npc_spots: Array[Dictionary] = [
	{"id": "lia", "name": "Lia", "position": Vector3(4, 0, 14)},
	{"id": "ines", "name": "Inês", "position": Vector3(-12, 0, 4)},
	{"id": "tomas", "name": "Tomás", "position": Vector3(10, 0, -7)},
]
var guard_routes: Array[Dictionary] = [
	{"id": "g1", "points": [Vector3(2, 0, 9), Vector3(4, 0, 4), Vector3(-2, 0, 3)]},
	{"id": "g2", "points": [Vector3(11, 0, -5), Vector3(12, 0, -10), Vector3(9, 0, -13)]},
	{"id": "g3", "points": [Vector3(-8, 0, -14), Vector3(-6, 0, -19), Vector3(-10, 0, -22)]},
]
var patrols: Array[Node3D] = []
var building_meshes: Array[MeshInstance3D] = []
var _built: bool = false
var _clock: float = 0.0
var _beacons: Dictionary = {}
var _beacon_stems: Dictionary = {}
var _tower_beacon: Node3D
var _tower_lamp: MeshInstance3D
var _tower_active: bool = false
var _materials: Dictionary = {}
var _window_transforms: Array[Transform3D] = []
var _frame_transforms: Array[Transform3D] = []
var _patrol_origins: Array[Vector3] = []
var _leaf_transforms: Array[Transform3D] = []
var _leaf_colors: Array[Color] = []
var _main_light: DirectionalLight3D


func _ready() -> void:
	build_world()


func _material(key: String, color: Color, emissive: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var kind: String = "plain"
	if key.begins_with("building_") or key in ["foundation", "trim"]:
		kind = "plaster"
	elif key in ["road", "asphalt_patch"]:
		kind = "asphalt"
	elif key in ["sidewalk", "paving_joints"]:
		kind = "paving"
	elif key in ["ground", "curb", "planter", "tower_stone", "garden_soil", "roof"]:
		kind = "stone"
	elif key in ["bench", "crate_wood", "evidence_table"]:
		kind = "wood"
	elif key == "tree_trunk":
		kind = "bark"
	elif key in ["tree_crown", "leaf"]:
		kind = "leaf"
	elif key.contains("metal") or key.contains("pipe") or key.contains("copper") or key == "garden_fence":
		kind = "metal"
	var material: StandardMaterial3D = Art.surface(color, kind)
	if kind == "asphalt":
		material.uv1_scale = Vector3(28, 76, 1)
	elif key == "sidewalk":
		material.uv1_scale = Vector3(8, 32, 1)
	elif kind == "plaster":
		material.uv1_scale = Vector3(5, 4, 1)
	elif kind == "wood":
		material.uv1_scale = Vector3(3, 1, 1)
	elif key == "ground":
		material.uv1_scale = Vector3(40, 40, 1)
	if emissive > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emissive
	_materials[key] = material
	return material


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh: Mesh
	var smallest: float = minf(dimensions.x, minf(dimensions.y, dimensions.z))
	var largest: float = maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	if smallest >= 0.075 and largest < 45.0:
		mesh = Art.rounded_box(dimensions, clampf(smallest * 0.16, 0.012, 0.16))
	else:
		var flat: BoxMesh = BoxMesh.new()
		flat.size = dimensions
		mesh = flat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = at
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = dimensions
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)
	return instance


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _label(parent: Node3D, at: Vector3, text: String, font_size: int = 36, color: Color = Color("f9e4b5")) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color("172a36")
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	return label


func build_world() -> void:
	if _built:
		return
	_built = true
	_lighting()
	var ground := _material("ground", Color("687154"))
	var road := _material("road", Color("555c55"))
	var sidewalk := _material("sidewalk", Color("9c9b88"))
	var curb := _material("curb", Color("b0ad96"))
	var paint := _material("paint", Color("dbd4b5"))
	_box(self, Vector3(0, -0.3, 0), Vector3(80, 0.6, 80), ground, true)
	_box(self, Vector3(0, 0.014, -3), Vector3(9, 0.028, 65), road)
	_box(self, Vector3(0, 0.02, 2), Vector3(64, 0.035, 7), road)
	_box(self, Vector3(0, 0.02, -12), Vector3(64, 0.035, 6), road)
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 6.8, 0.04, -3), Vector3(4.5, 0.08, 66), sidewalk)
		_box(self, Vector3(side * 4.6, 0.08, -3), Vector3(0.14, 0.16, 66), curb)
	for z in range(-28, 27, 6):
		_box(self, Vector3(0, 0.045, float(z)), Vector3(0.1, 0.02, 2.0), paint)
	for x in range(-3, 4):
		_box(self, Vector3(float(x), 0.048, 10.0), Vector3(0.5, 0.02, 2.6), paint)
		_box(self, Vector3(float(x), 0.048, -15.5), Vector3(0.5, 0.02, 2.0), paint)
	# Os grandes quarteirões ficam fora dos corredores de navegação e dos objetivos.
	_building(Vector3(-21, 0, 1), Vector3(10, 7.3, 11), Color("899080"), "ARQUIVO MUNICIPAL", true)
	_building(Vector3(22, 0, -9), Vector3(11, 8.5, 13), Color("788879"), "RÁDIO AURORA · 104.3", false)
	_building(Vector3(-18, 0, -20), Vector3(10, 6.5, 10), Color("a49177"), "JORNAL FAROL", true)
	_building(Vector3(-23, 0, 20), Vector3(12, 8.5, 12), Color("74806d"), "", true)
	_building(Vector3(23, 0, 20), Vector3(14, 10, 12), Color("918876"), "", false)
	_building(Vector3(24, 0, -26), Vector3(13, 10.5, 12), Color("798274"), "", false)
	_building(Vector3(-29, 0, -28), Vector3(10, 15, 11), Color("6d786b"), "", true)
	_building(Vector3(27, 0, 5), Vector3(10, 6.5, 8), Color("96917f"), "", false)
	# Skyline distante: visível, mas fora da área física de jogo.
	for index in range(11):
		var x := -42.0 + float(index) * 8.0
		var height := 11.0 + float((index * 7) % 13)
		_box(self, Vector3(x, height / 2.0, -43), Vector3(6, height, 7), _material("skyline", Color("566454")))
	_window_batch()
	_tower()
	for z in [15.0, 5.0, -6.0, -18.0, -28.0]:
		_lamp(Vector3(-6, 0, z))
		_lamp(Vector3(6, 0, z))
	for at in [Vector3(-11, 0, 11), Vector3(11, 0, 16), Vector3(-11, 0, -9), Vector3(10, 0, -23), Vector3(-6, 0, -29), Vector3(8, 0, 7)]:
		_tree(at)
	_bench(Vector3(-9, 0, 7), 0.0)
	_bench(Vector3(9, 0, -17), PI)
	_bench(Vector3(-4.5, 0, -22), PI / 2.0)
	_barricade(Vector3(14, 0, 12), -0.2)
	_barricade(Vector3(-14, 0, -10), 0.15)
	_street_details()
	_gardens()
	_public_props()
	_foliage_batch()
	_label(self, Vector3(0, 4.5, 18), "PRAÇA DA AURORA", 42)
	for data: Dictionary in evidence_points:
		_evidence(data)
	_patrol(Vector3(9.0, 1.5, 0), 0)
	_patrol(Vector3(-7.5, 1.5, -15.0), 1)
	# Barreiras de limite invisíveis permitem trajetos claros sem cair do cenário.
	var wall_mat := _material("boundary", Color("273e4a"))
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 39.5, 0.6, 0), Vector3(1, 1.2, 80), wall_mat, true)
		_box(self, Vector3(0, 0.6, side * 39.5), Vector3(80, 1.2, 1), wall_mat, true)


func _lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("384b54")
	sky_material.sky_horizon_color = Color("879582")
	sky_material.ground_bottom_color = Color("4a5545")
	sky_material.ground_horizon_color = Color("879582")
	sky_material.sun_angle_max = 1.5
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7c7cc")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("8b9a93")
	environment.fog_light_energy = 0.4
	environment.fog_density = 0.004
	environment_node.environment = environment
	add_child(environment_node)
	var moon := DirectionalLight3D.new()
	moon.name = "LuzDaCidade"
	moon.rotation_degrees = Vector3(-48, -30, 0)
	moon.light_color = Color("fff1dc")
	moon.light_energy = 0.68
	moon.shadow_enabled = true
	# Evita auto-sombreamento em faixas nas superfícies planas do GLES3.
	moon.shadow_bias = 0.12
	moon.shadow_normal_bias = 1.2
	moon.directional_shadow_max_distance = 38.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)
	_main_light = moon


func set_graphics_quality(smooth: bool) -> void:
	if is_instance_valid(_main_light):
		_main_light.shadow_enabled = smooth


func _building(at: Vector3, dimensions: Vector3, color: Color, sign: String, faces_east: bool) -> void:
	var mat_key := "building_%s" % color.to_html()
	building_meshes.append(_box(self, at + Vector3(0, dimensions.y / 2.0, 0), dimensions, _material(mat_key, color), true))
	building_meshes.append(_box(self, at + Vector3(0, dimensions.y + 0.15, 0), Vector3(dimensions.x + 0.45, 0.3, dimensions.z + 0.45), _material("roof", Color("535a49"))))
	# Frisos e base de alvenaria dão escala humana às fachadas.
	_box(self, at + Vector3(0, 0.32, 0), Vector3(dimensions.x + 0.12, 0.64, dimensions.z + 0.12), _material("foundation", Color("6f7565")))
	_box(self, at + Vector3(0, 3.0, 0), Vector3(dimensions.x + 0.15, 0.12, dimensions.z + 0.15), _material("trim", Color("b1ad92")))
	for corner_x in [-1.0, 1.0]:
		for corner_z in [-1.0, 1.0]:
			_box(self, at + Vector3(corner_x * dimensions.x * 0.5, dimensions.y * 0.5, corner_z * dimensions.z * 0.5), Vector3(0.16, dimensions.y, 0.16), _material("trim", Color("b1ad92")))
	# Caixa d'água e dutos, em vez de uma laje totalmente vazia.
	_cylinder(self, at + Vector3(-dimensions.x * 0.22, dimensions.y + 0.65, 0), 0.70, 1.0, _material("roof_utility", Color("7b8070")), 0.64)
	_cylinder(self, at + Vector3(-dimensions.x * 0.22, dimensions.y + 1.18, 0), 0.73, 0.10, _material("tank_lid", Color("59675e")))
	_cylinder(self, at + Vector3(dimensions.x * 0.22, dimensions.y + 0.65, -dimensions.z * 0.24), 0.28, 1.0, _material("pipe", Color("606956")))
	var facade_x := at.x + (dimensions.x / 2.0 + 0.05) * (1 if faces_east else -1)
	var facade_normal := Vector3.RIGHT if faces_east else Vector3.LEFT
	for floor_index in range(1, int(dimensions.y / 2.5)):
		for column in range(4):
			if (floor_index + column) % 5 == 0:
				continue
			var z := at.z - dimensions.z * 0.35 + float(column) * dimensions.z * 0.23
			_add_window(Vector3(facade_x, float(floor_index) * 2.5, z), Vector3(0.06, 1.1, 1.1), facade_normal)
	# Mais janelas na face que aponta para a praça e a câmera inicial.
	for floor_index in range(1, int(dimensions.y / 2.5)):
		for column in range(3):
			var x := at.x - dimensions.x * 0.28 + float(column) * dimensions.x * 0.28
			_add_window(Vector3(x, float(floor_index) * 2.5, at.z + dimensions.z / 2.0 + 0.05), Vector3(1.0, 1.1, 0.06), Vector3.BACK)
	if not sign.is_empty():
		var sign_at := Vector3(facade_x + (0.1 if faces_east else -0.1), 3.0, at.z)
		_label(self, sign_at, sign, 27)
		_box(self, Vector3(facade_x, 1.2, at.z), Vector3(0.12, 2.4, 1.5), _material("door", Color("394c42")))
		_box(self, Vector3(facade_x, 1.8, at.z), Vector3(0.15, 0.8, 1.1), _material("door_glass", Color("849188")))
		var awning := _box(self, Vector3(facade_x, 2.8, at.z) + facade_normal * 0.65, Vector3(1.5, 0.13, 2.4), _material("awning", Color("566d57")))
		awning.rotation.z = -0.12 if faces_east else 0.12
		for z_offset in [-1.12, 1.12]:
			_box(self, Vector3(facade_x, 2.65, at.z + z_offset) + facade_normal * 0.65, Vector3(1.5, 0.24, 0.08), _material("awning_trim", Color("d1c49b")))
		# Avisos nos prédios fazem parte da cidade ficcional, não de uma textura remota.
		_box(self, Vector3(facade_x, 1.55, at.z + 2.0) + facade_normal * 0.04, Vector3(0.035, 0.8, 0.58), _material("poster", Color("e0d7b1")))
		_box(self, Vector3(facade_x, 1.55, at.z + 2.0) + facade_normal * 0.065, Vector3(0.04, 0.07, 0.4), _material("poster_ink", Color("7a6755")))


func _add_window(at: Vector3, dimensions: Vector3, facing: Vector3) -> void:
	_window_transforms.append(Transform3D(Basis.IDENTITY.scaled(dimensions), at + facing * 0.025))
	var frame_size := dimensions + Vector3(0.24 if dimensions.x > 0.1 else 0.0, 0.24, 0.24 if dimensions.z > 0.1 else 0.0)
	_frame_transforms.append(Transform3D(Basis.IDENTITY.scaled(frame_size), at - facing * 0.015))


func _window_batch() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	multimesh.mesh = mesh
	multimesh.instance_count = _window_transforms.size()
	for index in range(_window_transforms.size()):
		multimesh.set_instance_transform(index, _window_transforms[index])
		# Vidro com profundidade visual, e só algumas janelas ainda iluminadas.
		var pane_color: Color = Color("d2bd8b") if index % 9 == 0 else Color("344e50").lerp(Color("789092"), float(index % 4) / 5.0)
		multimesh.set_instance_color(index, pane_color)
	var windows := MultiMeshInstance3D.new()
	windows.multimesh = multimesh
	var glass: StandardMaterial3D = Art.surface(Color.WHITE, "metal")
	glass.vertex_color_use_as_albedo = true
	glass.roughness = 0.28
	glass.metallic = 0.20
	windows.material_override = glass
	windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(windows)
	_batch_boxes("WindowFrames", _frame_transforms, _material("window_frames", Color("535e4d")))


func _tower() -> void:
	var stone := _material("tower_stone", Color("69767b"))
	var copper := _material("copper", Color("bc9460"))
	_box(self, Vector3(0, 3, -29), Vector3(9, 6, 8), stone, true)
	_box(self, Vector3(0, 10, -29), Vector3(3.7, 16, 3.7), stone, true)
	_box(self, Vector3(0, 18.3, -29), Vector3(5.0, 1.0, 5.0), copper)
	_cylinder(self, Vector3(0, 21, -29), 1.6, 4.5, _material("tower_roof", Color("2b5863")), 0.0)
	_cylinder(self, Vector3(0, 25, -29), 0.09, 5.8, copper)
	for y in [23.0, 24.0, 25.0]:
		_box(self, Vector3(0, y, -29), Vector3(2.3, 0.07, 0.07), copper)
	_tower_lamp = _cylinder(self, Vector3(0, 28.1, -29), 0.18, 0.4, _material("tower_off", Color("b0644e"), 0.8))
	var face := _cylinder(self, Vector3(0, 15, -27.08), 1.38, 0.08, _material("clock_face", Color("ffe9b6"), 0.5))
	face.rotation_degrees.x = 90
	_box(self, Vector3(0, 15.35, -26.99), Vector3(0.08, 0.75, 0.08), _material("clock_hands", Color("263c4c")))
	var hand := _box(self, Vector3(0.32, 14.87, -26.98), Vector3(0.75, 0.07, 0.08), _material("clock_hands", Color("263c4c")))
	hand.rotation.z = -0.35
	_label(self, Vector3(0, 7.2, -24.8), "TORRE DE TRANSMISSÃO", 40)
	_box(self, Vector3(0, 1.15, -24.8), Vector3(1.8, 2.3, 0.45), _material("terminal", Color("213b49")))
	_box(self, Vector3(0, 1.55, -24.54), Vector3(1.2, 0.6, 0.05), _material("terminal_screen", Color("81aab4"), 0.5))
	_tower_beacon = Node3D.new()
	_tower_beacon.position = tower_point
	add_child(_tower_beacon)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.1
	ring.outer_radius = 1.28
	ring.rings = 16
	ring.ring_segments = 8
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.position.y = 0.11
	ring_mesh.material_override = _material("tower_ring", Color("829ca4"), 0.35)
	_tower_beacon.add_child(ring_mesh)
	_label(_tower_beacon, Vector3(0, 3, 0), "REÚNA AS 3 PROVAS", 25, Color("bbced3"))


func _lamp(at: Vector3) -> void:
	var metal := _material("lamp_metal", Color("293f4c"))
	_cylinder(self, at + Vector3(0, 2.4, 0), 0.08, 4.8, metal)
	_box(self, at + Vector3(0, 4.7, 0), Vector3(0.8, 0.13, 0.8), metal)
	_box(self, at + Vector3(0, 4.58, 0), Vector3(0.55, 0.12, 0.55), _material("lamp_glow", Color("ffcc86"), 1.0))
	# Iluminação local limitada; a luz ambiente mantém tudo visível no celular.
	if at.z == 15.0 or at.z == -18.0:
		var light := OmniLight3D.new()
		light.position = at + Vector3(0, 3.8, 0)
		light.light_color = Color("ffc984")
		light.light_energy = 0.65
		light.omni_range = 7.0
		light.shadow_enabled = false
		add_child(light)


func _tree(at: Vector3) -> void:
	var bark: StandardMaterial3D = _material("tree_trunk", Color("796b56"))
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var profile: Array[Vector3] = [Vector3(0.22, 0.0, 0.19), Vector3(0.15, 0.65, 0.14), Vector3(0.125, 1.6, 0.11), Vector3(0.08, 2.8, 0.075)]
	trunk.mesh = Art.profile(profile, 16)
	trunk.position = at
	trunk.material_override = bark
	add_child(trunk)
	_branch(at + Vector3(0, 1.8, 0), at + Vector3(-0.75, 2.65, 0.1), bark)
	_branch(at + Vector3(0, 2.1, 0), at + Vector3(0.70, 2.85, 0.1), bark)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = absi(hash(at))
	var lobes: Array[Vector3] = [
		Vector3(-0.70, 2.65, 0.05), Vector3(0.65, 2.8, 0.15),
		Vector3(-0.15, 3.35, -0.15), Vector3(-0.3, 3.0, 0.6),
		Vector3(0.45, 3.15, -0.45), Vector3(-0.75, 3.1, -0.4),
		Vector3(0.4, 3.7, 0.1), Vector3(0.1, 2.65, -0.65),
	]
	for offset: Vector3 in lobes:
		var leaf_size: Vector3 = Vector3(random.randf_range(1.7, 2.3), random.randf_range(1.35, 1.85), random.randf_range(1.55, 2.0))
		var basis: Basis = Basis.from_euler(Vector3(random.randf_range(-0.15, 0.15), random.randf_range(0, TAU), random.randf_range(-0.15, 0.15)))
		_leaf_transforms.append(Transform3D(basis.scaled(leaf_size), at + offset))
		_leaf_colors.append(Color("3d6041").lerp(Color("82975b"), random.randf_range(0.18, 0.9)))
	var shadow: Sprite3D = Sprite3D.new()
	shadow.texture = Art.shadow_texture()
	shadow.pixel_size = 3.8 / 64.0
	shadow.rotation.x = -PI * 0.5
	shadow.position = at + Vector3(0, 0.095, 0)
	shadow.shaded = false
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	_box(self, at + Vector3(0, 0.12, 0), Vector3(2, 0.24, 2), _material("planter", Color("92907a")), true)


func _branch(from: Vector3, to: Vector3, material: Material) -> void:
	var direction: Vector3 = to - from
	var branch: MeshInstance3D = _cylinder(self, (from + to) * 0.5, 0.08, direction.length(), material, 0.045)
	branch.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))


func _foliage_batch() -> void:
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = Art.ellipsoid(Vector3.ONE)
	batch.instance_count = _leaf_transforms.size()
	for index in range(_leaf_transforms.size()):
		batch.set_instance_transform(index, _leaf_transforms[index])
		batch.set_instance_color(index, _leaf_colors[index])
	var leaves: MultiMeshInstance3D = MultiMeshInstance3D.new()
	leaves.name = "SmoothTreeCrowns"
	leaves.multimesh = batch
	var material: StandardMaterial3D = Art.surface(Color.WHITE, "leaf")
	material.vertex_color_use_as_albedo = true
	leaves.material_override = material
	add_child(leaves)


func _batch_boxes(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _street_details() -> void:
	var paving: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for z in range(-34, 31, 2):
			paving.append(Transform3D(Basis.IDENTITY.scaled(Vector3(4.2, 0.008, 0.025)), Vector3(side * 6.8, 0.086, float(z))))
		for x_offset in [-1.05, 1.05]:
			paving.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.025, 0.008, 66)), Vector3(side * 6.8 + x_offset, 0.086, -3)))
	_batch_boxes("PavementJoints", paving, _material("paving_joints", Color("7a806d")))
	var patches: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = 4816
	for index in range(36):
		var at := Vector3(random.randf_range(-3.5, 3.5), 0.037, random.randf_range(-30, 26))
		var dimensions := Vector3(random.randf_range(0.2, 0.6), 0.004, random.randf_range(0.4, 1.4))
		patches.append(Transform3D(Basis(Vector3.UP, random.randf_range(-0.15, 0.15)).scaled(dimensions), at))
	_batch_boxes("AsphaltPatches", patches, _material("asphalt_patch", Color("4b534b")))
	var papers: Array[Transform3D] = []
	for at in [Vector3(-8.8, 0.092, 2.5), Vector3(7.0, 0.092, 11.5), Vector3(-7.3, 0.092, -12.8), Vector3(8.3, 0.092, -5.2)]:
		papers.append(Transform3D(Basis(Vector3.UP, random.randf_range(-0.8, 0.8)).scaled(Vector3(0.23, 0.005, 0.32)), at))
	_batch_boxes("DroppedNewspapers", papers, _material("newsprint", Color("c8c3a4")))


func _gardens() -> void:
	# Três lâminas cruzadas formam cada tufo. Milhares de tufos usam uma só chamada.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(3):
		var angle: float = float(index) * PI / 3.0
		var side := Vector3(cos(angle) * 0.075, 0, sin(angle) * 0.075)
		var tip := Vector3(sin(angle) * 0.055, 0.52 + float(index % 2) * 0.12, cos(angle) * 0.055)
		var normal: Vector3 = (side * 2.0).cross(tip + side).normalized()
		for vertex in [-side, side, tip]:
			tool.set_normal(normal)
			tool.add_vertex(vertex)
	var grass_mesh: ArrayMesh = tool.commit()
	var patches: Array[Rect2] = [
		Rect2(-16, 16, 6, 15), Rect2(10.5, 18, 5, 13),
		Rect2(-38, -35, 3, 70), Rect2(34, -35, 4, 70),
		Rect2(-16, -6, 5, 4), Rect2(11.5, -22, 4, 6),
	]
	var count: int = 0
	for patch: Rect2 in patches:
		count += int(patch.get_area() * 3.0)
		_box(self, Vector3(patch.get_center().x, 0.014, patch.get_center().y), Vector3(patch.size.x, 0.024, patch.size.y), _material("garden_soil", Color("596b45")))
	var grass := MultiMesh.new()
	grass.transform_format = MultiMesh.TRANSFORM_3D
	grass.use_colors = true
	grass.mesh = grass_mesh
	grass.instance_count = count
	var random := RandomNumberGenerator.new()
	random.seed = 7084
	var instance_index: int = 0
	for patch: Rect2 in patches:
		for index in range(int(patch.get_area() * 3.0)):
			var at := Vector3(random.randf_range(patch.position.x, patch.end.x), 0.028, random.randf_range(patch.position.y, patch.end.y))
			var scale_factor: float = random.randf_range(0.65, 1.3)
			grass.set_instance_transform(instance_index, Transform3D(Basis(Vector3.UP, random.randf_range(0, TAU)).scaled(Vector3.ONE * scale_factor), at))
			grass.set_instance_color(instance_index, Color("879153").lerp(Color("49633d"), random.randf()))
			instance_index += 1
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_color = Color.WHITE
	grass_material.vertex_color_use_as_albedo = true
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.roughness = 1.0
	var grass_node := MultiMeshInstance3D.new()
	grass_node.name = "GrassPatches"
	grass_node.multimesh = grass
	grass_node.material_override = grass_material
	grass_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass_node)
	# Cercas mantêm os canteiros visíveis sem fechar os acessos à praça.
	var fence_parts: Array[Transform3D] = []
	for x in [-16.7, 15.8]:
		for z in range(19, 32, 2):
			fence_parts.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.09, 1.15, 0.09)), Vector3(x, 0.58, float(z))))
		for y in [0.28, 0.91]:
			fence_parts.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.055, 0.055, 12)), Vector3(x, y, 25)))
		for z in range(20, 31, 2):
			for angle in [-0.38, 0.38]:
				fence_parts.append(Transform3D(Basis(Vector3.RIGHT, angle).scaled(Vector3(0.022, 0.022, 2.1)), Vector3(x, 0.60, float(z))))
		var fence_body := StaticBody3D.new()
		fence_body.position = Vector3(x, 0.55, 25)
		var fence_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.1, 1.1, 12)
		fence_shape.shape = box
		fence_body.add_child(fence_shape)
		add_child(fence_body)
	_batch_boxes("GardenFences", fence_parts, _material("garden_fence", Color("58634d")))
	_tree(Vector3(-12.5, 0, 24))
	_tree(Vector3(12.6, 0, 26))
	_shrub_batch()


func _shrub_batch() -> void:
	var shrub_mesh: Mesh = Art.ellipsoid(Vector3(1.25, 0.85, 1.1))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = shrub_mesh
	batch.instance_count = 28
	for index in range(28):
		var x: float = -15.2 if index < 14 else 14.4
		var z: float = 18.0 + float(index % 14) * 0.9
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.8 + float(index % 3) * 0.1, 1.0)), Vector3(x, 0.42, z)))
		batch.set_instance_color(index, Color("6a7e4b") if index % 3 == 0 else Color("526b40"))
	var material: StandardMaterial3D = Art.surface(Color.WHITE, "leaf")
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var instance := MultiMeshInstance3D.new()
	instance.name = "ParkShrubs"
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _public_props() -> void:
	var wood := _material("crate_wood", Color("927d59"))
	for at in [Vector3(-14, 0, 10.5), Vector3(14, 0, -18), Vector3(-25, 0, -8)]:
		_box(self, at + Vector3(0, 0.38, 0), Vector3(0.9, 0.76, 0.9), wood, true)
		for y in [0.12, 0.58]:
			_box(self, at + Vector3(0, y, 0), Vector3(0.94, 0.06, 0.94), _material("crate_band", Color("5c6550")))
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 9.4, 0, 13)
		_cylinder(self, at + Vector3(0, 0.4, 0), 0.06, 0.8, _material("furniture_metal", Color("4b5a49")))
		_box(self, at + Vector3(0, 0.95, 0), Vector3(0.5, 0.45, 0.4), _material("mailbox", Color("647652")))
		_box(self, at + Vector3(0, 1.0, 0.21), Vector3(0.32, 0.035, 0.025), _material("mail_slot", Color("283b31")))
	# Bicicleta apoiada perto do jardim. Geometria simples, sem textura externa.
	var bicycle := Node3D.new()
	bicycle.position = Vector3(9.7, 0, 20)
	add_child(bicycle)
	var tyre := TorusMesh.new()
	tyre.inner_radius = 0.29
	tyre.outer_radius = 0.34
	tyre.rings = 12
	tyre.ring_segments = 6
	for z in [-0.65, 0.65]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = tyre
		wheel.position = Vector3(0, 0.36, z)
		wheel.rotation.z = PI * 0.5
		wheel.material_override = _material("bike_tyre", Color("344135"))
		bicycle.add_child(wheel)
	var frame := _material("bike_frame", Color("9c6b51"))
	_rod(bicycle, Vector3(0, 0.36, -0.65), Vector3(0, 0.85, 0.05), frame)
	_rod(bicycle, Vector3(0, 0.85, 0.05), Vector3(0, 0.36, 0.65), frame)
	_rod(bicycle, Vector3(0, 0.36, -0.65), Vector3(0, 0.36, 0.20), frame)
	_rod(bicycle, Vector3(0, 0.36, 0.20), Vector3(0, 0.85, 0.05), frame)
	_rod(bicycle, Vector3(0, 0.85, 0.05), Vector3(0, 0.82, -0.4), frame)
	_rod(bicycle, Vector3(0, 0.82, -0.4), Vector3(0, 0.36, -0.65), frame)
	_box(bicycle, Vector3(0, 0.97, 0.05), Vector3(0.27, 0.09, 0.30), _material("bike_seat", Color("4a4f3f")))
	_box(bicycle, Vector3(0, 0.98, -0.45), Vector3(0.6, 0.055, 0.055), frame)


func _rod(parent: Node3D, from: Vector3, to: Vector3, material: Material) -> void:
	var direction: Vector3 = to - from
	var rod := _cylinder(parent, (from + to) * 0.5, 0.025, direction.length(), material)
	rod.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))


func _bench(at: Vector3, angle: float) -> void:
	var bench := Node3D.new()
	bench.position = at
	bench.rotation.y = angle
	add_child(bench)
	var wood := _material("bench", Color("ae8960"))
	_box(bench, Vector3(0, 0.6, 0), Vector3(2.2, 0.18, 0.6), wood, true)
	_box(bench, Vector3(0, 1.0, 0.3), Vector3(2.2, 0.65, 0.12), wood, true)
	for x in [-0.8, 0.8]:
		_box(bench, Vector3(x, 0.3, 0), Vector3(0.1, 0.6, 0.5), _material("lamp_metal", Color("293f4c")))


func _barricade(at: Vector3, angle: float) -> void:
	var barrier := Node3D.new()
	barrier.position = at
	barrier.rotation.y = angle
	add_child(barrier)
	_box(barrier, Vector3(0, 0.8, 0), Vector3(3.2, 0.6, 0.4), _material("barrier", Color("c5a773")), true)
	for x in [-1.2, -0.4, 0.4, 1.2]:
		var stripe := _box(barrier, Vector3(x, 0.8, 0.215), Vector3(0.25, 0.58, 0.025), _material("barrier_stripe", Color("36464d")))
		stripe.rotation.z = -0.25
	for x in [-1.1, 1.1]:
		_box(barrier, Vector3(x, 0.3, 0), Vector3(0.14, 0.6, 0.8), _material("lamp_metal", Color("293f4c")))


func _evidence(data: Dictionary) -> void:
	var at: Vector3 = data["position"]
	var id: String = data["id"]
	var stand := Node3D.new()
	stand.position = at
	stand.name = "Prova_" + id
	add_child(stand)
	_box(stand, Vector3(0, 0.65, 0), Vector3(1.2, 1.3, 0.75), _material("evidence_stand", Color("385764")), true)
	_box(stand, Vector3(0, 1.32, 0), Vector3(1.35, 0.12, 0.85), _material("evidence_table", Color("b49973")))
	var beacon := Node3D.new()
	beacon.position.y = 1.85
	stand.add_child(beacon)
	var document := _box(beacon, Vector3.ZERO, Vector3(0.5, 0.65, 0.08), _material("proof", Color("ffd398"), 0.7))
	document.rotation.z = -0.12
	for y in [-0.14, 0.0, 0.14]:
		_box(beacon, Vector3(0, y, 0.045), Vector3(0.3, 0.035, 0.018), _material("document_ink", Color("785b3b")))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.86
	ring.outer_radius = 0.99
	ring.rings = 16
	ring.ring_segments = 6
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.position.y = 0.1
	ring_node.material_override = _material("proof_ring", Color("ffd398"), 0.6)
	stand.add_child(ring_node)
	_label(stand, Vector3(0, 3.0, 0), "RECOLHER PROVA", 24)
	_beacons[id] = beacon
	_beacon_stems[id] = stand


func _patrol(at: Vector3, index: int) -> void:
	var patrol := Node3D.new()
	patrol.name = "Vigia%d" % index
	patrol.position = at
	add_child(patrol)
	var body := _box(patrol, Vector3.ZERO, Vector3(0.85, 0.35, 0.6), _material("patrol_body", Color("24313b")))
	body.rotation.z = 0.08
	_box(patrol, Vector3(0, -0.05, 0.32), Vector3(0.65, 0.12, 0.04), _material("patrol_eye", Color("e4b775"), 1.0))
	for x in [-0.65, 0.65]:
		_box(patrol, Vector3(x, 0.05, 0), Vector3(0.5, 0.06, 0.16), _material("patrol_metal", Color("59727b")))
		_cylinder(patrol, Vector3(x, 0.1, 0), 0.26, 0.05, _material("patrol_rotor", Color("1e2d36")))
	var cone_material := StandardMaterial3D.new()
	cone_material.albedo_color = Color(0.95, 0.72, 0.35, 0.09)
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := _cylinder(patrol, Vector3(0, -0.65, 0), 1.6, 1.3, cone_material, 0.08)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patrols.append(patrol)
	_patrol_origins.append(at)


func mark_collected(id: String) -> void:
	if _beacons.has(id):
		var beacon: Node3D = _beacons[id]
		beacon.visible = false
	if _beacon_stems.has(id):
		var stand: Node3D = _beacon_stems[id]
		for child in stand.get_children():
			if child is Label3D:
				child.text = "PROVA RECOLHIDA"
				child.modulate = Color("99c7b7")


func set_tower_active(active: bool) -> void:
	_tower_active = active
	if _tower_beacon == null:
		return
	var color := Color("a2ebd0") if active else Color("829ca4")
	for child in _tower_beacon.get_children():
		if child is MeshInstance3D:
			child.material_override = _material("tower_ring_active" if active else "tower_ring", color, 0.6)
		elif child is Label3D:
			child.text = "TRANSMITIR O DOSSIÊ" if active else "REÚNA AS 3 PROVAS"
			child.modulate = color
	if _tower_lamp != null:
		_tower_lamp.material_override = _material("tower_active" if active else "tower_off", color, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	for id: String in _beacons:
		var beacon: Node3D = _beacons[id]
		beacon.position.y = 1.85 + sin(_clock * 2.0) * 0.08
		beacon.rotation.y = sin(_clock * 0.7) * 0.2
	for index in range(patrols.size()):
		var origin: Vector3 = _patrol_origins[index]
		var patrol: Node3D = patrols[index]
		patrol.position = origin + Vector3(sin(_clock * 0.35 + float(index) * PI) * 3.2, sin(_clock * 1.6) * 0.08, cos(_clock * 0.24 + float(index)) * 3.2)
		patrol.rotation.y = sin(_clock * 0.3 + float(index)) * 0.65
