extends CharacterBody3D
## Personagem e câmera em terceira pessoa, renderizados pelo engine nativo.

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
var camera_yaw: float = 0.0
var camera_pitch: float = -0.28

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _walk_phase: float = 0.0
var _spawn_position: Vector3 = Vector3.ZERO
var _gravity: float = 9.8


func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
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


func _material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _limb(parent: Node3D, at: Vector3, length: float, width: float, material: Material) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	_box(pivot, Vector3(width, length, width), Vector3(0, -length * 0.5, 0), material)
	return pivot


func _build_character() -> void:
	visual = Node3D.new()
	visual.name = "Reporter"
	add_child(visual)
	var coat = _material(Color("c29864"))
	var coat_shadow = _material(Color("856647"))
	var trousers = _material(Color("263641"))
	var shoes = _material(Color("16222a"))
	var skin = _material(Color("b98461"))
	var hair = _material(Color("262627"))
	var bag = _material(Color("754b35"))
	var strap = _material(Color("342d2a"))
	var paper = _material(Color("efe1bd"))
	_box(visual, Vector3(0.66, 0.78, 0.42), Vector3(0, 1.20, 0), coat)
	_box(visual, Vector3(0.67, 0.18, 0.44), Vector3(0, 0.87, 0), coat_shadow)
	# Costura central e lapelas ajudam a ler a silhueta por frente e por trás.
	_box(visual, Vector3(0.024, 0.65, 0.015), Vector3(0, 1.20, -0.22), coat_shadow)
	for side in [-1.0, 1.0]:
		var lapel = _box(visual, Vector3(0.14, 0.24, 0.025), Vector3(side * 0.10, 1.48, -0.22), coat_shadow)
		lapel.rotation.z = side * -0.25
	_box(visual, Vector3(0.17, 0.18, 0.17), Vector3(0, 1.63, 0), skin)
	_sphere(visual, 0.235, 0.43, Vector3(0, 1.85, 0), skin)
	_box(visual, Vector3(0.40, 0.12, 0.37), Vector3(0, 2.015, 0.025), hair)
	_box(visual, Vector3(0.40, 0.14, 0.10), Vector3(0, 1.94, 0.17), hair)
	_sphere(visual, 0.045, 0.08, Vector3(0, 1.83, -0.23), skin)
	for side in [-1.0, 1.0]:
		_box(visual, Vector3(0.035, 0.035, 0.018), Vector3(side * 0.085, 1.89, -0.216), hair)
	# Mochila de trabalho e caderno: o protagonista é um repórter, não um soldado.
	_box(visual, Vector3(0.44, 0.54, 0.22), Vector3(0, 1.25, 0.31), bag)
	_box(visual, Vector3(0.31, 0.18, 0.025), Vector3(0, 1.12, 0.435), coat_shadow)
	for side in [-1.0, 1.0]:
		_box(visual, Vector3(0.065, 0.69, 0.06), Vector3(side * 0.22, 1.26, 0.21), strap)
	_box(visual, Vector3(0.14, 0.18, 0.05), Vector3(0.20, 1.19, -0.24), paper)
	_left_leg = _limb(visual, Vector3(-0.18, 0.84, 0), 0.71, 0.23, trousers)
	_right_leg = _limb(visual, Vector3(0.18, 0.84, 0), 0.71, 0.23, trousers)
	_box(_left_leg, Vector3(0.25, 0.14, 0.38), Vector3(0, -0.73, -0.06), shoes)
	_box(_right_leg, Vector3(0.25, 0.14, 0.38), Vector3(0, -0.73, -0.06), shoes)
	_left_arm = _limb(visual, Vector3(-0.43, 1.48, 0), 0.59, 0.20, coat)
	_right_arm = _limb(visual, Vector3(0.43, 1.48, 0), 0.59, 0.20, coat)
	_sphere(_left_arm, 0.105, 0.21, Vector3(0, -0.64, 0), skin)
	_sphere(_right_arm, 0.105, 0.21, Vector3(0, -0.64, 0), skin)


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
	_update_camera()


func add_camera_look(delta: Vector2) -> void:
	if not controls_enabled or not delta.is_finite():
		return
	camera_yaw = wrapf(camera_yaw - delta.x * LOOK_SENSITIVITY, -PI, PI)
	camera_pitch = clampf(camera_pitch - delta.y * LOOK_SENSITIVITY, -0.82, -0.10)
	_update_camera()


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
	camera_yaw = 0.0
	camera_pitch = -0.28
	_walk_phase = 0.0
	if visual != null:
		visual.rotation = Vector3.ZERO
	_update_camera()
	_animate_character(0.0, false, 1.0)


func _physics_process(delta: float) -> void:
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
