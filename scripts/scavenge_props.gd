extends Node3D
## Carros, corpos e recipientes originais; o inventário pertence à missão.
const Art = preload("res://scripts/art_geometry.gd")
const LootCatalog = preload("res://scripts/loot_catalog.gd")

var loot_points: Array = LootCatalog.POINTS.duplicate(true)
var cars: Array[Node3D] = []
var bodies: Array[Node3D] = []
var _built: bool = false
var _markers: Dictionary = {}
var _lids: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	build_props()


func build_props() -> void:
	if _built:
		return
	_built = true
	_car("car_praca", Vector3(2.8, 0, 18.5), 0.0, Color("587584"), false)
	_car("car_radio", Vector3(-2.8, 0, -5), PI, Color("6e7e63"), true)
	_car("car_cruzamento", Vector3(17, 0, 2), PI * 0.5, Color("785c59"), true)
	_corpse("body_praca", Vector3(-10.5, 0, 15.5), -0.65, Color("687889"), Color("635e52"), false)
	_corpse("body_jardim", Vector3(8.5, 0, 22), 0.75, Color("978774"), Color("465354"), false)
	_corpse("body_radio", Vector3(-8, 0, -6), -0.2, Color("3e7c46"), Color("444a42"), true)
	for point: Dictionary in loot_points:
		if point["kind"] == "house":
			_container(point)
		_marker(point)


func _material(key: String, color: Color, kind: String = "plain") -> StandardMaterial3D:
	if not _materials.has(key):
		_materials[key] = Art.surface(color, kind)
	return _materials[key]


func _mesh(parent: Node3D, geometry: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, bevel: float = 0.045) -> MeshInstance3D:
	return _mesh(parent, Art.rounded_box(size, bevel), at, material)


func _car(id: String, at: Vector3, yaw: float, color: Color, damaged: bool) -> void:
	var car: Node3D = Node3D.new()
	car.name = id
	car.position = at
	car.rotation.y = yaw
	add_child(car)
	cars.append(car)
	var paint: Material = _material("paint_" + color.to_html(), color, "metal")
	var dark_paint: Material = _material("dark_" + color.to_html(), color.darkened(0.24), "metal")
	var trim: Material = _material("trim", Color("353c3b"), "metal")
	var glass: StandardMaterial3D = _material("glass", Color("263c40"))
	glass.roughness = 0.22
	glass.metallic = 0.35
	var rubber: Material = _material("rubber", Color("252b28"))
	var hub: Material = _material("hub", Color("90978d"), "metal")
	var lamp: Material = _material("headlamp", Color("ded7b1"))
	var brake: Material = _material("brake", Color("a15445"))
	# A carroceria baixa e as rodas largas mantêm a escala humana.
	_box(car, Vector3(0, 0.55, 0), Vector3(1.82, 0.58, 4.05), paint, 0.20)
	_box(car, Vector3(0, 0.86, -1.23), Vector3(1.70, 0.17, 1.38), dark_paint, 0.075)
	_box(car, Vector3(0, 1.12, 0.05), Vector3(1.56, 0.72, 1.85), paint, 0.20)
	# Vidros escuros não transparentes evitam transparências caras no Android.
	var windscreen: MeshInstance3D = _box(car, Vector3(0, 1.22, -0.78), Vector3(1.30, 0.46, 0.07), glass, 0.03)
	windscreen.rotation.x = -0.25
	var rear_window: MeshInstance3D = _box(car, Vector3(0, 1.22, 0.88), Vector3(1.29, 0.42, 0.07), glass, 0.03)
	rear_window.rotation.x = 0.22
	_box(car, Vector3(0, 1.50, 0.09), Vector3(1.43, 0.12, 1.45), paint, 0.045)
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.35, 0.44]:
			_box(car, Vector3(side * 0.793, 1.23, z), Vector3(0.035, 0.39, 0.65), glass, 0.018)
			_box(car, Vector3(side * 0.929, 0.72, z), Vector3(0.022, 0.42, 0.72), dark_paint, 0.015)
			_box(car, Vector3(side * 0.949, 0.86, z + 0.16), Vector3(0.035, 0.035, 0.18), hub, 0.012)
		_box(car, Vector3(side * 0.816, 1.22, 0.055), Vector3(0.055, 0.49, 0.065), trim, 0.015)
		_box(car, Vector3(side * 0.98, 1.02, -0.58), Vector3(0.18, 0.15, 0.27), dark_paint, 0.06)
		for z: float in [-1.29, 1.30]:
			var wheel: CylinderMesh = CylinderMesh.new()
			wheel.top_radius = 0.36
			wheel.bottom_radius = 0.36
			wheel.height = 0.23
			wheel.radial_segments = 16
			var tire: MeshInstance3D = _mesh(car, wheel, Vector3(side * 0.88, 0.36, z), rubber)
			tire.rotation.z = PI * 0.5
			var cap: CylinderMesh = CylinderMesh.new()
			cap.top_radius = 0.205
			cap.bottom_radius = 0.205
			cap.height = 0.025
			cap.radial_segments = 12
			var hubcap: MeshInstance3D = _mesh(car, cap, Vector3(side * 1.005, 0.36, z), hub)
			hubcap.rotation.z = PI * 0.5
		_box(car, Vector3(side * 0.57, 0.75, -2.035), Vector3(0.47, 0.20, 0.075), lamp)
		_box(car, Vector3(side * 0.64, 0.75, 2.035), Vector3(0.33, 0.19, 0.075), brake)
	_box(car, Vector3(0, 0.47, -2.04), Vector3(1.76, 0.16, 0.12), trim)
	_box(car, Vector3(0, 0.47, 2.04), Vector3(1.76, 0.16, 0.12), trim)
	_box(car, Vector3(0, 0.72, -2.047), Vector3(0.46, 0.11, 0.016), trim, 0.005)
	_box(car, Vector3(0, 0.66, 2.105), Vector3(0.46, 0.17, 0.025), hub, 0.006)
	var trunk: Node3D = Node3D.new()
	trunk.position = Vector3(0, 0.93, 0.93)
	car.add_child(trunk)
	_box(trunk, Vector3(0, 0, 0.51), Vector3(1.64, 0.10, 1.01), dark_paint)
	_lids[id] = trunk
	if damaged:
		var scratch: Material = _material("scratch", Color("b2a18b"), "metal")
		for index: int in range(3):
			var scar: MeshInstance3D = _box(car, Vector3(0.954, 0.67 + index * 0.065, -0.52 + index * 0.12), Vector3(0.018, 0.025, 0.64), scratch, 0.004)
			scar.rotation.x = 0.19
		_box(car, Vector3(-0.45, 0.97, -1.31), Vector3(0.37, 0.025, 0.62), trim)
		# Rachaduras na janela são apenas duas tiras opacas, sem partículas.
		for sign_value: float in [-1.0, 1.0]:
			var crack: MeshInstance3D = _box(car, Vector3(0.18, 1.23, -0.833), Vector3(0.018, 0.32, 0.012), hub, 0.003)
			crack.rotation.z = sign_value * 0.55
	var hull: StaticBody3D = StaticBody3D.new()
	hull.name = "CarCollision"
	hull.collision_layer = 1
	hull.collision_mask = 2 | 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.96, 1.50, 4.20)
	shape.shape = box
	shape.position.y = 0.75
	hull.add_child(shape)
	car.add_child(hull)
	_contact_shadow(car, Vector3(0, 0.032, 0), Vector2(2.65, 4.75))
	_batch_static_meshes(car)


func _corpse(id: String, at: Vector3, yaw: float, shirt_color: Color, pants_color: Color, green_yellow: bool) -> void:
	var body: Node3D = Node3D.new()
	body.name = id
	body.position = at
	body.rotation.y = yaw
	add_child(body)
	bodies.append(body)
	var clothes: Material = _material("shirt_" + shirt_color.to_html(), shirt_color, "cloth")
	var pants: Material = _material("pants_" + pants_color.to_html(), pants_color, "cloth")
	var skin: Material = _material("body_skin", Color("a39d86"), "skin")
	var hair: Material = _material("body_hair", Color("47423b"))
	var shoe: Material = _material("body_shoe", Color("30342f"))
	_contact_shadow(body, Vector3(0, 0.033, 0.07), Vector2(1.55, 2.70))
	# Silhueta deitada, braços soltos e olhos fechados; sem sangue explícito.
	_mesh(body, Art.ellipsoid(Vector3(0.55, 0.30, 0.65)), Vector3(0, 0.20, -0.20), clothes)
	_mesh(body, Art.ellipsoid(Vector3(0.37, 0.30, 0.34)), Vector3(0.025, 0.22, -0.76), skin)
	_mesh(body, Art.ellipsoid(Vector3(0.38, 0.20, 0.24)), Vector3(0.025, 0.24, -0.87), hair)
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = _box(body, Vector3(side * 0.065, 0.368, -0.75), Vector3(0.045, 0.009, 0.012), hair, 0.003)
		eye.rotation.y = side * 0.15
		var thigh: MeshInstance3D = _mesh(body, Art.capsule(0.105, 0.60), Vector3(side * 0.13, 0.16, 0.35), pants)
		thigh.rotation.x = PI * 0.5
		thigh.rotation.y = side * 0.10
		var calf: MeshInstance3D = _mesh(body, Art.capsule(0.085, 0.49), Vector3(side * 0.19, 0.13, 0.83), pants)
		calf.rotation.x = PI * 0.5
		calf.rotation.y = side * 0.12
		_mesh(body, Art.ellipsoid(Vector3(0.21, 0.19, 0.31)), Vector3(side * 0.22, 0.13, 1.09), shoe)
		var arm: MeshInstance3D = _mesh(body, Art.capsule(0.078, 0.48), Vector3(side * 0.37, 0.14, -0.28), clothes)
		arm.rotation.x = PI * 0.5
		arm.rotation.y = side * 0.39
		var forearm: MeshInstance3D = _mesh(body, Art.capsule(0.062, 0.36), Vector3(side * 0.52, 0.12, 0.06), skin)
		forearm.rotation.x = PI * 0.5
		forearm.rotation.y = side * -0.17
		_mesh(body, Art.ellipsoid(Vector3(0.12, 0.10, 0.17)), Vector3(side * 0.49, 0.10, 0.27), skin)
	if green_yellow:
		var yellow: Material = _material("body_yellow", Color("d7bd3f"), "cloth")
		_box(body, Vector3(0, 0.355, -0.23), Vector3(0.48, 0.018, 0.17), yellow, 0.008)
	else:
		var bag: Material = _material("body_bag", Color("78634c"), "cloth")
		_box(body, Vector3(-0.48, 0.17, -0.55), Vector3(0.32, 0.30, 0.42), bag, 0.10)
	_batch_static_meshes(body)


func _batch_static_meshes(parent: Node3D) -> void:
	# Apenas filhos estáticos diretos: o pivô animado do porta-malas fica intacto.
	# Sombras de contato transparentes conservam o material e as flags originais.
	var groups: Dictionary = {}
	for child: Node in parent.get_children():
		if not child is MeshInstance3D:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or part.mesh == null:
			continue
		var material: StandardMaterial3D = part.material_override as StandardMaterial3D
		if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var key: int = material.get_instance_id()
		if not groups.has(key):
			groups[key] = []
		groups[key].append(part)
	for key: int in groups:
		var parts: Array = groups[key]
		if parts.size() < 2:
			continue
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in parts:
			tool.append_from(part.mesh, 0, part.transform)
		var geometry: ArrayMesh = tool.commit()
		var combined: MeshInstance3D = _mesh(parent, geometry, Vector3.ZERO, parts[0].material_override)
		combined.name = "LoteEstatico_" + str(key)
		for part: MeshInstance3D in parts:
			parent.remove_child(part)
			part.free()


func _container(point: Dictionary) -> void:
	var container: Node3D = Node3D.new()
	container.name = String(point["id"])
	container.position = point["position"]
	add_child(container)
	var metal: Material = _material("medical_tin", Color("b5b39c"), "metal")
	var red: Material = _material("medical_cross", Color("a55e50"))
	var edge: Material = _material("medical_edge", Color("697064"), "metal")
	_box(container, Vector3(0, 0.30, 0), Vector3(0.65, 0.52, 0.48), metal, 0.065)
	_box(container, Vector3(0, 0.57, 0), Vector3(0.69, 0.06, 0.52), edge)
	_box(container, Vector3(0, 0.61, 0), Vector3(0.12, 0.016, 0.29), red, 0.008)
	_box(container, Vector3(0, 0.61, 0), Vector3(0.29, 0.016, 0.12), red, 0.008)
	_box(container, Vector3(0, 0.37, -0.25), Vector3(0.14, 0.08, 0.035), edge)
	# Recipientes pequenos não criam obstáculos nas passagens das casas.


func _marker(point: Dictionary) -> void:
	var marker: Node3D = Node3D.new()
	marker.name = "Loot_" + String(point["id"])
	marker.position = point["position"] + Vector3.UP * (1.15 if point["kind"] == "car" else 0.85)
	add_child(marker)
	var amber: StandardMaterial3D = _material("loot_marker", Color("e5bc65"))
	amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var diamond: MeshInstance3D = _box(marker, Vector3.ZERO, Vector3(0.16, 0.16, 0.16), amber, 0.02)
	diamond.rotation_degrees = Vector3(25, 45, 25)
	_markers[String(point["id"])] = marker


func mark_looted(id: String) -> void:
	if _markers.has(id):
		(_markers[id] as Node3D).visible = false
	if _lids.has(id):
		(_lids[id] as Node3D).rotation.x = -0.62


func restore_looted(ids: Array) -> void:
	for id: String in _markers:
		(_markers[id] as Node3D).visible = id not in ids
	for id: String in _lids:
		(_lids[id] as Node3D).rotation.x = -0.62 if id in ids else 0.0


func _contact_shadow(parent: Node3D, at: Vector3, dimensions: Vector2) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = dimensions
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = Art.shadow_texture()
	var mesh: MeshInstance3D = _mesh(parent, plane, at, material)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
