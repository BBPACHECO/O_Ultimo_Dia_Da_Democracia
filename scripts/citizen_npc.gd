extends Node3D
## Cidadão original. As conversas e a pausa da missão são coordenadas pelo jogo.

const Art = preload("res://scripts/art_geometry.gd")

var npc_id: String = "lia"
var display_name: String = "Lia"
var visual: Node3D
var name_label: Label3D
var conversation_marker: Label3D
var spoken: bool = false
var _left_arm: Node3D
var _right_arm: Node3D
var _idle_clock: float = 0.0


func _ready() -> void:
	name = "Citizen_" + npc_id
	_build_character()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CitizenCollision"
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	body.add_child(shape)
	add_child(body)
	name_label = _label(display_name, 2.90, 31, Color("f2ead5"))
	conversation_marker = _label("● CONVERSAR", 2.15, 21, Color("e7b974"))
	mark_spoken(spoken)


func _material(color: Color, kind: String = "cloth") -> StandardMaterial3D:
	return Art.surface(color, kind)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	return _mesh(parent, Art.rounded_box(dimensions, minf(0.04, minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.24)), at, material)


func _capsule(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	return _mesh(parent, Art.capsule(radius, height), at, material)


func _limb(parent: Node3D, at: Vector3, length: float, radius: float, material: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	var rings: Array[Vector3] = [
		Vector3(radius * 0.58, -length, radius * 0.58),
		Vector3(radius * 0.78, -length * 0.85, radius * 0.73),
		Vector3(radius * 0.91, -length * 0.55, radius * 0.83),
		Vector3(radius * 0.87, -length * 0.46, radius * 0.78),
		Vector3(radius * 1.10, -length * 0.20, radius),
		Vector3(radius * 0.96, 0.0, radius * 0.92),
	]
	_mesh(pivot, Art.profile(rings, 16), Vector3.ZERO, material)
	return pivot


func _build_character() -> void:
	visual = Node3D.new()
	visual.name = "CitizenVisual"
	add_child(visual)
	var jacket_color: Color = Color("704b50")
	var trousers_color: Color = Color("343b3e")
	var skin_color: Color = Color("b98b69")
	var hair_color: Color = Color("352d2c")
	if npc_id == "ines":
		jacket_color = Color("aba18b")
		trousers_color = Color("555e4e")
		skin_color = Color("c2977b")
		hair_color = Color("aaa69b")
	elif npc_id == "tomas":
		jacket_color = Color("47647a")
		trousers_color = Color("4e5350")
		skin_color = Color("956d52")
		hair_color = Color("282b2a")
	var jacket: Material = _material(jacket_color)
	var trousers: Material = _material(trousers_color)
	var skin: Material = _material(skin_color, "skin")
	var hair: Material = _material(hair_color, "plain")
	var shoes: Material = _material(Color("292c2b"), "plain")
	var seam: Material = _material(jacket_color.darkened(0.25))
	var torso: Array[Vector3] = [
		Vector3(0.24, 0.79, 0.155), Vector3(0.26, 0.88, 0.17),
		Vector3(0.225, 1.05, 0.145), Vector3(0.255, 1.25, 0.17),
		Vector3(0.29, 1.40, 0.155), Vector3(0.255, 1.47, 0.135),
		Vector3(0.105, 1.52, 0.09),
	]
	_mesh(visual, Art.profile(torso), Vector3.ZERO, jacket)
	_box(visual, Vector3(0.018, 0.48, 0.015), Vector3(0, 1.13, -0.167), seam)
	for side: float in [-1.0, 1.0]:
		var collar: MeshInstance3D = _box(visual, Vector3(0.085, 0.17, 0.025), Vector3(side * 0.07, 1.38, -0.154), seam)
		collar.rotation.z = side * -0.25
	_capsule(visual, 0.075, 0.17, Vector3(0, 1.54, 0), skin)
	_mesh(visual, Art.ellipsoid(Vector3(0.335, 0.36, 0.31)), Vector3(0, 1.76, -0.005), skin)
	_mesh(visual, Art.ellipsoid(Vector3(0.345, 0.19, 0.325)), Vector3(0, 1.90, 0.018), hair)
	_mesh(visual, Art.ellipsoid(Vector3(0.052, 0.074, 0.058)), Vector3(0, 1.74, -0.168), skin)
	for side: float in [-1.0, 1.0]:
		_mesh(visual, Art.ellipsoid(Vector3(0.052, 0.08, 0.04)), Vector3(side * 0.167, 1.76, 0), skin)
		_box(visual, Vector3(0.027, 0.017, 0.013), Vector3(side * 0.062, 1.79, -0.155), hair)
		var leg: Node3D = _limb(visual, Vector3(side * 0.135, 0.79, 0), 0.66, 0.10, trousers)
		_mesh(leg, Art.ellipsoid(Vector3(0.19, 0.135, 0.30)), Vector3(0, -0.69, -0.05), shoes)
	_left_arm = _limb(visual, Vector3(-0.315, 1.39, 0), 0.53, 0.093, jacket)
	_right_arm = _limb(visual, Vector3(0.315, 1.39, 0), 0.53, 0.093, jacket)
	for arm: Node3D in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.13, 0.04, 0.13), Vector3(0, -0.49, 0), seam)
		_mesh(arm, Art.ellipsoid(Vector3(0.12, 0.16, 0.085)), Vector3(0, -0.585, -0.01), skin)
	if npc_id == "lia":
		# Longer hair and a rounded notebook distinguish the editor at a glance.
		_mesh(visual, Art.ellipsoid(Vector3(0.31, 0.26, 0.13)), Vector3(0, 1.75, 0.13), hair)
		_box(visual, Vector3(0.18, 0.26, 0.045), Vector3(0.19, 1.02, -0.20), _material(Color("d7ccb0"), "plain"))
	elif npc_id == "ines":
		_mesh(visual, Art.ellipsoid(Vector3(0.16, 0.15, 0.14)), Vector3(0, 1.87, 0.17), hair)
		for side: float in [-1.0, 1.0]:
			var glasses: TorusMesh = TorusMesh.new()
			glasses.inner_radius = 0.044
			glasses.outer_radius = 0.055
			glasses.rings = 10
			glasses.ring_segments = 6
			var frame: MeshInstance3D = _mesh(visual, glasses, Vector3(side * 0.063, 1.79, -0.161), seam)
			frame.rotation.x = PI * 0.5
		_box(visual, Vector3(0.025, 0.009, 0.012), Vector3(0, 1.79, -0.165), seam)
		_box(visual, Vector3(0.17, 0.25, 0.045), Vector3(-0.19, 1.01, -0.20), _material(Color("726c4d")))
	else:
		# Rounded cap dome and curved brim, without a cubic helmet silhouette.
		_mesh(visual, Art.ellipsoid(Vector3(0.37, 0.15, 0.35)), Vector3(0, 1.95, 0.015), seam)
		_box(visual, Vector3(0.34, 0.035, 0.20), Vector3(0, 1.93, -0.16), seam)
		_box(visual, Vector3(0.13, 0.17, 0.045), Vector3(0.19, 1.17, -0.19), _material(Color("2d3d42"), "plain"))


func _label(text: String, height: float, font_size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.013
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color("172a29")
	label.position.y = height
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 20.0
	label.visibility_range_end_margin = 3.0
	add_child(label)
	return label


func face_position(point: Vector3) -> void:
	if not is_instance_valid(visual):
		return
	var direction: Vector3 = point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		visual.rotation.y = atan2(-direction.x, -direction.z) - global_rotation.y


func mark_spoken(value: bool) -> void:
	spoken = value
	if is_instance_valid(conversation_marker):
		conversation_marker.text = "CONVERSAR" if spoken else "● CONVERSAR"
		conversation_marker.modulate = Color("b0c7b2") if spoken else Color("e7b974")


func set_active(value: bool) -> void:
	# Apenas a animação para: o corpo estático continua bloqueando passagem.
	set_process(value)


func _process(delta: float) -> void:
	_idle_clock += delta
	if is_instance_valid(visual):
		visual.position.y = sin(_idle_clock * 1.7) * 0.009
	if is_instance_valid(_left_arm):
		_left_arm.rotation.x = sin(_idle_clock * 1.25) * 0.035
		_right_arm.rotation.x = -sin(_idle_clock * 1.25 + 0.4) * 0.035
