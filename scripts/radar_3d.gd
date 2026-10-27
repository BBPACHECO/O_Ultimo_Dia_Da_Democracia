extends Control
var player: Node3D
var world: Node3D
var mission: RefCounted
var enemies: Array = []
var citizens: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _map(p: Vector3) -> Vector2:
	return size * 0.5 + Vector2(p.x, p.z) * (size.x / 85.0)


func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var center: Vector2 = size * 0.5
	draw_line(Vector2(center.x, 10), Vector2(center.x, size.y - 10), Color("38525b"), 10)
	draw_line(Vector2(10, center.y), Vector2(size.x - 10, center.y), Color("38525b"), 5)
	if not is_instance_valid(player) or not is_instance_valid(world):
		return
	for point: Dictionary in world.evidence_points:
		if point["id"] not in mission.collected:
			draw_circle(_map(point["position"]), 4.0, Color("efc47e"))
	var tower: Vector2 = _map(world.tower_point)
	draw_rect(Rect2(tower - Vector2(4, 4), Vector2(8, 8)), Color("9cddc9"), false, 1.5)
	for patrol: Node3D in world.patrols:
		draw_circle(_map(patrol.global_position), 3.0, Color("e69578"))
	for guard: Node3D in enemies:
		if is_instance_valid(guard) and not guard.defeated_flag:
			draw_circle(_map(guard.global_position), 3.5, Color("e77c6f"))
	for citizen: Node3D in citizens:
		if is_instance_valid(citizen):
			draw_circle(_map(citizen.global_position), 3.0, Color("9dd6b5"))
	var p: Vector2 = _map(player.global_position)
	draw_circle(p, 4.0, Color("f5f3e6"))
	var direction: Vector3 = -player.camera.global_transform.basis.z
	var heading: Vector2 = Vector2(direction.x, direction.z).normalized()
	draw_line(p, p + heading * 11.0, Color("f5f3e6"), 2.0)


func _panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.13, 0.85)
	style.border_color = Color("6c807c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style
