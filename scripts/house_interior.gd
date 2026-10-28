extends Node3D
## Casas de Aurora: portas abertas, móveis físicos e corte visual do telhado.
const Art = preload("res://scripts/art_geometry.gd")

var house_id: String = ""
var dimensions: Vector2 = Vector2(10, 9)
var entrance_side: float = 1.0
var cutaway_active: bool = false
var _cutaway_meshes: Array[MeshInstance3D] = []
var _materials: Dictionary = {}


func configure(id: String, footprint: Vector2, side: float) -> void:
	house_id = id
	dimensions = footprint
	entrance_side = side
	name = id
	_build()


func _material(key: String, color: Color, kind: String = "plain") -> StandardMaterial3D:
	if not _materials.has(key):
		_materials[key] = Art.surface(color, kind)
	return _materials[key] as StandardMaterial3D


func _box(at: Vector3, size: Vector3, material: Material, solid: bool = false, cutaway: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = Art.rounded_box(size, minf(0.075, minf(size.x, minf(size.y, size.z)) * 0.18))
	instance.position = at
	instance.material_override = material
	add_child(instance)
	if cutaway:
		_cutaway_meshes.append(instance)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return instance


func _wall(at: Vector3, length: float, along_x: bool, color: Material) -> void:
	var lower_size := Vector3(length, 0.65, 0.22) if along_x else Vector3(0.22, 0.65, length)
	var upper_size := Vector3(length, 2.35, 0.22) if along_x else Vector3(0.22, 2.35, length)
	_box(at + Vector3(0, 0.325, 0), lower_size, color, true)
	_box(at + Vector3(0, 1.825, 0), upper_size, color, true, true)
	var trim_size := Vector3(length, 0.09, 0.25) if along_x else Vector3(0.25, 0.09, length)
	_box(at + Vector3(0, 0.075, 0), trim_size, _material("skirting", Color("74664f"), "wood"))


func _build() -> void:
	var half_x: float = dimensions.x * 0.5
	var half_z: float = dimensions.y * 0.5
	var wall := _material("plaster", Color("b6b090") if entrance_side > 0 else Color("ad9b7d"), "plaster")
	var wood := _material("wood", Color("8e7453"), "wood")
	var dark_wood := _material("dark_wood", Color("5f5945"), "wood")
	var white := _material("ceramic", Color("c7c3ac"), "stone")
	var metal := _material("metal", Color("4d5c53"), "metal")
	# O piso é apenas visual: fica nivelado com o chão, sem degrau na porta.
	_box(Vector3(0, 0.018, 0), Vector3(dimensions.x, 0.032, dimensions.y), _material("floor", Color("9c8d6d"), "wood"))
	_box(Vector3(0, 0.038, -1.5), Vector3(3.8, 0.025, 3.3), _material("rug", Color("777f69"), "cloth"))
	_wall(Vector3(0, 0, -half_z), dimensions.x, true, wall)
	_wall(Vector3(0, 0, half_z), dimensions.x, true, wall)
	_wall(Vector3(-entrance_side * half_x, 0, 0), dimensions.y, false, wall)
	# Duas paredes laterais deixam uma porta de 2,2 m. A bandeira fica acima da cabeça.
	var side_length: float = (dimensions.y - 2.2) * 0.5
	for direction: float in [-1.0, 1.0]:
		_wall(Vector3(entrance_side * half_x, 0, direction * (1.1 + side_length * 0.5)), side_length, false, wall)
	_box(Vector3(entrance_side * half_x, 2.65, 0), Vector3(0.22, 0.7, 2.2), wall, true, true)
	for direction: float in [-1.0, 1.0]:
		_box(Vector3(entrance_side * half_x, 1.15, direction * 1.16), Vector3(0.30, 2.3, 0.12), wood, false, true)
	_box(Vector3(entrance_side * half_x, 2.31, 0), Vector3(0.30, 0.12, 2.44), wood, false, true)
	# Porta caída encostada do lado de fora, deixando a passagem completamente livre.
	var door := _box(Vector3(entrance_side * (half_x + 0.23), 1.04, -2.55), Vector3(0.10, 2.0, 0.88), wood, false, true)
	door.rotation.z = entrance_side * 0.07
	_box(Vector3(entrance_side * (half_x + 0.30), 1.0, -2.3), Vector3(0.07, 0.08, 0.12), metal, false, true)
	# Quarto e sala/cozinha são separados por uma parede com passagem larga no meio.
	var partition_z: float = 0.65
	_wall(Vector3((-half_x - 0.8) * 0.5, 0, partition_z), half_x - 0.8, true, wall)
	_wall(Vector3((1.4 + half_x) * 0.5, 0, partition_z), half_x - 1.4, true, wall)
	_box(Vector3(0.3, 2.65, partition_z), Vector3(2.2, 0.7, 0.22), wall, true, true)
	# Cozinha: bancada, pia, fogão e geladeira, sempre fora do acesso principal.
	_box(Vector3(0, 0.45, -half_z + 0.65), Vector3(2.9, 0.9, 0.9), wood, true)
	_box(Vector3(0, 0.95, -half_z + 0.65), Vector3(3.05, 0.12, 1.0), white)
	_box(Vector3(-0.65, 1.017, -half_z + 0.65), Vector3(0.80, 0.025, 0.60), metal)
	_box(Vector3(-0.65, 1.028, -half_z + 0.65), Vector3(0.62, 0.025, 0.43), _material("sink", Color("909e95"), "metal"))
	_box(Vector3(-0.65, 1.13, -half_z + 0.92), Vector3(0.08, 0.25, 0.08), metal)
	for x: float in [-1.0, 0.0, 1.0]:
		_box(Vector3(x, 0.53, -half_z + 1.12), Vector3(0.78, 0.58, 0.035), dark_wood)
		_box(Vector3(x, 0.64, -half_z + 1.15), Vector3(0.24, 0.055, 0.06), metal)
	_box(Vector3(-2.45, 0.48, -half_z + 0.67), Vector3(1.0, 0.96, 0.95), white, true)
	for x: float in [-2.69, -2.22]:
		for z: float in [-0.23, 0.23]:
			_box(Vector3(x, 0.975, -half_z + 0.67 + z), Vector3(0.28, 0.025, 0.28), metal)
	_box(Vector3(-half_x + 0.75, 1.00, -half_z + 0.70), Vector3(1.0, 2.0, 1.0), white, true)
	_box(Vector3(-half_x + 1.27, 1.20, -half_z + 0.70), Vector3(0.05, 0.60, 0.065), metal)
	# Sofá pequeno e mesa deixam o centro livre para atravessar a casa.
	_box(Vector3(half_x - 1.55, 0.38, -2.6), Vector3(1.9, 0.65, 0.9), _material("sofa", Color("697c71"), "cloth"), true)
	_box(Vector3(half_x - 1.55, 0.85, -2.93), Vector3(1.9, 0.72, 0.22), _materials["sofa"])
	for x: float in [half_x - 2.45, half_x - 0.65]:
		_box(Vector3(x, 0.65, -2.60), Vector3(0.18, 0.50, 0.9), _materials["sofa"])
	_box(Vector3(half_x - 1.5, 0.34, -1.30), Vector3(1.6, 0.12, 0.7), wood, true)
	for x: float in [half_x - 2.05, half_x - 0.95]:
		_box(Vector3(x, 0.16, -1.3), Vector3(0.09, 0.32, 0.5), dark_wood)
	# Cama, travesseiro e mesinha se alternam entre as duas casas.
	var bed_side: float = -1.0 if entrance_side > 0 else 1.0
	var bed_x: float = bed_side * (half_x - 0.9)
	_box(Vector3(bed_x, 0.25, half_z - 1.7), Vector3(1.35, 0.50, 2.5), dark_wood, true)
	_box(Vector3(bed_x, 0.56, half_z - 1.7), Vector3(1.32, 0.22, 2.45), _material("linen", Color("b3ad93"), "cloth"))
	_box(Vector3(bed_x, 0.70, half_z - 2.1), Vector3(1.34, 0.14, 1.58), _material("blanket", Color("6e7c7a"), "cloth"))
	_box(Vector3(bed_x, 0.74, half_z - 0.85), Vector3(1.05, 0.22, 0.48), _material("pillow", Color("d4cdb5"), "cloth"))
	_box(Vector3(bed_x - bed_side * 1.40, 0.35, half_z - 1.0), Vector3(0.65, 0.7, 0.65), wood, true)
	# Estante baixa, relógio e livros dão uso ao cômodo sem bloquear o loot.
	var shelf_x: float = -bed_side * 2.0
	_box(Vector3(shelf_x, 0.70, half_z - 0.5), Vector3(2.2, 1.4, 0.5), dark_wood, true)
	for shelf_y: float in [0.2, 0.7, 1.2]:
		_box(Vector3(shelf_x, shelf_y, half_z - 0.22), Vector3(2.18, 0.07, 0.06), wood)
	for index in range(6):
		_box(Vector3(shelf_x - 0.75 + index * 0.29, 0.95, half_z - 0.2), Vector3(0.16, 0.35, 0.1), _material("book_%s" % (index % 3), [Color("7d8b73"), Color("987658"), Color("b3a77a")][index % 3]))
	# As águas do telhado, chaminé e beirais desaparecem juntos no corte.
	var roof := _material("roof", Color("675b4a"), "stone")
	for side: float in [-1.0, 1.0]:
		var panel := _box(Vector3(side * dimensions.x * 0.25, 3.50, 0), Vector3(dimensions.x * 0.55, 0.18, dimensions.y + 0.7), roof, false, true)
		panel.rotation.z = -side * 0.20
	_box(Vector3(0, 3.5 + dimensions.x * 0.25 * tan(0.20), 0), Vector3(0.18, 0.15, dimensions.y + 0.72), roof, false, true)
	_box(Vector3(-half_x + 1.15, 3.75, -half_z + 1.1), Vector3(0.65, 1.15, 0.7), wall, false, true)
	# Janelas de vidro opaco e venezianas são decorativas; somem no corte para não flutuar.
	for z: float in [-half_z, half_z]:
		for x: float in [-dimensions.x * 0.26, dimensions.x * 0.26]:
			_box(Vector3(x, 1.65, z + signf(z) * 0.13), Vector3(1.35, 1.18, 0.08), wood, false, true)
			_box(Vector3(x, 1.65, z + signf(z) * 0.18), Vector3(1.16, 0.99, 0.04), _material("glass", Color("71867c"), "metal"), false, true)
			_box(Vector3(x, 1.65, z + signf(z) * 0.21), Vector3(0.055, 1.0, 0.035), wood, false, true)
	var label := Label3D.new()
	label.text = "CASA 12 · PORTA ABERTA" if entrance_side > 0 else "CASA 18 · PORTA ABERTA"
	label.font_size = 24
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = Color("ddd3aa")
	label.position = Vector3(entrance_side * (half_x + 0.4), 3.2, 0)
	add_child(label)
	_merge_surfaces()


func _merge_surfaces() -> void:
	# Móveis e paredes compartilham superfícies por material. As colisões são
	# irmãos independentes e continuam intactas quando o telhado é ocultado.
	var groups: Dictionary = {}
	var originals: Array[MeshInstance3D] = []
	for child: Node in get_children():
		if not child is MeshInstance3D:
			continue
		var instance := child as MeshInstance3D
		var cut: bool = instance in _cutaway_meshes
		var key: String = "%s_%s" % [instance.material_override.get_instance_id(), cut]
		if not groups.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"tool": surface, "material": instance.material_override, "cut": cut}
		for index in range(instance.mesh.get_surface_count()):
			groups[key]["tool"].append_from(instance.mesh, index, instance.transform)
		originals.append(instance)
	_cutaway_meshes.clear()
	for key: String in groups:
		var group: Dictionary = groups[key]
		var surface: SurfaceTool = group["tool"]
		surface.index()
		var merged := MeshInstance3D.new()
		merged.name = "Corte_" + key if group["cut"] else "Interior_" + key
		merged.mesh = surface.commit()
		merged.material_override = group["material"]
		add_child(merged)
		if group["cut"]:
			_cutaway_meshes.append(merged)
	for instance: MeshInstance3D in originals:
		instance.free()


func set_viewer_position(viewer: Vector3) -> void:
	var local: Vector3 = to_local(viewer)
	var inside: bool = absf(local.x) <= dimensions.x * 0.5 + 0.8 and absf(local.z) <= dimensions.y * 0.5 + 0.8
	var door: Vector3 = Vector3(entrance_side * dimensions.x * 0.5, 0, 0)
	var near_door: bool = Vector2(local.x - door.x, local.z).length() < 3.0
	var should_cut: bool = inside or near_door
	if should_cut == cutaway_active:
		return
	cutaway_active = should_cut
	for mesh: MeshInstance3D in _cutaway_meshes:
		mesh.visible = not cutaway_active
