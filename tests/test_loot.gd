extends SceneTree
## Recursos e migração do progresso de exploração; arquivos separados do jogador.
const Mission = preload("res://scripts/mission_state.gd")
const Loot = preload("res://scripts/loot_catalog.gd")
const MODEL_SAVE: String = "user://test_loot_model.json"
const SCENE_SAVE: String = "user://test_loot_scene.json"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FALHOU: " + message)


func clean_save(path: String) -> void:
	for file: String in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


func write_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(MODEL_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func settle(frames: int = 3) -> void:
	for frame in range(frames):
		await physics_frame
		await process_frame


func _test_model() -> void:
	var mission = Mission.new()
	mission.save_path = MODEL_SAVE
	clean_save(MODEL_SAVE)
	mission.start_new()
	check(mission.supplies == 0 and mission.looted_ids.is_empty(), "Missão começa sem inventar suprimentos")
	check(not mission.collect_loot("desconhecido"), "Um ponto inexistente não cria itens")
	check(not mission.use_supplies(), "Sem suprimentos não há cura")
	var first: Dictionary = Loot.POINTS[0]
	var second: Dictionary = Loot.POINTS[1]
	check(mission.collect_loot(first["id"]) and mission.supplies == int(first["amount"]), "Revistar um ponto concede o conteúdo definido")
	check(not mission.collect_loot(first["id"]) and mission.looted_ids.size() == 1, "Um recipiente não pode ser explorado repetidamente")
	var stock: int = mission.supplies
	check(not mission.use_supplies() and mission.supplies == stock, "Saúde cheia não desperdiça itens")
	mission.take_damage(60.0)
	check(mission.use_supplies() and is_equal_approx(mission.health, 75.0), "Um suprimento recupera 35 de saúde durante a missão")
	check(mission.supplies == stock - 1, "A cura consome exatamente um suprimento")
	mission.health = 95.0
	check(mission.use_supplies() and is_equal_approx(mission.health, 100.0), "Cura perto do máximo é limitada a 100")
	mission.supplies = 8
	check(mission.collect_loot(second["id"]) and mission.supplies == 9, "Mochila para no limite de nove unidades")
	var third: Dictionary = Loot.POINTS[2]
	check(not mission.collect_loot(third["id"]) and third["id"] not in mission.looted_ids, "Mochila cheia deixa o recipiente disponível")
	mission.health = 50.0
	mission.use_supplies()
	check(mission.collect_loot(third["id"]) and mission.supplies == 9, "Após usar um item, a coleta respeita a capacidade restante")
	mission.health = 77.0
	mission.elapsed = 51.0
	mission.alert = 12.0
	mission.defeated_ids.append("g1")
	mission.talked_ids.append("lia")
	mission.collect(mission.evidence_ids[0])
	mission.position = Vector3(-8, 0.1, 14)
	check(mission.save_game(), "Suprimentos e recipientes podem ser salvos")
	var restored = Mission.new()
	restored.save_path = MODEL_SAVE
	check(restored.load_game() and restored.supplies == 9, "Retomar conserva o inventário")
	check(restored.looted_ids == mission.looted_ids, "Retomar conserva todos os recipientes já esvaziados")
	check(not restored.collect_loot(first["id"]), "Carregar não permite coletar o mesmo loot novamente")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MODEL_SAVE))
	check(int(payload["version"]) == 3 and not FileAccess.file_exists(MODEL_SAVE + ".tmp"), "Novo esquema é salvo atomicamente")
	for invalid: Variant in [-1, 10, 1.5, "2", null, true]:
		var bad: Dictionary = payload.duplicate(true)
		bad["supplies"] = invalid
		write_save(bad)
		check(not restored.load_game(), "Inventário inválido é recusado: " + str(invalid))
	for invalid: Variant in [null, "lista", ["desconhecido"], [first["id"], first["id"]], [1]]:
		var bad: Dictionary = payload.duplicate(true)
		bad["looted_ids"] = invalid
		write_save(bad)
		check(not restored.load_game(), "Recipientes inválidos não entram no progresso")
	check(restored.supplies == 9 and restored.looted_ids == mission.looted_ids, "Falha de leitura conserva o inventário em memória")
	for field: String in ["supplies", "looted_ids"]:
		var bad: Dictionary = payload.duplicate(true)
		bad.erase(field)
		write_save(bad)
		check(not restored.load_game(), "Esquema novo exige o campo " + field)
	var old: Dictionary = payload.duplicate(true)
	old["version"] = 2
	old.erase("supplies")
	old.erase("looted_ids")
	write_save(old)
	check(restored.load_game(), "Save anterior da versão visual continua válido")
	check(restored.supplies == 0 and restored.looted_ids.is_empty(), "Migração inicializa loot sem conceder itens")
	check(is_equal_approx(restored.health, 77.0) and restored.collected == mission.collected, "Migração mantém saúde e provas anteriores")
	check(restored.defeated_ids == ["g1"] and restored.talked_ids == ["lia"], "Migração mantém combate e conversas")
	check(restored.position.is_equal_approx(mission.position) and is_equal_approx(restored.elapsed, 51.0) and is_equal_approx(restored.alert, 12.0), "Migração mantém posição, prazo e alerta")
	old["version"] = 1
	old.erase("health")
	old.erase("defeated_ids")
	old.erase("talked_ids")
	write_save(old)
	check(restored.load_game() and is_equal_approx(restored.health, 100.0) and restored.supplies == 0, "Esquema original ainda migra para saúde e loot")
	restored.collect_loot(first["id"])
	restored.take_damage(1000.0)
	stock = restored.supplies
	check(not restored.use_supplies() and restored.supplies == stock and is_zero_approx(restored.health), "Suprimentos não ressuscitam jogador derrotado")
	check(not restored.collect_loot(second["id"]), "Missão encerrada impede nova coleta")
	restored.start_new()
	check(restored.supplies == 0 and restored.looted_ids.is_empty() and is_equal_approx(restored.health, 100.0), "Nova tentativa limpa inventário e libera recipientes")
	restored.supplies = 1
	restored.health = 50.0
	restored.outcome = "timed_out"
	check(not restored.use_supplies(), "Prazo encerrado também impede cura")
	clean_save(MODEL_SAVE)


func _quiet_enemies(game: Node3D) -> void:
	for enemy: CharacterBody3D in game.enemies:
		enemy.set_active(false)


func _wall(parent: Node3D, at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = at
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.5, 0.15)
	collider.shape = box
	wall.add_child(collider)
	parent.add_child(wall)
	return wall


func _dispatch_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)


func _dispatch_emulated_mouse(at: Vector2, pressed: bool) -> void:
	# Alguns aparelhos enviam também mouse sintético após um toque nativo.
	# Ele não pode aplicar um segundo curativo.
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)


func _test_heal_input(game: Node3D) -> void:
	# A parte inferior de CURAR se sobrepõe à região livre do joystick. O toque
	# precisa chegar ao Button e não pode deslocar o personagem acidentalmente.
	var lower_corner: Vector2 = game.supplies_button.get_global_transform_with_canvas() * (game.supplies_button.size - Vector2(12, 8))
	_dispatch_touch(81, lower_corner, true)
	await settle(1)
	check(game.controls.move_vector.is_zero_approx() and game.controls._joystick_finger == -1, "Toque no canto inferior de CURAR não captura o joystick")
	_dispatch_touch(81, lower_corner, false)
	await settle(1)
	check(is_equal_approx(game.mission.health, 90.0) and game.mission.supplies == 0, "Toque nativo completo em CURAR recupera vida e consome um único item")
	check(game.controls.move_vector.is_zero_approx() and game.controls._joystick_finger == -1, "Soltar CURAR deixa o joystick inativo")
	game.mission.health = 40.0
	game.mission.supplies = 2
	game._update_hud()
	var joystick_at: Vector2 = game.controls.get_global_transform_with_canvas() * (Vector2(160, game.controls.size.y - 160) + Vector2(0, -55))
	_dispatch_touch(82, joystick_at, true)
	await settle(1)
	var moving: Vector2 = game.controls.move_vector
	check(moving.length() > 0.5 and game.controls._joystick_finger == 82, "Outro dedo mantém movimento no joystick")
	_dispatch_touch(83, lower_corner, true)
	await settle(1)
	check(game.controls.move_vector.is_equal_approx(moving) and game.controls._joystick_finger == 82, "Toque em CURAR preserva o dedo independente no joystick")
	check(is_equal_approx(game.mission.health, 75.0) and game.mission.supplies == 1, "Segundo dedo usa CURAR enquanto o primeiro mantém o movimento")
	_dispatch_touch(83, lower_corner, true)
	_dispatch_emulated_mouse(lower_corner, true)
	_dispatch_emulated_mouse(lower_corner, false)
	await settle(1)
	check(is_equal_approx(game.mission.health, 75.0) and game.mission.supplies == 1, "Pressão repetida e mouse emulado não aplicam curativo duplicado")
	_dispatch_touch(83, lower_corner, false)
	await settle(1)
	check(game.controls.move_vector.is_equal_approx(moving) and game.controls._joystick_finger == 82, "Soltar CURAR não solta o dedo do joystick")
	_dispatch_touch(82, joystick_at, false)
	await settle(1)
	check(game.controls.move_vector.is_zero_approx() and game.controls._joystick_finger == -1, "Soltar o dedo do joystick encerra o movimento")


func _test_scene() -> void:
	var scene: PackedScene = load("res://scenes/third_person.tscn")
	var game: Node3D = scene.instantiate()
	game.mission.save_path = SCENE_SAVE
	game.graphics_settings_path = "user://test_loot_graphics.cfg"
	clean_save(SCENE_SAVE)
	root.add_child(game)
	await settle()
	game.start_mission()
	await settle()
	_quiet_enemies(game)
	game.player.set_physics_process(false)
	check(game.world.houses.size() == 2, "Aurora inclui duas casas exploráveis")
	check(game.scavenge.cars.size() == 3 and game.scavenge.bodies.size() == 3, "Ruas incluem três carros e três corpos")
	check(game.scavenge.loot_points.size() == Loot.POINTS.size(), "Todos os pontos de loot estão presentes no cenário")
	game.player.reset_player(Vector3(0, 0.1, 30))
	game.player.set_physics_process(false)
	game.interact()
	check(game.mission.supplies == 0, "Interagir longe não recolhe suprimentos")
	var car_point: Vector3 = Vector3(2.8, 0, 20.8)
	game.player.reset_player(car_point + Vector3(0, 0.1, 1.4))
	game.player.set_physics_process(false)
	await settle()
	var target: Dictionary = game._interaction_target()
	check(target.get("kind") == "loot" and target.get("point", {}).get("id") == "car_praca", "Botão identifica o porta-malas perto do jogador")
	game.controls.interacted.emit()
	check("car_praca" in game.mission.looted_ids and game.mission.supplies == 1, "Botão real de ação recolhe o porta-malas")
	var stock: int = game.mission.supplies
	game.interact()
	check(game.mission.supplies == stock, "Segundo toque não duplica o conteúdo do porta-malas")
	check(not game.scavenge.get_node("Loot_car_praca").visible, "Marca de loot desaparece no recipiente esvaziado")
	game.mission.health = 55.0
	game._update_hud()
	check(not game.supplies_button.disabled, "CURAR fica disponível quando há item e ferimento")
	await _test_heal_input(game)
	game.mission.supplies = 1
	var health_before_pause: float = game.mission.health
	game.pause_mission()
	game.use_supplies()
	check(game.mission.supplies == 1 and is_equal_approx(game.mission.health, health_before_pause), "Pausa impede uso de suprimentos por eventos atrasados")
	game.resume_mission()
	_quiet_enemies(game)
	game.player.set_physics_process(false)
	# Um corpo próximo também exige linha livre: não se revista através da parede.
	var body_point: Vector3 = Vector3(-8, 0, -6)
	game.player.reset_player(body_point + Vector3(0, 0.1, 1.5))
	game.player.set_physics_process(false)
	var wall: StaticBody3D = _wall(game, body_point + Vector3(0, 1.25, 0.75))
	await settle()
	game.interact()
	check("body_radio" not in game.mission.looted_ids, "Parede bloqueia a coleta de um corpo próximo")
	wall.queue_free()
	await settle()
	game.interact()
	check("body_radio" in game.mission.looted_ids and game.mission.supplies == 2, "Sem parede o mesmo corpo fornece suprimentos")
	game.show_home()
	await settle()
	game.continue_mission()
	await settle()
	_quiet_enemies(game)
	game.player.set_physics_process(false)
	check(game.mission.supplies == 2 and "car_praca" in game.mission.looted_ids and "body_radio" in game.mission.looted_ids, "Continuar restaura inventário e loot dos corpos/carros")
	check(not game.scavenge.get_node("Loot_car_praca").visible and not game.scavenge.get_node("Loot_body_radio").visible, "Reconstruir cenário mantém os recipientes esvaziados")
	for data: Dictionary in game.world.houses:
		var center: Vector3 = data["center"]
		var entrance: Vector3 = data["entrance"]
		var side: float = signf(entrance.x - center.x)
		game.player.reset_player(entrance + Vector3(side * 1.2, 0.1, 0))
		game.player.set_physics_process(false)
		await settle()
		var collision: KinematicCollision3D = game.player.move_and_collide(Vector3(-side * 3.0, 0, 0))
		check(collision == null and absf(game.player.global_position.x - center.x) < absf(entrance.x - center.x), "Porta aberta permite entrada física na casa " + String(data["id"]))
		game.world.set_viewer_position(center)
		check(data["node"].cutaway_active, "Telhado revela os cômodos ao se aproximar: " + String(data["id"]))
		game.player.reset_player(center + Vector3(0, 0.1, -data["node"].dimensions.y * 0.5 - 1.0))
		game.player.set_physics_process(false)
		await settle()
		check(game.player.test_move(game.player.global_transform, Vector3(0, 0, 2.0)), "Corte visual preserva as paredes físicas: " + String(data["id"]))
		game.world.set_viewer_position(Vector3.ZERO)
		check(not data["node"].cutaway_active, "Telhado retorna ao sair da casa " + String(data["id"]))
	# O móvel da casa também pode ser revistado de dentro, sem disputar o diálogo.
	game.player.reset_player(Vector3(-22, 0.1, 19.2))
	game.player.set_physics_process(false)
	await settle()
	game.interact()
	check("house_left_cupboard" in game.mission.looted_ids, "Interior tem loot alcançável no armário")
	game.start_mission()
	await settle()
	check(game.mission.supplies == 0 and game.mission.looted_ids.is_empty() and game.scavenge.get_node("Loot_car_praca").visible, "Nova missão repõe os recipientes com inventário vazio")
	game.queue_free()
	await settle()
	clean_save(SCENE_SAVE)
	if FileAccess.file_exists("user://test_loot_graphics.cfg"):
		DirAccess.remove_absolute("user://test_loot_graphics.cfg")


func _run() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func() -> void:
		printerr("FALHOU: validação de exploração excedeu o prazo.")
		quit(1)
	)
	_test_model()
	if not OS.get_cmdline_user_args().has("--model-only"):
		await _test_scene()
	clean_save(MODEL_SAVE)
	clean_save(SCENE_SAVE)
	print("Exploração e loot: %d verificações, %d falhas." % [checks, failures])
	quit(0 if failures == 0 else 1)
