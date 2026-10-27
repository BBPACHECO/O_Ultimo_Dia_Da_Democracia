extends Node3D
## Missão em terceira pessoa. Interface, personagem e cidade são todos nativos.
const City = preload("res://scripts/city_world.gd")
const Player = preload("res://scripts/player_3d.gd")
const Touch = preload("res://scripts/touch_controls.gd")
const Mission = preload("res://scripts/mission_state.gd")
const Radar = preload("res://scripts/radar_3d.gd")
const Guard = preload("res://scripts/enemy_guard.gd")
const Citizen = preload("res://scripts/citizen_npc.gd")
const Dialogues = preload("res://scripts/dialogue_book.gd")
const SERIF = preload("res://assets/fonts/DejaVuSerif-Bold.ttf")
const INK: Color = Color("f1ead8")
const GOLD: Color = Color("e7b974")
var mission = Mission.new()
var world: Node3D
var player: CharacterBody3D
var controls: Control
var phase: String = "home"
var hud: Control
var home_panel: PanelContainer
var pause_panel: PanelContainer
var result_panel: PanelContainer
var continue_button: Button
var result_title: Label
var result_body: Label
var objective: Label
var counter: Label
var clock: Label
var alert_bar: ProgressBar
var toast: Label
var radar: Control
var restart_dialog: ConfirmationDialog
var exit_dialog: ConfirmationDialog
var _toast_time: float = 0.0
var _autosave: float = 0.0
var _nearby: Dictionary = {}
var enemies: Array = []
var citizens: Array = []
var actors: Node3D
var health_label: Label
var dialogue_panel: PanelContainer
var dialogue_speaker: Label
var dialogue_text: Label
var dialogue_next: Button
var dialogue_lines: Array = []
var dialogue_index: int = 0
var _dialogue_npc: Node3D
var _dialogue_book = Dialogues.new()
var _attack_cooldown: float = 0.0
var graphics_quality: String = "smooth"
var graphics_settings_path: String = "user://graphics_settings.cfg"
var _quality_buttons: Array[Button] = []


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_reset_world()
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.reset_player(world.spawn_point)
	_spawn_actors()
	_build_interface()
	_load_graphics_quality()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	if mission.load_game() and mission.outcome.is_empty():
		continue_button.visible = true
	_restore_actor_progress()
	show_home()


func _reset_world() -> void:
	if is_instance_valid(actors):
		remove_child(actors)
		actors.free()
	enemies.clear()
	citizens.clear()
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = City.new()
	world.name = "CityWorld"
	add_child(world)
	mission.evidence_ids.clear()
	for point: Dictionary in world.evidence_points:
		mission.evidence_ids.append(String(point["id"]))
	if is_instance_valid(radar):
		radar.world = world
	if is_instance_valid(player):
		_spawn_actors()
	_apply_world_graphics()


func _load_graphics_quality() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(graphics_settings_path) == OK:
		var value: Variant = config.get_value("graphics", "quality", "smooth")
		if value is String and value in ["smooth", "light"]:
			graphics_quality = value
	set_graphics_quality(graphics_quality, false)


func set_graphics_quality(value: String, persist: bool = true) -> void:
	if value not in ["smooth", "light"]:
		return
	graphics_quality = value
	get_viewport().msaa_3d = Viewport.MSAA_2X if value == "smooth" else Viewport.MSAA_DISABLED
	_apply_world_graphics()
	for button: Button in _quality_buttons:
		button.text = "Gráficos: %s  ⇄" % ("Suave" if value == "smooth" else "Leve")
	if persist:
		var config: ConfigFile = ConfigFile.new()
		config.load(graphics_settings_path)
		config.set_value("graphics", "quality", graphics_quality)
		if config.save(graphics_settings_path) != OK:
			_message("A qualidade foi alterada, mas não foi possível salvar essa preferência.", 5.0)


func _apply_world_graphics() -> void:
	if not is_instance_valid(world):
		return
	if world.has_method("set_graphics_quality"):
		world.set_graphics_quality(graphics_quality == "smooth")
	else:
		for light: DirectionalLight3D in world.find_children("*", "DirectionalLight3D", true, false):
			light.shadow_enabled = graphics_quality == "smooth"


func _quality_button() -> Button:
	var button: Button = _button("Gráficos: Suave  ⇄", func() -> void:
		set_graphics_quality("light" if graphics_quality == "smooth" else "smooth")
	)
	button.name = "GraphicsQualityButton"
	_quality_buttons.append(button)
	return button


func _spawn_actors() -> void:
	actors = Node3D.new()
	actors.name = "PeopleOfAurora"
	add_child(actors)
	for route: Dictionary in world.guard_routes:
		var guard = Guard.new()
		guard.guard_id = String(route["id"])
		guard.target = player
		guard.patrol_route.assign(route["points"])
		guard.position = guard.patrol_route[0] + Vector3.UP * 0.1
		guard.struck_player.connect(_on_player_struck.bind(guard))
		guard.defeated.connect(_on_guard_defeated)
		actors.add_child(guard)
		enemies.append(guard)
	for spot: Dictionary in world.npc_spots:
		var citizen = Citizen.new()
		citizen.npc_id = String(spot["id"])
		citizen.display_name = String(spot["name"])
		citizen.position = spot["position"]
		actors.add_child(citizen)
		citizens.append(citizen)
	_restore_actor_progress()
	if is_instance_valid(radar):
		radar.enemies = enemies
		radar.citizens = citizens


func _restore_actor_progress() -> void:
	for guard: Node3D in enemies:
		if guard.guard_id in mission.defeated_ids:
			guard.restore_defeated()
	for citizen: Node3D in citizens:
		citizen.mark_spoken(citizen.npc_id in mission.talked_ids)


func _notification(what: int) -> void:
	if not is_instance_valid(controls):
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if restart_dialog.visible:
			restart_dialog.hide()
		elif exit_dialog.visible:
			exit_dialog.hide()
		elif phase == "dialogue":
			close_dialogue(false)
		elif phase == "playing":
			pause_mission()
		elif phase == "paused":
			resume_mission()
		elif phase == "result":
			show_home()
		else:
			exit_dialog.popup_centered(Vector2i(500, 190))
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if phase == "playing":
			pause_mission()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			if phase == "dialogue":
				advance_dialogue()
			elif phase == "playing":
				interact()
		elif event.physical_keycode == KEY_SPACE and phase == "playing":
			attack()
		elif event.physical_keycode == KEY_F and phase == "playing":
			player.toggle_camera_mode()
		elif event.physical_keycode == KEY_ESCAPE:
			if phase == "dialogue":
				close_dialogue(false)
			elif phase == "playing":
				pause_mission()
			elif phase == "paused":
				resume_mission()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(controls):
		return
	player.touch_move = controls.move_vector if phase == "playing" else Vector2.ZERO
	player.touch_sprint = controls.sprint_pressed and phase == "playing"


func _process(delta: float) -> void:
	if phase != "playing" or not is_instance_valid(player):
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	controls.set_attack_available(_attack_cooldown <= 0.0)
	var exposure: float = 0.0
	for patrol: Node3D in world.patrols:
		var offset: Vector3 = patrol.global_position - player.global_position
		var distance: float = Vector2(offset.x, offset.z).length()
		if distance < 5.0:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				patrol.global_position, player.global_position + Vector3.UP * 1.2)
			query.exclude = [player.get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				exposure = maxf(exposure, 1.0 - distance / 7.0)
	mission.tick(delta, exposure)
	_update_hud()
	_toast_time = maxf(0.0, _toast_time - delta)
	toast.visible = _toast_time > 0.0
	_autosave += delta
	if _autosave >= 5.0:
		_save_progress()
	if not mission.outcome.is_empty():
		_show_result()


func start_mission() -> void:
	mission.start_new()
	_attack_cooldown = 0.0
	_reset_world()
	player.reset_player(world.spawn_point)
	_set_phase("playing")
	_save_progress()
	_update_hud()
	_message("Converse com Lia junto à praça. Evite os zumbis ou use ATACAR para abrir caminho.", 7.0)


func continue_mission() -> void:
	if not mission.load_game() or not mission.outcome.is_empty():
		continue_button.visible = false
		return
	_reset_world()
	for id: String in mission.collected:
		world.mark_collected(id)
	world.set_tower_active(mission.collected.size() == mission.evidence_ids.size())
	player.reset_player(mission.position)
	_attack_cooldown = 0.0
	_set_phase("playing")
	_update_hud()
	_message("Missão retomada. A cidade ainda precisa ouvir a verdade.")


func show_home() -> void:
	if phase in ["playing", "paused"]:
		_save_progress()
	dialogue_lines.clear()
	_set_phase("home")
	continue_button.visible = mission.has_save() and mission.outcome.is_empty()


func pause_mission() -> void:
	if phase != "playing":
		return
	_save_progress()
	_set_phase("paused")


func resume_mission() -> void:
	if phase == "paused":
		_set_phase("playing")


func _set_phase(next: String) -> void:
	phase = next
	controls.reset_controls()
	controls.enabled = phase == "playing"
	controls.visible = phase == "playing"
	player.controls_enabled = phase == "playing"
	player.set_physics_process(phase == "playing")
	# Pause a patrulha sem desativar as colisões estáticas da cidade.
	world.set_process(phase == "playing")
	for guard: Node3D in enemies:
		guard.set_active(phase == "playing")
	for citizen: Node3D in citizens:
		citizen.set_active(phase == "playing")
	hud.visible = phase in ["playing", "dialogue"]
	home_panel.visible = phase == "home"
	pause_panel.visible = phase == "paused"
	result_panel.visible = phase == "result"
	dialogue_panel.visible = phase == "dialogue"


func _save_progress() -> void:
	mission.position = player.global_position
	_autosave = 0.0
	if not mission.save_game():
		_message("Não foi possível salvar. Mantenha o jogo aberto até terminar a missão.", 8.0)


func interact() -> void:
	if phase != "playing":
		return
	var target_npc: Node3D = _nearest_citizen()
	if target_npc != null:
		var npc_distance: float = _flat_distance(player.global_position, target_npc.global_position)
		var proof_distance: float = INF
		for point: Dictionary in world.evidence_points:
			if point["id"] not in mission.collected:
				proof_distance = minf(proof_distance, _flat_distance(player.global_position, point["position"]))
		var terminal_distance: float = _flat_distance(player.global_position, world.tower_point)
		if npc_distance < minf(proof_distance, terminal_distance) or (proof_distance > 2.8 and terminal_distance > 3.0):
			begin_dialogue(target_npc)
			return
	for point: Dictionary in world.evidence_points:
		if point["id"] in mission.collected:
			continue
		if _flat_distance(player.global_position, point["position"]) <= 2.8:
			if mission.collect(String(point["id"])):
				world.mark_collected(String(point["id"]))
				world.set_tower_active(mission.collected.size() == mission.evidence_ids.size())
				_save_progress()
				_update_hud()
				_message(String(point["description"]), 6.0)
			return
	if _flat_distance(player.global_position, world.tower_point) <= 3.0:
		if mission.transmit():
			_show_result()
		else:
			_message("Ainda faltam %d provas. Procure os feixes dourados pela cidade." % (3 - mission.collected.size()))
	else:
		_message("Aproxime-se de uma pessoa, prova ou do terminal para interagir.")


func _nearest_citizen() -> Node3D:
	var nearest: Node3D
	var best: float = 2.8
	for citizen: Node3D in citizens:
		var distance: float = _flat_distance(player.global_position, citizen.global_position)
		if distance < best and _line_clear(player.global_position, citizen.global_position):
			best = distance
			nearest = citizen
	return nearest


func _line_clear(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from + Vector3.UP * 1.2, to + Vector3.UP * 1.2, 1)
	# O colisor do próprio interlocutor não deve ser interpretado como uma parede.
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or Vector3(result["position"]).distance_to(to + Vector3.UP * 1.2) < 0.5


func attack() -> void:
	if phase != "playing" or _attack_cooldown > 0.0 or mission.health <= 0.0:
		return
	_attack_cooldown = 0.55
	controls.set_attack_available(false)
	player.play_attack()
	var victim: Node3D
	var best: float = 2.6
	for guard: Node3D in enemies:
		if guard.defeated_flag or not guard.active:
			continue
		var offset: Vector3 = guard.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= best and player.facing_direction.dot(offset.normalized()) >= 0.1 and _line_clear(player.global_position, guard.global_position):
			victim = guard
			best = distance
	if victim != null and victim.take_hit(25.0, player.global_position):
		if not victim.defeated_flag:
			_message("Você abriu espaço. Ataque novamente ou afaste-se antes da reação.", 2.0)


func _on_player_struck(damage: float, guard: Node3D) -> void:
	if phase != "playing" or not is_instance_valid(guard) or guard.defeated_flag or not guard.active:
		return
	if _flat_distance(player.global_position, guard.global_position) > 2.1 or not _line_clear(guard.global_position, player.global_position):
		return
	if mission.take_damage(damage):
		player.play_hurt()
		_update_hud()
		_message("O zumbi atingiu você. Recue quando ele preparar o próximo ataque.", 3.0)
		if not mission.outcome.is_empty():
			_show_result()


func _on_guard_defeated(guard: Node3D) -> void:
	if guard.guard_id not in mission.defeated_ids:
		mission.defeated_ids.append(guard.guard_id)
		_save_progress()
		_message("Zumbi derrubado. O caminho está livre.", 3.0)


func begin_dialogue(npc: Node3D) -> void:
	if phase != "playing" or not is_instance_valid(npc) or npc not in citizens:
		return
	if _flat_distance(player.global_position, npc.global_position) > 2.8 or not _line_clear(player.global_position, npc.global_position):
		return
	dialogue_lines = _dialogue_book.get_dialogue(npc.npc_id, {
		"collected": mission.collected.size(), "talked": mission.talked_ids,
		"defeated": mission.defeated_ids.size(), "health": mission.health,
	})
	if dialogue_lines.is_empty():
		return
	_save_progress()
	_dialogue_npc = npc
	dialogue_index = 0
	npc.face_position(player.global_position)
	_set_phase("dialogue")
	_render_dialogue()


func _render_dialogue() -> void:
	var line: Dictionary = dialogue_lines[dialogue_index]
	dialogue_speaker.text = String(line["speaker"])
	dialogue_text.text = String(line["text"])
	dialogue_next.text = "Concluir conversa" if dialogue_index == dialogue_lines.size() - 1 else "Continuar  →"


func advance_dialogue() -> void:
	if phase != "dialogue":
		return
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		close_dialogue(true)
	else:
		_render_dialogue()


func close_dialogue(completed: bool = false) -> void:
	if phase != "dialogue":
		return
	if completed and is_instance_valid(_dialogue_npc) and _dialogue_npc.npc_id not in mission.talked_ids:
		var id: String = _dialogue_npc.npc_id
		mission.talked_ids.append(id)
		_dialogue_npc.mark_spoken(true)
		if id == "lia":
			mission.health = minf(100.0, mission.health + 20.0)
		elif id == "tomas":
			mission.alert = 0.0
	dialogue_lines.clear()
	_dialogue_npc = null
	_set_phase("playing")
	_save_progress()
	_update_hud()
	_message("Conversa concluída. Continue a missão." if completed else "Conversa encerrada. Você pode voltar a falar quando quiser.", 3.0)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_hud() -> void:
	var seconds: int = ceili(mission.remaining())
	clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	counter.text = "PROVAS  %d / 3" % mission.collected.size()
	alert_bar.value = mission.alert
	health_label.text = "VIDA  %03d / 100   ·   ZUMBIS  %d / 3" % [ceili(mission.health), mission.defeated_ids.size()]
	var best: float = INF
	_nearby = {}
	for point: Dictionary in world.evidence_points:
		if point["id"] in mission.collected:
			continue
		var distance: float = _flat_distance(player.global_position, point["position"])
		if distance < best:
			best = distance
			_nearby = point
	var tower_distance: float = _flat_distance(player.global_position, world.tower_point)
	if mission.collected.size() == 3:
		objective.text = "TRANSMITA AS PROVAS\nTorre de transmissão · %dm" % roundi(tower_distance)
		controls.set_interaction_label("Transmitir", tower_distance <= 3.0)
	elif not _nearby.is_empty():
		objective.text = "RECOLHA AS PROVAS\n%s · %dm" % [String(_nearby["title"]), roundi(best)]
		if tower_distance <= 3.0 and best > 2.8:
			controls.set_interaction_label("Terminal", true)
		else:
			controls.set_interaction_label("Recolher prova" if best <= 2.8 else "Aproxime-se", best <= 2.8)
	var npc: Node3D = _nearest_citizen()
	if npc != null:
		var npc_distance: float = _flat_distance(player.global_position, npc.global_position)
		if (npc_distance < best or best > 2.8) and (npc_distance < tower_distance or tower_distance > 3.0):
			controls.set_interaction_label("Falar com " + npc.display_name, true)


func _message(text: String, duration: float = 4.0) -> void:
	if not is_instance_valid(toast):
		return
	toast.text = text
	_toast_time = duration
	toast.visible = true


func _show_result() -> void:
	_save_progress()
	_set_phase("result")
	if mission.outcome == "transmitted":
		result_title.text = "A cidade\nouviu."
		result_body.text = "Você atravessou Aurora e colocou as três provas no ar antes da meia-noite. Nas janelas, as primeiras luzes se acendem.\n\nMissão concluída em %dmin %02ds." % [int(mission.elapsed) / 60, int(mission.elapsed) % 60]
	elif mission.outcome == "detected":
		result_title.text = "Sinal\ninterrompido."
		result_body.text = "As patrulhas localizaram seu sinal. Na próxima tentativa, mantenha distância dos drones e use os edifícios como cobertura."
	elif mission.outcome == "injured":
		result_title.text = "Você foi\ninterceptado."
		result_body.text = "Os zumbis cercaram você antes da transmissão. Evite ficar parado: recue quando prepararem o ataque e use ATACAR para abrir uma saída."
	else:
		result_title.text = "Meia-noite\nchegou."
		result_body.text = "O prazo acabou antes da transmissão. As provas estão nos feixes dourados; recolha as três e leve-as ao terminal da torre."


func _request_start() -> void:
	if mission.has_save() and mission.outcome.is_empty():
		restart_dialog.popup_centered(Vector2i(540, 190))
	else:
		start_mission()


func _apply_safe_area() -> void:
	if not is_instance_valid(hud):
		return
	var insets: Vector4 = Vector4.ZERO
	if OS.has_feature("mobile"):
		var screen: Vector2i = DisplayServer.screen_get_size()
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var scale_x: float = viewport_size.x / float(screen.x)
			var scale_y: float = viewport_size.y / float(screen.y)
			insets = Vector4(safe.position.x * scale_x, safe.position.y * scale_y,
				(screen.x - safe.end.x) * scale_x, (screen.y - safe.end.y) * scale_y)
	hud.offset_left = insets.x
	hud.offset_top = insets.y
	hud.offset_right = -insets.z
	hud.offset_bottom = -insets.w
	for panel: PanelContainer in [home_panel, pause_panel, result_panel]:
		panel.offset_left = insets.x
		panel.offset_right = 590.0 + insets.x
		panel.offset_top = insets.y
		panel.offset_bottom = -insets.w


func _style(color: Color, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline
	style.set_border_width_all(1 if outline.a > 0.0 else 0)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	return style


func _label(text: String, font_size: int = 22, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 62
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("122a34") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("122a34") if primary else INK)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("19343f"), GOLD))
	button.add_theme_stylebox_override("hover", _style(Color("f4d49e") if primary else Color("2b4c56"), INK))
	button.add_theme_stylebox_override("pressed", _style(Color("c79450"), GOLD))
	button.pressed.connect(action)
	return button


func _overlay(parent: Control, title: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = title
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = 590
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.085, 0.11, 0.94)))
	parent.add_child(panel)
	return panel


func _column(panel: PanelContainer) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	panel.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	return column


func _headline(text: String) -> Label:
	var label: Label = _label(text, 54)
	label.add_theme_font_override("font", SERIF)
	return label


func _build_interface() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var root_ui: Control = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root_ui)
	hud = Control.new()
	hud.name = "MissionHUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(hud)
	var mission_panel: PanelContainer = PanelContainer.new()
	mission_panel.position = Vector2(28, 24)
	mission_panel.size = Vector2(460, 112)
	mission_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.1, 0.13, 0.87)))
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mission_panel)
	var mission_box: VBoxContainer = VBoxContainer.new()
	mission_panel.add_child(mission_box)
	counter = _label("PROVAS  0 / 3", 17, GOLD)
	mission_box.add_child(counter)
	objective = _label("RECOLHA AS PROVAS", 22)
	objective.name = "Objective"
	mission_box.add_child(objective)
	clock = _label("05:00", 38, INK)
	clock.name = "MissionClock"
	clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock.position = Vector2(-60, 26)
	clock.size = Vector2(120, 54)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_theme_stylebox_override("normal", _style(Color(0.04, 0.1, 0.13, 0.88)))
	hud.add_child(clock)
	var pause_button: Button = _button("Pausa  Ⅱ", pause_mission)
	pause_button.name = "PauseButton"
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-190, 24)
	pause_button.size = Vector2(162, 58)
	hud.add_child(pause_button)
	radar = Radar.new()
	radar.name = "CityMap"
	radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radar.position = Vector2(-190, 100)
	radar.size = Vector2(162, 162)
	radar.player = player
	radar.world = world
	radar.mission = mission
	radar.enemies = enemies
	radar.citizens = citizens
	hud.add_child(radar)
	var vitals_panel: PanelContainer = PanelContainer.new()
	vitals_panel.position = Vector2(22, 145)
	vitals_panel.size = Vector2(376, 120)
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.1, 0.13, 0.9)))
	hud.add_child(vitals_panel)
	var risk_label: Label = _label("ALERTA DAS PATRULHAS", 14, GOLD)
	risk_label.position = Vector2(30, 158)
	risk_label.size = Vector2(300, 24)
	hud.add_child(risk_label)
	alert_bar = ProgressBar.new()
	alert_bar.position = Vector2(30, 187)
	alert_bar.size = Vector2(300, 5)
	alert_bar.show_percentage = false
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color("344a51")
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("e49b7d")
	alert_bar.add_theme_stylebox_override("background", track)
	alert_bar.add_theme_stylebox_override("fill", fill)
	alert_bar.size = Vector2(300, 6)
	hud.add_child(alert_bar)
	health_label = _label("VIDA  100 / 100   ·   ZUMBIS  0 / 3", 17, Color("b9d8b0"))
	health_label.name = "HealthLabel"
	health_label.position = Vector2(30, 224)
	health_label.size = Vector2(390, 30)
	hud.add_child(health_label)
	var camera_button: Button = _button("VISÃO  ◇", func() -> void: player.toggle_camera_mode())
	camera_button.name = "CameraButton"
	camera_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	camera_button.position = Vector2(-385, 24)
	camera_button.size = Vector2(175, 58)
	hud.add_child(camera_button)
	toast = _label("", 21)
	toast.name = "MissionMessage"
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-300, -156)
	toast.size = Vector2(600, 96)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_stylebox_override("normal", _style(Color(0.04, 0.1, 0.13, 0.88)))
	hud.add_child(toast)
	controls = Touch.new()
	controls.name = "TouchControls"
	controls.interacted.connect(interact)
	controls.attacked.connect(attack)
	controls.camera_toggled.connect(func() -> void: player.toggle_camera_mode())
	controls.look_dragged.connect(func(motion: Vector2) -> void:
		if phase == "playing":
			player.add_camera_look(motion)
	)
	root_ui.add_child(controls)
	home_panel = _overlay(root_ui, "HomeScreen")
	var home: VBoxContainer = _column(home_panel)
	home.add_child(_label("AURORA · 23:55", 17, GOLD))
	home.add_child(_headline("O ÚLTIMO DIA\nDA DEMOCRACIA"))
	home.add_child(_label("Atravesse a cidade.\nFaça a verdade chegar ao ar.", 24))
	home.add_child(_label("Converse com os sobreviventes, enfrente ou evite os zumbis e reúna três provas para transmitir antes da meia-noite.", 20, Color("b1c4c5")))
	continue_button = _button("Continuar missão", continue_mission, true)
	continue_button.name = "ContinueMissionButton"
	continue_button.visible = false
	home.add_child(continue_button)
	var start_button: Button = _button("Iniciar missão   →", _request_start, true)
	start_button.name = "StartMissionButton"
	home.add_child(start_button)
	home.add_child(_quality_button())
	home.add_child(_label("TOQUE  Joystick · Arraste para olhar · ATACAR · VISÃO\nPC  WASD · Shift · E conversa/ação · Espaço ataque · F câmera", 15, Color("a7bcbd")))
	home.add_child(_label("Uma história fictícia. Jogue offline, no seu celular.", 15, GOLD))
	pause_panel = _overlay(root_ui, "PauseScreen")
	var pause: VBoxContainer = _column(pause_panel)
	pause.add_child(_label("O TEMPO ESTÁ PARADO", 17, GOLD))
	pause.add_child(_headline("Respire.\nAurora espera."))
	pause.add_child(_label("A missão e as patrulhas ficam pausadas enquanto esta tela estiver aberta.", 22))
	pause.add_child(_button("Voltar à missão", resume_mission, true))
	pause.add_child(_quality_button())
	pause.add_child(_button("Voltar ao menu", show_home))
	result_panel = _overlay(root_ui, "ResultScreen")
	var result: VBoxContainer = _column(result_panel)
	result.add_child(_label("O DIA SEGUINTE", 17, GOLD))
	result_title = _headline("")
	result_title.name = "ResultTitle"
	result.add_child(result_title)
	result_body = _label("", 23)
	result.add_child(result_body)
	result.add_child(_button("Tentar outra vez", start_mission, true))
	result.add_child(_button("Voltar ao menu", show_home))
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.position = Vector2(-450, -308)
	dialogue_panel.size = Vector2(900, 280)
	dialogue_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.09, 0.10, 0.97), GOLD))
	root_ui.add_child(dialogue_panel)
	var dialogue_box: VBoxContainer = VBoxContainer.new()
	dialogue_box.add_theme_constant_override("separation", 12)
	dialogue_panel.add_child(dialogue_box)
	dialogue_speaker = _label("", 22, GOLD)
	dialogue_speaker.name = "DialogueSpeaker"
	dialogue_box.add_child(dialogue_speaker)
	dialogue_text = _label("", 23)
	dialogue_text.name = "DialogueText"
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_box.add_child(dialogue_text)
	var dialogue_actions: HBoxContainer = HBoxContainer.new()
	dialogue_actions.add_theme_constant_override("separation", 18)
	dialogue_box.add_child(dialogue_actions)
	var cancel_dialogue: Button = _button("Encerrar conversa", close_dialogue.bind(false))
	cancel_dialogue.name = "EndDialogueButton"
	cancel_dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_actions.add_child(cancel_dialogue)
	dialogue_next = _button("Continuar  →", advance_dialogue, true)
	dialogue_next.name = "AdvanceDialogueButton"
	dialogue_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_actions.add_child(dialogue_next)
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "Recomeçar a missão?"
	restart_dialog.dialog_text = "O progresso da missão atual será substituído."
	restart_dialog.get_ok_button().text = "Recomeçar"
	restart_dialog.get_cancel_button().text = "Cancelar"
	restart_dialog.confirmed.connect(start_mission)
	root_ui.add_child(restart_dialog)
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Fechar o jogo?"
	exit_dialog.dialog_text = "Você poderá continuar a missão ao abrir o jogo novamente."
	exit_dialog.get_ok_button().text = "Fechar"
	exit_dialog.get_cancel_button().text = "Ficar"
	exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	root_ui.add_child(exit_dialog)
