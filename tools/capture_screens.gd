extends SceneTree
## Captura visual opcional: exige uma sessão gráfica, nunca um navegador.
const MAIN = preload("res://scenes/main.tscn")
var ui: Control


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
	ui = MAIN.instantiate()
	ui.game.save_path = "user://screenshot_test_save.json"
	ui.game.wipe_save()
	root.add_child(ui)
	await capture("01-inicio.png")
	ui.start_game()
	await capture("02-primeiro-capitulo.png")
	ui.game_screen.scroll_vertical = 10000
	await capture("03-escolhas.png")
	ui.choose_option(1)
	await capture("04-consequencia.png")
	while not ui.game.is_finished():
		ui.choose_option(1)
	await capture("05-final.png")
	ui.game.wipe_save()
	ui.queue_free()
	await process_frame
	quit(0)
