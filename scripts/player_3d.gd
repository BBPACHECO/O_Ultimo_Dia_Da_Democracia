extends CharacterBody3D
## Personagem e câmera em terceira pessoa, renderizados pelo engine nativo.

const Art = preload("res://scripts/art_geometry.gd")

const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const ACCELERATION: float = 22.0
const LOOK_SENSITIVITY: float = 0.004

var touch_move: Vector2 = Vector2.ZERO
var touch_sprint: bool = false
var controls_enabled: bool = false
var camera: Camera3D
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var visual: Node3D
var camera_mode: String = "tactical"
var camera_yaw: float = -0.65
var camera_pitch: float = -0.88
var attack_animating: bool = false
var facing_direction: Vector3:
	get:
		return -visual.global_transform.basis.z.normalized() if is_instance_valid(visual) else Vector3.FORWARD

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _walk_phase: float = 0.0
var _spawn_position: Vector3 = Vector3.ZERO
var _gravity: float = 9.8
var _attack_time: float = 0.0
var _hurt_time: float = 0.0
var _character_materials: Array[StandardMaterial3D] = []
var _material_colors: Array[Color] = []
var _silhouette: Node3D
var _occlusion_check: float = 0.0


func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(48.0)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_spawn_position = global_position
	var shape = CollisionShape3D.new()
	shape.name = "BodyCollision"
	var capsule = CapsuleShape3D.new()
	capsule.height = 2.0
	capsule.radius = 0.32
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)
	_build_character()
	_build_camera()
	_build_silhouette()


func _material(color: Color, roughness: float = 0.88, kind: String = "cloth") -> StandardMaterial3D:
	var material: StandardMaterial3D = Art.surface(color, kind).duplicate() as StandardMaterial3D
	material.roughness = roughness
	_character_materials.append(material)
	_material_colors.append(color)
	return material


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var top: float = radius if top_radius < 0.0 else top_radius
	var rings: Array[Vector3] = [Vector3(radius, -height * 0.5, radius), Vector3(top, height * 0.5, top)]
	return _mesh(parent, Art.profile(rings, 16), at, material)


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	return _mesh(parent, Art.rounded_box(dimensions, minf(0.045, minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.24)), at, material)


func _sphere(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	return _mesh(parent, Art.ellipsoid(Vector3(radius * 2.0, height, radius * 2.0)), at, material)


func _limb(parent: Node3D, at: Vector3, length: float, width: float, material: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	# A discrete knee/elbow and tapered ankle/wrist replace the capsule silhouette.
	var rings: Array[Vector3] = [
		Vector3(width * 0.28, -length, width * 0.28),
		Vector3(width * 0.37, -length * 0.87, width * 0.36),
		Vector3(width * 0.46, -length * 0.58, width * 0.43),
		Vector3(width * 0.43, -length * 0.47, width * 0.40),
		Vector3(width * 0.57, -length * 0.20, width * 0.48),
		Vector3(width * 0.48, 0.0, width * 0.44),
	]
	_mesh(pivot, Art.profile(rings, 16), Vector3.ZERO, material)
	return pivot


func _build_character() -> void:
	visual = Node3D.new()
	visual.name = "Reporter"
	add_child(visual)
	var coat: Material = _material(Color("8f9076"), 0.90)
	var coat_shadow: Material = _material(Color("626a55"), 0.92)
	var trousers: Material = _material(Color("333d3c"), 0.93)
	var shoes: Material = _material(Color("252b29"), 0.82, "plain")
	var skin: Material = _material(Color("b58e70"), 0.72, "skin")
	var hair: Material = _material(Color("34332e"), 0.87, "plain")
	var bag: Material = _material(Color("776149"), 0.90)
	var strap: Material = _material(Color("3e3930"), 0.90)
	var paper: Material = _material(Color("d8d2b9"), 0.97, "plain")
	var torso: Array[Vector3] = [
		Vector3(0.27, 0.84, 0.185), Vector3(0.285, 0.94, 0.19),
		Vector3(0.24, 1.09, 0.165), Vector3(0.27, 1.28, 0.185),
		Vector3(0.32, 1.43, 0.17), Vector3(0.285, 1.51, 0.145),
		Vector3(0.12, 1.56, 0.105),
	]
	_mesh(visual, Art.profile(torso), Vector3.ZERO, coat)
	# Tailored lapels and cuff folds retain detail without a box-shaped chest.
	_box(visual, Vector3(0.018, 0.51, 0.013), Vector3(0, 1.15, -0.186), coat_shadow)
	for side: float in [-1.0, 1.0]:
		var lapel: MeshInstance3D = _box(visual, Vector3(0.10, 0.21, 0.022), Vector3(side * 0.083, 1.40, -0.169), coat_shadow)
		lapel.rotation.z = side * -0.23
		_box(visual, Vector3(0.115, 0.08, 0.025), Vector3(side * 0.15, 1.02, -0.183), coat_shadow)
	_mesh(visual, Art.capsule(0.075, 0.19), Vector3(0, 1.58, 0), skin)
	_mesh(visual, Art.ellipsoid(Vector3(0.335, 0.37, 0.32)), Vector3(0, 1.79, -0.005), skin)
	_mesh(visual, Art.ellipsoid(Vector3(0.348, 0.19, 0.33)), Vector3(0, 1.93, 0.018), hair)
	_mesh(visual, Art.ellipsoid(Vector3(0.30, 0.19, 0.11)), Vector3(0, 1.83, 0.13), hair)
	_mesh(visual, Art.ellipsoid(Vector3(0.052, 0.075, 0.063)), Vector3(0, 1.77, -0.17), skin)
	for side: float in [-1.0, 1.0]:
		_mesh(visual, Art.ellipsoid(Vector3(0.055, 0.085, 0.045)), Vector3(side * 0.167, 1.79, 0), skin)
		_box(visual, Vector3(0.031, 0.018, 0.015), Vector3(side * 0.061, 1.82, -0.157), hair)
	# Rounded padded backpack, piping and narrow shoulder straps.
	_box(visual, Vector3(0.40, 0.47, 0.22), Vector3(0, 1.22, 0.26), bag)
	_box(visual, Vector3(0.29, 0.17, 0.040), Vector3(0, 1.10, 0.379), coat_shadow)
	for side: float in [-1.0, 1.0]:
		_box(visual, Vector3(0.045, 0.61, 0.035), Vector3(side * 0.21, 1.25, 0.15), strap)
	_box(visual, Vector3(0.12, 0.17, 0.035), Vector3(0.18, 1.17, -0.19), paper)
	_left_leg = _limb(visual, Vector3(-0.14, 0.84, 0), 0.72, 0.20, trousers)
	_right_leg = _limb(visual, Vector3(0.14, 0.84, 0), 0.72, 0.20, trousers)
	for leg: Node3D in [_left_leg, _right_leg]:
		_mesh(leg, Art.ellipsoid(Vector3(0.19, 0.14, 0.32)), Vector3(0, -0.74, -0.055), shoes)
	_left_arm = _limb(visual, Vector3(-0.345, 1.43, 0), 0.56, 0.18, coat)
	_right_arm = _limb(visual, Vector3(0.345, 1.43, 0), 0.56, 0.18, coat)
	for arm: Node3D in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.14, 0.045, 0.14), Vector3(0, -0.51, 0), coat_shadow)
		_mesh(arm, Art.ellipsoid(Vector3(0.125, 0.175, 0.09)), Vector3(0, -0.61, -0.012), skin)


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.45, 0)
	add_child(camera_pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraSpringArm"
	spring_arm.spring_length = 6.0
	spring_arm.margin = 0.20
	spring_arm.collision_mask = 1
	var camera_shape = SphereShape3D.new()
	camera_shape.radius = 0.20
	spring_arm.shape = camera_shape
	camera_pivot.add_child(spring_arm)
	spring_arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.fov = 64.0
	camera.near = 0.08
	camera.far = 150.0
	camera.current = true
	spring_arm.add_child(camera)
	set_camera_mode(camera_mode)


func add_camera_look(delta: Vector2) -> void:
	if not controls_enabled or not delta.is_finite():
		return
	camera_yaw = wrapf(camera_yaw - delta.x * LOOK_SENSITIVITY, -PI, PI)
	var low: float = -1.15 if camera_mode == "tactical" else -0.82
	var high: float = -0.55 if camera_mode == "tactical" else -0.10
	camera_pitch = clampf(camera_pitch - delta.y * LOOK_SENSITIVITY, low, high)
	_update_camera()


func toggle_camera_mode() -> void:
	set_camera_mode("third_person" if camera_mode == "tactical" else "tactical")


func set_camera_mode(mode: String) -> void:
	if mode not in ["tactical", "third_person"]:
		return
	camera_mode = mode
	if camera == null or spring_arm == null:
		return
	if camera_mode == "tactical":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 18.0
		spring_arm.spring_length = 14.0
		spring_arm.collision_mask = 0
		camera_yaw = -0.65
		camera_pitch = -0.88
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 64.0
		spring_arm.spring_length = 6.0
		spring_arm.collision_mask = 1
		camera_yaw = 0.0
		camera_pitch = -0.28
	_update_camera()


func play_attack() -> void:
	if not controls_enabled:
		return
	_attack_time = 0.34
	attack_animating = true
	if _right_arm != null:
		_right_arm.rotation.x = -1.15


func play_hurt() -> void:
	_hurt_time = 0.25
	_update_hurt_color()


func _update_hurt_color() -> void:
	for index in range(_character_materials.size()):
		_character_materials[index].albedo_color = _material_colors[index].lerp(Color("e5a08c"), 0.72) if _hurt_time > 0.0 else _material_colors[index]


func _build_silhouette() -> void:
	# A small silhouette is visible only when a building hides the character.
	_silhouette = Node3D.new()
	_silhouette.name = "OccludedSilhouette"
	add_child(_silhouette)
	var ghost: StandardMaterial3D = StandardMaterial3D.new()
	ghost.albedo_color = Color(0.91, 0.77, 0.43, 0.55)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.no_depth_test = true
	ghost.render_priority = 12
	_sphere(_silhouette, 0.20, 0.40, Vector3(0, 1.83, 0), ghost)
	var body: MeshInstance3D = _cylinder(_silhouette, 0.30, 0.92, Vector3(0, 1.17, 0), ghost, 0.32)
	body.scale.z = 0.7
	for side in [-1.0, 1.0]:
		_cylinder(_silhouette, 0.10, 0.74, Vector3(side * 0.16, 0.43, 0), ghost)
		_cylinder(_silhouette, 0.095, 0.62, Vector3(side * 0.37, 1.16, 0), ghost)
	for child: Node in _silhouette.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_silhouette.visible = false


func _process(delta: float) -> void:
	_occlusion_check -= delta
	if _occlusion_check > 0.0 or camera == null or _silhouette == null:
		return
	_occlusion_check = 0.15
	_silhouette.rotation.y = visual.rotation.y
	if not controls_enabled:
		_silhouette.visible = false
		return
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, global_position + Vector3.UP * 1.2, 1)
	query.exclude = [get_rid()]
	_silhouette.visible = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_camera() -> void:
	if camera_pivot != null:
		camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)


func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		add_camera_look(event.relative)
		get_viewport().set_input_as_handled()


func reset_player(at: Vector3) -> void:
	_spawn_position = at
	global_position = at
	velocity = Vector3.ZERO
	touch_move = Vector2.ZERO
	touch_sprint = false
	set_camera_mode(camera_mode)
	_walk_phase = 0.0
	_attack_time = 0.0
	_hurt_time = 0.0
	attack_animating = false
	_update_hurt_color()
	if visual != null:
		visual.rotation = Vector3(0, camera_yaw, 0)
	_update_camera()
	_animate_character(0.0, false, 1.0)


func _physics_process(delta: float) -> void:
	_attack_time = maxf(0.0, _attack_time - delta)
	attack_animating = _attack_time > 0.0
	if _hurt_time > 0.0:
		_hurt_time = maxf(0.0, _hurt_time - delta)
		_update_hurt_color()
	var movement = Vector2.ZERO
	var running: bool = false
	if controls_enabled:
		movement = touch_move.limit_length(1.0) if touch_move.is_finite() else Vector2.ZERO
		var keyboard = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		)
		movement = (movement + keyboard).limit_length(1.0)
		running = touch_sprint or Input.is_physical_key_pressed(KEY_SHIFT)
		var orbit: float = float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_R))
		if orbit != 0.0:
			camera_yaw = wrapf(camera_yaw + orbit * delta * 1.8, -PI, PI)
			_update_camera()
	var direction = Basis(Vector3.UP, camera_yaw) * Vector3(movement.x, 0, movement.y)
	var speed: float = RUN_SPEED if running else WALK_SPEED
	if controls_enabled:
		velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -39.0, 39.0)
	global_position.z = clampf(global_position.z, -39.0, 39.0)
	if global_position.y < -8.0:
		reset_player(_spawn_position)
	if direction.length_squared() > 0.02:
		var desired_yaw: float = atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, minf(1.0, delta * 11.0))
	_animate_character(Vector2(velocity.x, velocity.z).length(), running, delta)


func _animate_character(speed: float, running: bool, delta: float) -> void:
	if _left_leg == null:
		return
	var amplitude: float = 0.62 if running else 0.42
	if speed > 0.2:
		_walk_phase += delta * (12.0 if running else 8.5)
	else:
		amplitude = 0.0
	var swing: float = sin(_walk_phase) * amplitude
	var smoothing: float = minf(1.0, delta * 14.0)
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, swing, smoothing)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -swing, smoothing)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -swing * 0.8, smoothing)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, swing * 0.8, smoothing)
	if attack_animating:
		var progress: float = 1.0 - _attack_time / 0.34
		_right_arm.rotation.x = -1.7 * sin(progress * PI)
		_right_arm.rotation.z = -0.28 * sin(progress * PI)
		_left_arm.rotation.x = -0.38
	else:
		_right_arm.rotation.z = lerpf(_right_arm.rotation.z, 0.0, smoothing)
