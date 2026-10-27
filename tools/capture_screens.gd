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
		game.player.reset_player(point["position"] + Vector3(0, 0.1, 1.5))
		game.interact()
	game.player.reset_player(game.world.tower_point + Vector3(0, 0.1, 2))
	game.interact()
	await capture("06-transmissao.png")
	_cleanup()
	game.queue_free()
	await process_frame
	quit(0)


func _cleanup() -> void:
	for suffix: String in ["", ".tmp"]:
		var path: String = "user://screenshot_3d_save.json" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
