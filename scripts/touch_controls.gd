extends Control
## Controles nativos: cada dedo conserva sua função até ser levantado.

signal interacted
signal look_dragged(delta: Vector2)
signal attacked
signal camera_toggled
signal healed

const NAVY := Color("102a35")
const GOLD := Color("e0b777")
const MUTED := Color("a9c0c3")
const STICK_RADIUS := 74.0
const THUMB_RADIUS := 29.0

var move_vector: Vector2 = Vector2.ZERO
var sprint_pressed: bool = false
var enabled: bool = true:
	set(value):
		enabled = value
		visible = value
		if not value:
			reset_controls()

# Botão do HUD, tratado com o mesmo multitoque das ações de combate.
var heal_button: Button

var interact_button: Button
var sprint_button: Button
var attack_button: Button
var _move_label: Label
var _look_label: Label
var _joystick_center := Vector2(160, 560)
var _joystick_finger: int = -1
var _look_finger: int = -1
var _sprint_fingers: Dictionary = {}
var _interaction_fingers: Dictionary = {}
var _attack_fingers: Dictionary = {}
var _heal_fingers: Dictionary = {}
var _mouse_joystick: bool = false
var _mouse_sprint: bool = false
var _mouse_interaction: bool = false
var _mouse_attack: bool = false
var _interaction_available: bool = false
var _attack_available: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_button = _make_button("INTERAGIR", "InteractButton")
	interact_button.pressed.connect(_emit_interaction)
	interact_button.disabled = true
	sprint_button = _make_button("CORRER", "SprintButton")
	attack_button = _make_button("ATACAR", "AttackButton")
	attack_button.pressed.connect(_emit_attack)
	attack_button.disabled = not _attack_available
	_move_label = _make_label("MOVER")
	_look_label = _make_label("DESLIZE À DIREITA PARA OLHAR")
	resized.connect(_layout_controls)
	_layout_controls()
	visible = enabled


func _make_button(caption: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	# Touch is handled below, independently for every finger. Ignoring GUI
	# mouse events prevents Android's emulated mouse from pressing it twice.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("f5ead7"))
	button.add_theme_color_override("font_disabled_color", Color("96a8aa"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NAVY, 0.88)
	style.border_color = Color(GOLD, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	button.add_theme_stylebox_override("normal", style)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(NAVY, 0.67)
	disabled_style.border_color = Color(MUTED, 0.32)
	button.add_theme_stylebox_override("disabled", disabled_style)
	add_child(button)
	return button


func _make_label(caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label


func _safe_insets() -> Vector4:
	var insets := Vector4(24, 24, 24, 24)
	if not OS.has_feature("mobile"):
		return insets
	var screen_size := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return insets
	var sx := size.x / float(screen_size.x)
	var sy := size.y / float(screen_size.y)
	insets.x += safe.position.x * sx
	insets.y += safe.position.y * sy
	insets.z += (screen_size.x - safe.end.x) * sx
	insets.w += (screen_size.y - safe.end.y) * sy
	return insets


func _layout_controls() -> void:
	if interact_button == null:
		return
	var inset := _safe_insets()
	_joystick_center = Vector2(inset.x + 136, size.y - inset.w - 136)
	interact_button.position = Vector2(size.x - inset.z - 242, size.y - inset.w - 204)
	interact_button.size = Vector2(218, 78)
	sprint_button.position = Vector2(size.x - inset.z - 188, size.y - inset.w - 106)
	sprint_button.size = Vector2(164, 70)
	attack_button.position = Vector2(size.x - inset.z - 216, size.y - inset.w - 306)
	attack_button.size = Vector2(192, 78)
	_move_label.position = _joystick_center + Vector2(-85, 102)
	_move_label.size = Vector2(170, 22)
	_look_label.position = Vector2(size.x * 0.39, size.y - inset.w - 34)
	_look_label.size = Vector2(size.x * 0.32, 22)
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	draw_circle(_joystick_center, STICK_RADIUS + 13, Color(NAVY, 0.6), true, -1, true)
	draw_circle(_joystick_center, STICK_RADIUS, Color(NAVY, 0.72), true, -1, true)
	draw_arc(_joystick_center, STICK_RADIUS, 0, TAU, 64, Color(GOLD, 0.65), 2, true)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(_joystick_center + direction * 58, _joystick_center + direction * 65,
			Color(GOLD, 0.5), 2, true)
	var thumb := _joystick_center + move_vector * (STICK_RADIUS - 15)
	draw_circle(thumb, THUMB_RADIUS, Color(GOLD, 0.84 if _joystick_finger >= 0 or _mouse_joystick else 0.42), true, -1, true)
	draw_arc(thumb, THUMB_RADIUS, 0, TAU, 32, Color(GOLD, 0.95), 2, true)


func set_interaction_label(text: String, available: bool) -> void:
	_interaction_available = available
	if interact_button != null:
		interact_button.text = text if not text.is_empty() else "INTERAGIR"
		interact_button.disabled = not available


func set_attack_available(value: bool) -> void:
	_attack_available = value
	if attack_button != null:
		attack_button.disabled = not value


func reset_controls() -> void:
	move_vector = Vector2.ZERO
	sprint_pressed = false
	_joystick_finger = -1
	_look_finger = -1
	_sprint_fingers.clear()
	_interaction_fingers.clear()
	_attack_fingers.clear()
	_heal_fingers.clear()
	_mouse_joystick = false
	_mouse_sprint = false
	_mouse_interaction = false
	_mouse_attack = false
	_refresh_buttons()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset_controls()


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	# Native touch and physical mouse have independent paths. Synthetic events
	# are ignored, so one finger never becomes two interactions.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var handled := false
	if event is InputEventScreenTouch:
		var local := make_input_local(event) as InputEventScreenTouch
		if local.pressed and not local.canceled:
			handled = _touch_pressed(local.index, local.position)
		else:
			handled = _touch_released(local.index)
	elif event is InputEventScreenDrag:
		var local := make_input_local(event) as InputEventScreenDrag
		if local.index == _joystick_finger:
			_set_move(local.position)
			handled = true
		elif local.index == _look_finger:
			look_dragged.emit(local.relative)
			handled = true
		elif _sprint_fingers.has(local.index) or _interaction_fingers.has(local.index) or _attack_fingers.has(local.index) or _heal_fingers.has(local.index):
			handled = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := make_input_local(event) as InputEventMouseButton
		handled = _mouse_pressed(local.position) if local.pressed else _mouse_released()
	elif event is InputEventMouseMotion and _mouse_joystick:
		var local := make_input_local(event) as InputEventMouseMotion
		_set_move(local.position)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _touch_pressed(index: int, at: Vector2) -> bool:
	# A duplicate press cannot reassign an existing finger or trigger two attacks.
	if index == _joystick_finger or index == _look_finger or _sprint_fingers.has(index) or _interaction_fingers.has(index) or _attack_fingers.has(index) or _heal_fingers.has(index):
		return true
	if _over_heal_button(at):
		_heal_fingers[index] = true
		if not heal_button.disabled:
			healed.emit()
		return true
	if attack_button.get_rect().has_point(at):
		_attack_fingers[index] = true
		_refresh_buttons()
		_emit_attack()
		return true
	if interact_button.get_rect().has_point(at):
		_interaction_fingers[index] = true
		_refresh_buttons()
		_emit_interaction()
		return true
	if sprint_button.get_rect().has_point(at):
		_sprint_fingers[index] = true
		sprint_pressed = true
		_refresh_buttons()
		return true
	if _joystick_finger < 0 and at.x < size.x * 0.4 and at.y > size.y * 0.42:
		_joystick_finger = index
		_set_move(at)
		return true
	if _look_finger < 0 and at.x > size.x * 0.42 and at.y > 118:
		_look_finger = index
		return true
	return false


func _touch_released(index: int) -> bool:
	var handled := false
	if index == _joystick_finger:
		_joystick_finger = -1
		move_vector = Vector2.ZERO
		handled = true
	if index == _look_finger:
		_look_finger = -1
		handled = true
	if _sprint_fingers.has(index):
		_sprint_fingers.erase(index)
		sprint_pressed = not _sprint_fingers.is_empty() or _mouse_sprint
		handled = true
	if _interaction_fingers.has(index):
		_interaction_fingers.erase(index)
		handled = true
	if _attack_fingers.has(index):
		_attack_fingers.erase(index)
		handled = true
	if _heal_fingers.has(index):
		_heal_fingers.erase(index)
		handled = true
	_refresh_buttons()
	queue_redraw()
	return handled


func _mouse_pressed(at: Vector2) -> bool:
	if _over_heal_button(at):
		if not heal_button.disabled:
			healed.emit()
		return true
	if attack_button.get_rect().has_point(at):
		_mouse_attack = true
		_refresh_buttons()
		_emit_attack()
		return true
	if interact_button.get_rect().has_point(at):
		_mouse_interaction = true
		_refresh_buttons()
		_emit_interaction()
		return true
	if sprint_button.get_rect().has_point(at):
		_mouse_sprint = true
		sprint_pressed = true
		_refresh_buttons()
		return true
	if at.x < size.x * 0.4 and at.y > size.y * 0.42:
		_mouse_joystick = true
		_set_move(at)
		return true
	return false


func _over_heal_button(at: Vector2) -> bool:
	return is_instance_valid(heal_button) and heal_button.is_visible_in_tree() and heal_button.get_global_rect().has_point(get_global_transform() * at)


func _mouse_released() -> bool:
	var handled := _mouse_joystick or _mouse_sprint or _mouse_interaction or _mouse_attack
	_mouse_joystick = false
	_mouse_sprint = false
	_mouse_interaction = false
	_mouse_attack = false
	if _joystick_finger < 0:
		move_vector = Vector2.ZERO
	sprint_pressed = not _sprint_fingers.is_empty()
	_refresh_buttons()
	queue_redraw()
	return handled


func _set_move(at: Vector2) -> void:
	var offset := (at - _joystick_center) / STICK_RADIUS
	move_vector = offset.limit_length(1.0) if offset.length() >= 0.12 else Vector2.ZERO
	queue_redraw()


func _emit_interaction() -> void:
	if enabled and _interaction_available:
		interacted.emit()


func _emit_attack() -> void:
	if enabled and _attack_available:
		attacked.emit()


func _refresh_buttons() -> void:
	if interact_button != null:
		interact_button.modulate = GOLD if not _interaction_fingers.is_empty() or _mouse_interaction else Color.WHITE
	if sprint_button != null:
		sprint_button.modulate = GOLD if sprint_pressed else Color.WHITE
	if attack_button != null:
		attack_button.modulate = GOLD if not _attack_fingers.is_empty() or _mouse_attack else Color.WHITE
