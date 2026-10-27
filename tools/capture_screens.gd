extends SceneTree
## Captura visual opcional: exige uma sessão gráfica, nunca um navegador.
const MAIN = preload("res://scenes/third_person.tscn")
var game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func capture(filename: String) -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("res://builds/screenshots/" + filename)
	if result != OK:
		printerr("Falha ao capturar: " + filename)
		quit(1)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/screenshots")
	game = MAIN.instantiate()
	game.mission.save_path = "user://screenshot_3d_save.json"
	_cleanup()
	root.add_child(game)
	await capture("01-inicio-3d.png")
	game.start_mission()
	await capture("02-terceira-pessoa.png")
	var lia: Node3D = game.citizens[0]
	game.player.reset_player(lia.global_position + Vector3(0, 0.1, 1.8))
	game.begin_dialogue(lia)
	await capture("03-dialogo-lia.png")
	while game.phase == "dialogue":
		game.advance_dialogue()
	for guard: Node3D in game.enemies:
		guard.set_active(false)
	var opponent: Node3D = game.enemies[0]
	opponent.set_active(true)
	game.player.reset_player(opponent.global_position + Vector3(0, 0.1, -1.5))
	game.player.visual.rotation.y = PI
	game.attack()
	await capture("04-combate.png")
	opponent.set_active(false)
	game.player.reset_player(Vector3(0, 0.1, 10))
	game.player.add_camera_look(Vector2(100, -25))
	game.controls.move_vector = Vector2(0, -1)
	for frame in range(30):
		await physics_frame
	game.controls.reset_controls()
	await capture("03-exploracao.png")
	var first: Dictionary = game.world.evidence_points[0]
	game.player.reset_player(first["position"] + Vector3(0, 0.1, 2))
	await capture("04-recolher-prova.png")
	game.interact()
	await capture("05-prova-recolhida.png")
	for point: Dictionary in game.world.evidence_points:
		if point["id"] in game.mission.collected:
			continue
		game.player.reset_player(point["position"] + Vector3(0, 0.1, 1.5))
		game.interact()
	game.player.reset_player(game.world.tower_point + Vector3(0, 0.1, 2))
	game.interact()
	if game.mission.outcome != "transmitted":
		printerr("A captura da missão não chegou à transmissão.")
		_cleanup()
		quit(1)
		return
	await capture("06-transmissao.png")
	# Inspeção do figurino dos personagens reais do jogo, sem alterar o save.
	game.hud.visible = false
	game.controls.visible = false
	game.result_panel.visible = false
	game.dialogue_panel.visible = false
	game.home_panel.visible = false
	game.pause_panel.visible = false
	game.player.visible = false
	for index in range(game.enemies.size()):
		var enemy: Node3D = game.enemies[index]
		enemy.set_active(false)
		enemy.position = Vector3(-1.6 + index * 1.6, 0.1, 5)
		enemy.visual.rotation = Vector3.ZERO
		enemy._update_visual(0.0)
	var wardrobe_camera: Camera3D = Camera3D.new()
	game.add_child(wardrobe_camera)
	wardrobe_camera.position = Vector3(0, 2.0, -0.5)
	wardrobe_camera.fov = 44.0
	wardrobe_camera.look_at(Vector3(0, 1.05, 5))
	wardrobe_camera.current = true
	await capture("07-zumbis.png")
	_cleanup()
	game.queue_free()
	await process_frame
	quit(0)


func _cleanup() -> void:
	for suffix: String in ["", ".tmp"]:
		var path: String = "user://screenshot_3d_save.json" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
