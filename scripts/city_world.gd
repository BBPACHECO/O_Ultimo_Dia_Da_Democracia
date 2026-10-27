extends Node3D
## Cidade original construída com geometria nativa. Sem assets ou serviços remotos.

var spawn_point: Vector3 = Vector3(0.0, 0.0, 16.0)
var tower_point: Vector3 = Vector3(0.0, 0.0, -24.0)
var evidence_points: Array = [
	{"id": "arquivo", "title": "ARQUIVO MUNICIPAL", "position": Vector3(-14.0, 0.0, 2.0), "description": "Um registro assinado liga o decreto ao fechamento da assembleia."},
	{"id": "gravacao", "title": "ESTAÇÃO DE RÁDIO", "position": Vector3(13.0, 0.0, -8.0), "description": "A gravação de uma testemunha confirma a operação desta noite."},
	{"id": "lista", "title": "A ÚLTIMA REDAÇÃO", "position": Vector3(-9.0, 0.0, -18.0), "description": "Uma lista de ordens e horários completa o dossiê."},
]
var patrols: Array[Node3D] = []
var _built: bool = false
var _clock: float = 0.0
var _beacons: Dictionary = {}
var _beacon_stems: Dictionary = {}
var _tower_beacon: Node3D
var _tower_lamp: MeshInstance3D
var _tower_active: bool = false
var _materials: Dictionary = {}
var _window_transforms: Array[Transform3D] = []
var _patrol_origins: Array[Vector3] = []


func _ready() -> void:
	build_world()


func _material(key: String, color: Color, emissive: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if emissive > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emissive
	_materials[key] = material
	return material


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
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
	mesh.radial_segments = 10
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
	var ground := _material("ground", Color("354b54"))
	var road := _material("road", Color("21313d"))
	var sidewalk := _material("sidewalk", Color("67777b"))
	var curb := _material("curb", Color("91a0a1"))
	var paint := _material("paint", Color("b2b7aa"))
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
	_building(Vector3(-21, 0, 1), Vector3(10, 10, 11), Color("53646b"), "ARQUIVO MUNICIPAL", true)
	_building(Vector3(22, 0, -9), Vector3(11, 12, 13), Color("47616b"), "RÁDIO AURORA · 104.3", false)
	_building(Vector3(-18, 0, -20), Vector3(10, 8, 10), Color("5d6066"), "JORNAL FAROL", true)
	_building(Vector3(-23, 0, 20), Vector3(12, 14, 12), Color("374c5a"), "", true)
	_building(Vector3(23, 0, 20), Vector3(14, 17, 12), Color("4e606b"), "", false)
	_building(Vector3(24, 0, -26), Vector3(13, 15, 12), Color("465566"), "", false)
	_building(Vector3(-29, 0, -28), Vector3(10, 19, 11), Color("3a5062"), "", true)
	_building(Vector3(27, 0, 5), Vector3(10, 8, 8), Color("6b6d6c"), "", false)
	# Skyline distante: visível, mas fora da área física de jogo.
	for index in range(11):
		var x := -42.0 + float(index) * 8.0
		var height := 11.0 + float((index * 7) % 13)
		_box(self, Vector3(x, height / 2.0, -43), Vector3(6, height, 7), _material("skyline", Color("283d50")))
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
	sky_material.sky_top_color = Color("09192e")
	sky_material.sky_horizon_color = Color("2c435b")
	sky_material.ground_bottom_color = Color("243d4e")
	sky_material.ground_horizon_color = Color("2c435b")
	sky_material.sun_angle_max = 1.5
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("88a4bc")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("344e68")
	environment.fog_light_energy = 0.4
	environment.fog_density = 0.006
	environment_node.environment = environment
	add_child(environment_node)
	var moon := DirectionalLight3D.new()
	moon.name = "LuzDaCidade"
	moon.rotation_degrees = Vector3(-48, -30, 0)
	moon.light_color = Color("d4e2e7")
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(moon)


func _building(at: Vector3, dimensions: Vector3, color: Color, sign: String, faces_east: bool) -> void:
	var mat_key := "building_%s" % color.to_html()
	_box(self, at + Vector3(0, dimensions.y / 2.0, 0), dimensions, _material(mat_key, color), true)
	_box(self, at + Vector3(0, dimensions.y + 0.2, 0), Vector3(dimensions.x + 0.4, 0.4, dimensions.z + 0.4), _material("roof", Color("273c4a")))
	var facade_x := at.x + (dimensions.x / 2.0 + 0.05) * (1 if faces_east else -1)
	for floor_index in range(1, int(dimensions.y / 2.5)):
		for column in range(4):
			if (floor_index + column) % 5 == 0:
				continue
			var z := at.z - dimensions.z * 0.35 + float(column) * dimensions.z * 0.23
			_window_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.06, 1.1, 1.1)), Vector3(facade_x, float(floor_index) * 2.5, z)))
	# Mais janelas na face que aponta para a praça e a câmera inicial.
	for floor_index in range(1, int(dimensions.y / 2.5)):
		for column in range(3):
			var x := at.x - dimensions.x * 0.28 + float(column) * dimensions.x * 0.28
			_window_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.1, 0.06)), Vector3(x, float(floor_index) * 2.5, at.z + dimensions.z / 2.0 + 0.05)))
	if not sign.is_empty():
		var sign_at := Vector3(facade_x + (0.1 if faces_east else -0.1), 3.0, at.z)
		_label(self, sign_at, sign, 27)
		_box(self, Vector3(facade_x, 1.2, at.z), Vector3(0.12, 2.4, 1.5), _material("door", Color("243340")))


func _window_batch() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	multimesh.mesh = mesh
	multimesh.instance_count = _window_transforms.size()
	for index in range(_window_transforms.size()):
		multimesh.set_instance_transform(index, _window_transforms[index])
	var windows := MultiMeshInstance3D.new()
	windows.multimesh = multimesh
	windows.material_override = _material("window", Color("f0c78d"), 0.75)
	windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(windows)


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
	_cylinder(self, at + Vector3(0, 1.1, 0), 0.16, 2.2, _material("tree_trunk", Color("70574a")))
	_cylinder(self, at + Vector3(0, 3.0, 0), 1.4, 3.0, _material("tree_crown", Color("416a65")), 0.1)
	_box(self, at + Vector3(0, 0.12, 0), Vector3(2, 0.24, 2), _material("planter", Color("526267")), true)


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
