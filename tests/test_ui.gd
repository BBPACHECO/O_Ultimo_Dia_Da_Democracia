extends SceneTree
## Exercita sinais dos controles reais da cena, sem tocar no progresso do jogador.

const MAIN = preload("res://scenes/main.tscn")
const SAVE = "user://test_ui_save.json"
var checks: int = 0
var failures: int = 0
var ui: Control


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FALHOU: " + message)


func settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func press(node_name: String) -> void:
	var button = ui.find_child(node_name, true, false)
	check(button is Button, "Controle existe: " + node_name)
	if button is Button:
		check(button.is_visible_in_tree(), "Controle visível: " + node_name)
		button.pressed.emit()
	await settle()


func _run() -> void:
	ui = MAIN.instantiate()
	ui.game.save_path = SAVE
	ui.game.wipe_save()
	root.add_child(ui)
	await settle()
	check(ui.current_screen == "home", "Inicialização na tela inicial")
	check(not ui.continue_button.visible, "Sem continuar antes do primeiro jogo")
	await press("StartButton")
	check(ui.current_screen == "game" and ui.game.step == 0, "Início abre o primeiro capítulo")
	var clock = ui.find_child("StoryTime", true, false)
	check(clock != null and clock.size.y < 80, "Horário legível em uma única linha")
	for meter in ui.game_content.find_children("*", "ProgressBar", true, false):
		check(meter.size.y <= 8, "Medidores compactos sem margens de cartão")
	for index in range(3):
		var choice = ui.find_child("Choice%d" % index, true, false)
		check(choice != null and choice.custom_minimum_size.y >= 48, "Escolha com área de toque: %d" % index)
	await press("Choice0")
	check(ui.game.step == 1 and ui.game.history.size() == 1, "Sinal da escolha avança e registra decisão")
	check(ui.find_child("ChoiceFeedback", true, false) != null, "Consequência visível")
	var before: Dictionary = ui.game.stats.duplicate()
	await press("MenuButton")
	check(ui.current_screen == "home" and ui.continue_button.visible, "Menu oferece continuar")
	await press("ContinueButton")
	check(ui.game.step == 1 and ui.game.stats == before, "Continuar restaura capítulo e indicadores")
	ui.notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(ui.current_screen == "home", "Voltar do Android abre menu sem perder progresso")
	await press("StartButton")
	check(ui.restart_dialog.visible and ui.game.step == 1, "Nova história exige confirmação")
	ui.notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(not ui.restart_dialog.visible and ui.game.step == 1, "Voltar cancela reinício sem apagar")
	await press("ContinueButton")
	while not ui.game.is_finished():
		var previous: int = ui.game.step
		await press("Choice1")
		check(ui.game.step == previous + 1, "Capítulo avança uma vez por toque")
		if ui.game.step == previous:
			break
	check(ui.current_screen == "ending", "Última decisão abre final")
	var ending = ui.find_child("EndingTitle", true, false)
	check(ending != null and not ending.text.is_empty(), "Final apresenta título")
	check(ui.game.history.size() == 8, "Histórico contém oito decisões")
	await press("EndingHomeButton")
	await press("ContinueButton")
	check(ui.current_screen == "ending", "Continuar jogo concluído restaura epílogo")
	await press("ReplayButton")
	check(ui.restart_dialog.visible, "Rejogar pede confirmação")
	ui.restart_dialog.confirmed.emit()
	ui.restart_dialog.hide()
	await settle()
	check(ui.current_screen == "game" and ui.game.step == 0, "Reinício confirmado limpa a partida")
	check(ui.game.history.is_empty(), "Nova partida sem decisões antigas")
	ui.game.wipe_save()
	ui.queue_free()
	await settle()
	print("Interface nativa: %d verificações, %d falhas." % [checks, failures])
	quit(0 if failures == 0 else 1)
