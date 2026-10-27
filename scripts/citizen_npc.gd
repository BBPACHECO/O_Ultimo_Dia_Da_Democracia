extends Node3D
## Cidadão original. As conversas e a pausa da missão são coordenadas pelo jogo.

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


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _capsule(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 3
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _limb(parent: Node3D, at: Vector3, length: float, radius: float, material: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	_capsule(pivot, radius, length, Vector3(0, -length * 0.5, 0), material)
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
		jacket_color = Color("b1a68b")
		trousers_color = Color("555e4e")
		skin_color = Color("c2977b")
		hair_color = Color("ada99c")
	elif npc_id == "tomas":
		jacket_color = Color("47647a")
		trousers_color = Color("4e5350")
		skin_color = Color("956d52")
		hair_color = Color("282b2a")
	var jacket: StandardMaterial3D = _material(jacket_color)
	var trousers: StandardMaterial3D = _material(trousers_color)
	var skin: StandardMaterial3D = _material(skin_color)
	var hair: StandardMaterial3D = _material(hair_color)
	var shoes: StandardMaterial3D = _material(Color("292c2b"))
	var seam: StandardMaterial3D = _material(jacket_color.darkened(0.25))
	# Tronco arredondado e membros articulados mantêm a silhueta humana em três quartos.
	_capsule(visual, 0.28, 0.79, Vector3(0, 1.13, 0), jacket)
	_box(visual, Vector3(0.49, 0.20, 0.32), Vector3(0, 0.85, 0), jacket)
	_box(visual, Vector3(0.025, 0.52, 0.02), Vector3(0, 1.14, -0.272), seam)
	_capsule(visual, 0.09, 0.18, Vector3(0, 1.55, 0), skin)
	_capsule(visual, 0.20, 0.40, Vector3(0, 1.79, 0), skin)
	_box(visual, Vector3(0.35, 0.10, 0.32), Vector3(0, 1.96, 0.025), hair)
	_box(visual, Vector3(0.34, 0.17, 0.10), Vector3(0, 1.86, 0.14), hair)
	for side: float in [-1.0, 1.0]:
		_box(visual, Vector3(0.032, 0.025, 0.015), Vector3(side * 0.074, 1.82, -0.192), hair)
		var leg: Node3D = _limb(visual, Vector3(side * 0.145, 0.77, 0), 0.65, 0.10, trousers)
		_box(leg, Vector3(0.21, 0.13, 0.31), Vector3(0, -0.65, -0.045), shoes)
	_left_arm = _limb(visual, Vector3(-0.34, 1.43, 0), 0.54, 0.093, jacket)
	_right_arm = _limb(visual, Vector3(0.34, 1.43, 0), 0.54, 0.093, jacket)
	_capsule(_left_arm, 0.077, 0.15, Vector3(0, -0.58, 0), skin)
	_capsule(_right_arm, 0.077, 0.15, Vector3(0, -0.58, 0), skin)
	if npc_id == "lia":
		_box(visual, Vector3(0.19, 0.28, 0.06), Vector3(0.19, 1.05, -0.30), _material(Color("d7ccb0")))
	elif npc_id == "ines":
		for side: float in [-1.0, 1.0]:
			_box(visual, Vector3(0.12, 0.07, 0.02), Vector3(side * 0.073, 1.82, -0.203), seam)
		_box(visual, Vector3(0.18, 0.27, 0.055), Vector3(-0.20, 1.03, -0.28), _material(Color("726c4d")))
	else:
		_box(visual, Vector3(0.39, 0.08, 0.34), Vector3(0, 2.01, 0.015), seam)
		_box(visual, Vector3(0.38, 0.035, 0.17), Vector3(0, 1.98, -0.20), seam)
		_box(visual, Vector3(0.15, 0.18, 0.06), Vector3(0.20, 1.19, -0.27), _material(Color("2d3d42")))


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
