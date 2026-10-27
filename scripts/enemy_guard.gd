extends CharacterBody3D
## Zumbi de camisa verde e amarela. Os IDs antigos preservam os saves anteriores.
signal struck_player(damage: float)
signal defeated(guard: Node3D)

const MAX_HEALTH: float = 60.0
const ATTACK_DAMAGE: float = 12.0
const WINDUP_TIME: float = 0.55
const ATTACK_COOLDOWN: float = 1.3
const DETECT_DISTANCE: float = 11.0
const ATTACK_RANGE: float = 1.9
const SHIRT_GREEN: Color = Color("2f8f3b")
const SHIRT_YELLOW: Color = Color("e6c82d")

var target: CharacterBody3D
var guard_id: String = "vigia"
var patrol_route: Array[Vector3] = []
var health: float = MAX_HEALTH
var state: String = "patrol"
var defeated_flag: bool = false
var attack_count: int = 0
var attacks_started: int = 0
var windup_remaining: float = 0.0
var visual: Node3D
var active: bool = false:
	set(value):
		active = value and not defeated_flag
		if not active:
			windup_remaining = 0.0
			_cooldown = maxf(_cooldown, 0.65)
			velocity = Vector3.ZERO
			if not defeated_flag:
				state = "patrol"
		set_physics_process(active)

var _shape: CollisionShape3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _head: Node3D
var _status_label: Label3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _patrol_index: int = 0
var _memory: float = 0.0
var _last_seen: Vector3 = Vector3.ZERO
var _stun: float = 0.0
var _cooldown: float = 0.65
var _walk_cycle: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _avoid_side: float = 1.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	floor_snap_length = 0.4
	_avoid_side = 1.0 if absi(guard_id.hash()) % 2 == 0 else -1.0
	_shape = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.9
	capsule.radius = 0.30
	_shape.shape = capsule
	_shape.position.y = 0.95
	add_child(_shape)
	_build_visual()
	if patrol_route.is_empty():
		patrol_route.append(global_position)
	_last_seen = global_position
	if defeated_flag:
		_collapse(false)
	else:
		set_physics_process(active)
	_update_visual(0.0)


func set_active(value: bool) -> void:
	active = value


func _physics_process(delta: float) -> void:
	if not active or defeated_flag or delta <= 0.0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_stun = maxf(0.0, _stun - delta)
	var desired: Vector3 = Vector3.ZERO
	var speed: float = 2.0
	if not is_instance_valid(target):
		state = "patrol"
	elif _stun > 0.0:
		state = "stunned"
	elif windup_remaining > 0.0:
		state = "windup"
		_face(target.global_position - global_position, delta)
		windup_remaining = maxf(0.0, windup_remaining - delta)
		if windup_remaining <= 0.0:
			_cooldown = ATTACK_COOLDOWN
			if _target_in_reach() and _line_clear(global_position + Vector3.UP * 1.3, target.global_position + Vector3.UP * 1.1):
				attack_count += 1
				struck_player.emit(ATTACK_DAMAGE)
			state = "chase"
	else:
		var visible_target: bool = _can_detect_target()
		if visible_target:
			_last_seen = target.global_position
			_memory = 5.0
		else:
			_memory = maxf(0.0, _memory - delta)
		if _memory > 0.0:
			state = "chase" if visible_target else "search"
			speed = 3.3
			if visible_target and _target_in_reach() and _cooldown <= 0.0:
				windup_remaining = WINDUP_TIME
				attacks_started += 1
				state = "windup"
			elif _flat_distance(global_position, _last_seen) > 0.65:
				desired = _last_seen - global_position
		else:
			state = "patrol"
			var destination: Vector3 = patrol_route[_patrol_index]
			if _flat_distance(global_position, destination) < 0.65:
				_patrol_index = (_patrol_index + 1) % patrol_route.size()
				destination = patrol_route[_patrol_index]
			desired = destination - global_position
	if desired.length_squared() > 0.01 and _stun <= 0.0 and windup_remaining <= 0.0:
		desired.y = 0.0
		desired = _steer(desired.normalized())
		_face(desired, delta)
	else:
		desired = Vector3.ZERO
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 12.0)
	velocity.x = desired.x * speed + _knockback.x
	velocity.z = desired.z * speed + _knockback.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -39.0, 39.0)
	global_position.z = clampf(global_position.z, -39.0, 39.0)
	if global_position.y < -6.0:
		global_position = patrol_route[0] + Vector3.UP * 0.1
		velocity = Vector3.ZERO
	_update_visual(delta)


func _can_detect_target() -> bool:
	if not is_instance_valid(target):
		return false
	var delta: Vector3 = target.global_position - global_position
	delta.y = 0.0
	var distance: float = delta.length()
	if distance > DETECT_DISTANCE:
		return false
	var forward: Vector3 = -visual.global_transform.basis.z
	forward.y = 0.0
	var facing: bool = distance < 2.2 or forward.normalized().dot(delta.normalized()) >= cos(deg_to_rad(100.0))
	var heard: bool = distance < 5.0 and Vector2(target.velocity.x, target.velocity.z).length() > 6.0
	return (facing or heard) and _line_clear(global_position + Vector3.UP * 1.4, target.global_position + Vector3.UP * 1.1)


func _target_in_reach() -> bool:
	return is_instance_valid(target) and _flat_distance(global_position, target.global_position) <= ATTACK_RANGE and absf(global_position.y - target.global_position.y) < 1.4


func _line_clear(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _blocked(direction: Vector3, reach: float) -> bool:
	for height: float in [0.4, 1.2]:
		var start: Vector3 = global_position + Vector3.UP * height
		if not _line_clear(start, start + direction * reach):
			return true
	return false


func _steer(direction: Vector3) -> Vector3:
	if not _blocked(direction, 1.5):
		return direction
	# Raios baixos e altos contornam bancos, muros e esquinas sem navmesh externo.
	for degrees: float in [45.0, 80.0, 115.0]:
		for side: float in [_avoid_side, -_avoid_side]:
			var candidate: Vector3 = direction.rotated(Vector3.UP, deg_to_rad(degrees) * side)
			if not _blocked(candidate, 1.9):
				_avoid_side = side
				return candidate
	return Vector3.ZERO


func _face(direction: Vector3, delta: float) -> void:
	if direction.x * direction.x + direction.z * direction.z > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))


func take_hit(damage: float, from_position: Vector3) -> bool:
	if not active or defeated_flag or not is_finite(damage) or damage <= 0.0 or not from_position.is_finite():
		return false
	if _flat_distance(global_position, from_position) > 3.1:
		return false
	if not _line_clear(from_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.0):
		return false
	health = maxf(0.0, health - damage)
	windup_remaining = 0.0
	_stun = 0.4
	_cooldown = maxf(_cooldown, 0.8)
	var away: Vector3 = global_position - from_position
	away.y = 0.0
	_knockback = away.normalized() * 3.4 if away.length_squared() > 0.01 else visual.global_transform.basis.z * 3.4
	if health <= 0.0:
		_collapse(true)
	else:
		state = "stunned"
		_update_visual(0.0)
	return true


func restore_defeated() -> void:
	_collapse(false)


func _collapse(emit_event: bool) -> void:
	var was_defeated: bool = defeated_flag
	defeated_flag = true
	health = 0.0
	state = "defeated"
	active = false
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if is_instance_valid(_shape):
		_shape.set_deferred("disabled", true)
	if is_instance_valid(visual):
		visual.rotation.z = PI * 0.48
		visual.position.y = 0.22
		_update_visual(0.0)
	if emit_event and not was_defeated:
		defeated.emit(self)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
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


func _limb(at: Vector3, length: float, width: float, material: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = at
	visual.add_child(pivot)
	_box(pivot, Vector3(width, length, width), Vector3(0, -length * 0.5, 0), material)
	return pivot


func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Zombie"
	add_child(visual)
	var green: Material = _material(SHIRT_GREEN)
	var yellow: Material = _material(SHIRT_YELLOW)
	var green_faded: Material = _material(Color("507c3f"))
	var trousers: Material = _material(Color("343b39"))
	var shoes: Material = _material(Color("252b29"))
	var skin: Material = _material(Color("90a48a") if absi(guard_id.hash()) % 2 == 0 else Color("a1a68b"))
	var skin_shadow: Material = _material(Color("60715e"))
	var hair: Material = _material(Color("393c32"))
	var eye: Material = _material(Color("dbd29b"))
	# As faixas envolvem a camisa: verde e amarelo continuam legíveis pelas costas.
	var shirt: MeshInstance3D = _box(visual, Vector3(0.57, 0.64, 0.35), Vector3(0, 1.12, 0), green)
	shirt.name = "ShirtGreen"
	var stripe: MeshInstance3D = _box(visual, Vector3(0.585, 0.20, 0.367), Vector3(0, 1.15, 0), yellow)
	stripe.name = "ShirtYellowBand"
	var shoulder: MeshInstance3D = _box(visual, Vector3(0.59, 0.075, 0.37), Vector3(0, 1.40, 0), yellow)
	shoulder.name = "ShirtYellowShoulder"
	# Bainha irregular, manchas e rasgos são geométricos, sem sangue ou emblemas.
	for index in range(4):
		var x: float = -0.23 + float(index) * 0.15
		var drop: float = 0.08 if (index + absi(guard_id.hash())) % 2 == 0 else 0.03
		var hem: MeshInstance3D = _box(visual, Vector3(0.13, 0.09 + drop, 0.35), Vector3(x, 0.81 - drop * 0.35, 0), green)
		hem.rotation.z = -0.08 if index % 2 == 0 else 0.06
	_box(visual, Vector3(0.12, 0.11, 0.015), Vector3(-0.12, 0.96, -0.182), green_faded)
	_box(visual, Vector3(0.15, 0.10, 0.016), Vector3(0.14, 1.30, 0.183), green_faded)
	_box(visual, Vector3(0.08, 0.10, 0.018), Vector3(0.17, 0.91, 0.185), skin_shadow)
	_box(visual, Vector3(0.13, 0.16, 0.14), Vector3(0, 1.49, 0), skin)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.55, -0.045)
	_head.rotation = Vector3(0.16, 0, -0.15)
	visual.add_child(_head)
	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.37
	head_mesh.radial_segments = 12
	head_mesh.rings = 6
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0, 0.15, 0)
	_head.add_child(head)
	_box(_head, Vector3(0.25, 0.07, 0.30), Vector3(-0.025, 0.31, 0.025), hair)
	_box(_head, Vector3(0.10, 0.08, 0.11), Vector3(0.10, 0.30, 0.065), hair)
	for side in [-1.0, 1.0]:
		_box(_head, Vector3(0.075, 0.07, 0.025), Vector3(side * 0.068, 0.17, -0.177), skin_shadow)
		_box(_head, Vector3(0.025, 0.032, 0.016), Vector3(side * 0.068, 0.17, -0.194), eye)
	_box(_head, Vector3(0.11, 0.045, 0.02), Vector3(0, 0.065, -0.18), skin_shadow)
	_left_leg = _limb(Vector3(-0.16, 0.80, 0), 0.68, 0.18, trousers)
	_right_leg = _limb(Vector3(0.16, 0.80, 0), 0.68, 0.18, trousers)
	_box(_left_leg, Vector3(0.19, 0.13, 0.018), Vector3(0, -0.34, -0.098), skin_shadow)
	_box(_left_leg, Vector3(0.20, 0.13, 0.32), Vector3(0, -0.68, -0.06), shoes)
	_box(_right_leg, Vector3(0.20, 0.13, 0.30), Vector3(0, -0.68, -0.05), shoes)
	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.35, 1.39, 0)
	visual.add_child(_left_arm)
	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.35, 1.39, 0)
	visual.add_child(_right_arm)
	_box(_left_arm, Vector3(0.18, 0.24, 0.20), Vector3(0, -0.12, 0), yellow)
	_box(_right_arm, Vector3(0.18, 0.23, 0.20), Vector3(0, -0.115, 0), green)
	_box(_right_arm, Vector3(0.19, 0.07, 0.21), Vector3(0, -0.19, 0), yellow)
	_box(_left_arm, Vector3(0.15, 0.39, 0.15), Vector3(0, -0.42, 0), skin)
	_box(_right_arm, Vector3(0.15, 0.39, 0.15), Vector3(0, -0.42, 0), skin)
	for arm: Node3D in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.16, 0.17, 0.12), Vector3(0, -0.67, -0.025), skin)
		for finger in range(3):
			_box(arm, Vector3(0.025, 0.11, 0.03), Vector3(-0.05 + finger * 0.05, -0.79, -0.035), skin_shadow)
	_ring = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.43
	ring_mesh.outer_radius = 0.49
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	_ring.mesh = ring_mesh
	_ring.position.y = 0.07
	_ring_material = _material(Color("bb935d"))
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_material
	add_child(_ring)
	_status_label = Label3D.new()
	_status_label.position.y = 2.25
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.font_size = 25
	_status_label.pixel_size = 0.010
	_status_label.outline_size = 5
	_status_label.outline_modulate = Color("172822")
	add_child(_status_label)


func _update_visual(delta: float) -> void:
	if not is_instance_valid(visual) or _status_label == null:
		return
	if defeated_flag:
		_status_label.text = "IMOBILIZADO"
		_status_label.modulate = Color("a4aa99")
		_ring.visible = false
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	_walk_cycle += delta * (7.0 if state == "chase" else 4.2)
	var swing: float = sin(_walk_cycle) * minf(speed / 5.0, 0.38)
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -sin(_walk_cycle + 0.4) * minf(speed / 5.0, 0.30)
	visual.rotation.x = -0.10 - absf(sin(_walk_cycle * 0.5)) * 0.035
	visual.rotation.z = sin(_walk_cycle * 0.65) * 0.035
	visual.position.y = absf(sin(_walk_cycle)) * 0.018
	_head.rotation.z = -0.15 + sin(_walk_cycle * 0.8) * 0.045
	var reach: float = 1.15 if state in ["chase", "windup"] else 0.52
	_left_arm.rotation.x = reach + swing * 0.3
	_right_arm.rotation.x = reach - swing * 0.25
	_left_arm.rotation.z = -0.12
	_right_arm.rotation.z = 0.16
	var color: Color = Color("bdad7d")
	var caption: String = "ZUMBI"
	if state == "windup":
		color = Color("ed765b")
		caption = "VAI ATACAR!"
		_right_arm.rotation.x = 0.35 + (WINDUP_TIME - windup_remaining) * 2.5
		_left_arm.rotation.x = 1.45
	elif state == "chase":
		color = Color("e4a46b")
		caption = "PERSEGUINDO"
	elif state == "search":
		caption = "VAGANDO"
	elif state == "stunned":
		color = Color("f1d595")
		caption = "ATORDOADO"
		_left_arm.rotation.x = 0.25
		_right_arm.rotation.x = 0.40
	_status_label.text = "%s · %d" % [caption, ceili(health)]
	_status_label.modulate = color
	_ring_material.albedo_color = color
	_ring.scale = Vector3.ONE * (1.35 if state == "windup" else 1.0)
