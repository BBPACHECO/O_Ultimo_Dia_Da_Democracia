extends CharacterBody3D
## Guarda humano com percepção, perseguição, ataque anunciado e defesa interrompível.
signal struck_player(damage: float)
signal defeated(guard: Node3D)

const MAX_HEALTH: float = 60.0
const ATTACK_DAMAGE: float = 12.0
const WINDUP_TIME: float = 0.55
const ATTACK_COOLDOWN: float = 1.3
const DETECT_DISTANCE: float = 11.0
const ATTACK_RANGE: float = 1.9

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
	visual.name = "GuardHuman"
	add_child(visual)
	var uniform: Material = _material(Color("3f4841"))
	var dark: Material = _material(Color("222c29"))
	var boots: Material = _material(Color("1b2220"))
	var skin: Material = _material(Color("ae866b") if absi(guard_id.hash()) % 2 == 0 else Color("8e684f"))
	var badge: Material = _material(Color("b8a47a"))
	_box(visual, Vector3(0.56, 0.64, 0.34), Vector3(0, 1.12, 0), uniform)
	_box(visual, Vector3(0.58, 0.12, 0.37), Vector3(0, 0.84, 0), dark)
	_box(visual, Vector3(0.13, 0.13, 0.025), Vector3(-0.15, 1.27, -0.185), badge)
	_box(visual, Vector3(0.09, 0.26, 0.045), Vector3(0.16, 1.22, -0.2), dark)
	_box(visual, Vector3(0.13, 0.16, 0.14), Vector3(0, 1.49, 0), skin)
	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.34
	head_mesh.radial_segments = 12
	head_mesh.rings = 6
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0, 1.69, 0)
	visual.add_child(head)
	_box(visual, Vector3(0.37, 0.12, 0.35), Vector3(0, 1.84, 0), dark)
	_box(visual, Vector3(0.35, 0.045, 0.19), Vector3(0, 1.79, -0.22), dark)
	_box(visual, Vector3(0.04, 0.025, 0.025), Vector3(-0.065, 1.71, -0.173), dark)
	_box(visual, Vector3(0.04, 0.025, 0.025), Vector3(0.065, 1.71, -0.173), dark)
	_left_leg = _limb(Vector3(-0.16, 0.80, 0), 0.68, 0.18, uniform)
	_right_leg = _limb(Vector3(0.16, 0.80, 0), 0.68, 0.18, uniform)
	_box(_left_leg, Vector3(0.20, 0.14, 0.33), Vector3(0, -0.68, -0.06), boots)
	_box(_right_leg, Vector3(0.20, 0.14, 0.33), Vector3(0, -0.68, -0.06), boots)
	_left_arm = _limb(Vector3(-0.35, 1.39, 0), 0.57, 0.15, uniform)
	_right_arm = _limb(Vector3(0.35, 1.39, 0), 0.57, 0.15, uniform)
	_box(_left_arm, Vector3(0.14, 0.17, 0.13), Vector3(0, -0.60, 0), skin)
	_box(_right_arm, Vector3(0.14, 0.17, 0.13), Vector3(0, -0.60, 0), skin)
	_box(_right_arm, Vector3(0.045, 0.46, 0.045), Vector3(0, -0.82, 0), boots)
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
	_status_label.font_size = 23
	_status_label.pixel_size = 0.009
	_status_label.outline_size = 5
	_status_label.outline_modulate = Color("172822")
	add_child(_status_label)


func _update_visual(delta: float) -> void:
	if not is_instance_valid(visual) or _status_label == null:
		return
	if defeated_flag:
		_status_label.text = "FORA DE COMBATE"
		_status_label.modulate = Color("a4aa99")
		_ring.visible = false
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	_walk_cycle += delta * (10.0 if state == "chase" else 7.0)
	var swing: float = sin(_walk_cycle) * minf(speed / 4.0, 0.55)
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.6
	_right_arm.rotation.x = swing * 0.6
	var color: Color = Color("bdad7d")
	var caption: String = "PATRULHA"
	if state == "windup":
		color = Color("ed765b")
		caption = "AFASTE-SE!"
		_right_arm.rotation.x = -1.7 + (WINDUP_TIME - windup_remaining) * 1.2
	elif state == "chase":
		color = Color("e4a46b")
		caption = "EM PERSEGUIÇÃO"
	elif state == "search":
		caption = "PROCURANDO"
	elif state == "stunned":
		color = Color("f1d595")
		caption = "ATORDOADO"
	_status_label.text = "%s · %d" % [caption, ceili(health)]
	_status_label.modulate = color
	_ring_material.albedo_color = color
	_ring.scale = Vector3.ONE * (1.35 if state == "windup" else 1.0)
