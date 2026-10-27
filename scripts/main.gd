extends Control
## Interface nativa para toque. Nenhuma tela usa HTML, WebView ou serviços remotos.

const Game = preload("res://scripts/story_game.gd")
const TITLE_FONT = preload("res://assets/fonts/DejaVuSerif.ttf")
const TITLE_BOLD = preload("res://assets/fonts/DejaVuSerif-Bold.ttf")
const CITY = preload("res://assets/aurora.svg")
const BG = Color("102833")
const PANEL = Color("193640")
const INK = Color("f2ead8")
const MUTED = Color("a8bbba")
const GOLD = Color("d6a565")
const GREEN = Color("8bb7a4")
const RED = Color("db9987")

var game = Game.new()
var current_screen: String = "home"
var last_feedback: String = ""
var page_margin: MarginContainer
var home_screen: ScrollContainer
var game_screen: ScrollContainer
var ending_screen: ScrollContainer
var home_content: VBoxContainer
var game_content: VBoxContainer
var ending_content: VBoxContainer
var continue_button: Button
var start_button: Button
var home_error: Label
var restart_dialog: ConfirmationDialog
var exit_dialog: ConfirmationDialog


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_theme()
	var backdrop = ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	page_margin = MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_margin)
	var stack = Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_margin.add_child(stack)
	home_screen = _screen("HomeScreen", stack)
	game_screen = _screen("GameScreen", stack)
	ending_screen = _screen("EndingScreen", stack)
	home_content = _column(home_screen, 16)
	game_content = _column(game_screen, 20)
	ending_content = _column(ending_screen, 20)
	_build_home()
	_build_dialogs()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	show_home()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if restart_dialog != null and restart_dialog.visible:
			restart_dialog.hide()
		elif exit_dialog != null and exit_dialog.visible:
			exit_dialog.hide()
		elif current_screen != "home":
			show_home()
		elif exit_dialog != null:
			if not game.last_save_ok:
				exit_dialog.dialog_text = "Não foi possível salvar as últimas escolhas.\nSe sair agora, elas podem se perder."
			elif game.has_save():
				exit_dialog.dialog_text = "Seu progresso está salvo neste aparelho."
			else:
				exit_dialog.dialog_text = "Você pode voltar quando quiser."
			exit_dialog.popup_centered(Vector2i(450, 220))


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", BG)
	theme.set_stylebox("normal", "Button", _style(PANEL, Color("38515a"), 12))
	theme.set_stylebox("hover", "Button", _style(Color("254550"), GOLD, 12))
	theme.set_stylebox("pressed", "Button", _style(GOLD, GOLD, 12))
	var focus = _style(Color.TRANSPARENT, INK, 12)
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("panel", "AcceptDialog", _style(BG, GOLD, 14))
	theme.set_color("font_color", "AcceptDialog", INK)
	theme.set_color("title_color", "Window", INK)
	theme.set_color("font_color", "CheckButton", INK)


func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _screen(node_name: String, parent: Node) -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.name = node_name
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(scroll)
	return scroll


func _column(parent: Node, gap: int = 12) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column


func _label(text: String, font_size: int = 19, color: Color = INK, serif: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", TITLE_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _eyebrow(text: String) -> Label:
	var label = _label(text, 13, GOLD)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _rule(parent: Node) -> void:
	var line = ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color("38515a")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _button(text: String, node_name: String, action: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 62
	button.add_theme_font_size_override("font_size", 19)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal", _style(GOLD, GOLD, 10))
		button.add_theme_stylebox_override("hover", _style(Color("e8bd83"), INK, 10))
		button.add_theme_stylebox_override("pressed", _style(Color("bd8c52"), GOLD, 10))
		button.add_theme_color_override("font_color", BG)
		button.add_theme_color_override("font_hover_color", BG)
		button.add_theme_color_override("font_focus_color", BG)
	button.pressed.connect(action)
	return button


func _build_home() -> void:
	home_content.add_child(_eyebrow("UM JOGO DE ESCOLHAS"))
	var title = _label("O ÚLTIMO DIA\nDA DEMOCRACIA", 43, INK, true)
	title.add_theme_font_override("font", TITLE_BOLD)
	title.add_theme_constant_override("line_spacing", 5)
	home_content.add_child(title)
	home_content.add_child(_label("Uma noite. Muitas escolhas.\nO amanhã ainda está em suas mãos.", 20, MUTED))
	var art = TextureRect.new()
	art.name = "AuroraSkyline"
	art.texture = CITY
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y = 238
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_content.add_child(art)
	home_content.add_child(_eyebrow("A ÚLTIMA EDIÇÃO NÃO PODE ESPERAR"))
	home_content.add_child(_label("As luzes da cidade se apagam. Na redação, uma última denúncia chega até você. Preserve as provas, encontre aliados e decida o que merece chegar à primeira página.", 19, INK))
	continue_button = _button("Continuar história   →", "ContinueButton", continue_game, true)
	home_content.add_child(continue_button)
	start_button = _button("Começar história   →", "StartButton", _request_new_game, true)
	home_content.add_child(start_button)
	home_error = _label("", 15, RED)
	home_error.visible = false
	home_content.add_child(home_error)
	_rule(home_content)
	home_content.add_child(_label("8 CAPÍTULOS  ·  JOGUE OFFLINE  ·  NO SEU RITMO", 12, GOLD))
	home_content.add_child(_label("Uma narrativa de ficção. Lugares, pessoas e acontecimentos são imaginários. Contém temas de tensão política e ameaças, sem violência gráfica.", 13, MUTED))


func _build_dialogs() -> void:
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.name = "RestartDialog"
	restart_dialog.title = "Começar uma nova história?"
	restart_dialog.dialog_text = "O progresso desta história será substituído.\nSuas escolhas atuais não poderão ser recuperadas."
	restart_dialog.get_ok_button().text = "Recomeçar"
	restart_dialog.get_cancel_button().text = "Voltar"
	restart_dialog.confirmed.connect(start_game)
	add_child(restart_dialog)
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.name = "ExitDialog"
	exit_dialog.title = "Sair do jogo?"
	exit_dialog.dialog_text = "Seu progresso está salvo neste aparelho."
	exit_dialog.get_ok_button().text = "Sair"
	exit_dialog.get_cancel_button().text = "Ficar"
	exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	add_child(exit_dialog)


func _apply_safe_area() -> void:
	if page_margin == null:
		return
	var top = 26
	var bottom = 24
	var left = 26
	var right = 26
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var screen_size = DisplayServer.screen_get_size()
		var view_size = get_viewport_rect().size
		if screen_size.x > 0 and screen_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var scale_x = view_size.x / float(screen_size.x)
			var scale_y = view_size.y / float(screen_size.y)
			top += int(safe.position.y * scale_y)
			bottom += int((screen_size.y - safe.end.y) * scale_y)
			left += int(safe.position.x * scale_x)
			right += int((screen_size.x - safe.end.x) * scale_x)
	page_margin.add_theme_constant_override("margin_top", top)
	page_margin.add_theme_constant_override("margin_bottom", bottom)
	page_margin.add_theme_constant_override("margin_left", left)
	page_margin.add_theme_constant_override("margin_right", right)


func _activate(screen_name: String) -> void:
	current_screen = screen_name
	home_screen.visible = screen_name == "home"
	game_screen.visible = screen_name == "game"
	ending_screen.visible = screen_name == "ending"


func show_home() -> void:
	_activate("home")
	var saved: bool = game.has_save()
	continue_button.visible = saved
	start_button.text = "Nova história" if saved else "Começar história   →"
	home_error.visible = not game.last_save_ok
	if not game.last_save_ok:
		home_error.text = "Não foi possível salvar as últimas escolhas. Evite sair do jogo se quiser preservar esta sessão."
	home_screen.scroll_vertical = 0


func _request_new_game() -> void:
	if game.has_save():
		restart_dialog.popup_centered(Vector2i(450, 250))
	else:
		start_game()


func start_game() -> void:
	game.start_new()
	last_feedback = ""
	refresh_game()


func continue_game() -> void:
	if not game.load_game():
		home_error.text = "Não foi possível abrir o progresso salvo. Você pode começar uma nova história."
		home_error.visible = true
		return
	last_feedback = ""
	if game.is_finished():
		show_ending()
	else:
		refresh_game()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _navigation(parent: Node, right_text: String) -> void:
	var bar = HBoxContainer.new()
	var back = _button("‹  Menu", "MenuButton", show_home)
	back.custom_minimum_size = Vector2(108, 50)
	back.add_theme_font_size_override("font_size", 16)
	bar.add_child(back)
	var caption = _label(right_text, 13, MUTED)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(caption)
	parent.add_child(bar)


func _stats_row(parent: Node) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for key in ["voz", "provas", "risco"]:
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _style(PANEL, Color.TRANSPARENT, 10))
		var box = _column(panel, 7)
		var value: int = int(game.stats.get(key, 0))
		var color = RED if key == "risco" else GOLD
		box.add_child(_label(String(key).to_upper(), 12, MUTED))
		var number = _label(str(value), 25, color)
		number.name = "Stat" + String(key).capitalize()
		box.add_child(number)
		var meter = ProgressBar.new()
		meter.custom_minimum_size.y = 4
		meter.show_percentage = false
		meter.value = value
		var meter_background = StyleBoxFlat.new()
		meter_background.bg_color = Color("0c222b")
		var meter_fill = StyleBoxFlat.new()
		meter_fill.bg_color = color
		meter.add_theme_stylebox_override("background", meter_background)
		meter.add_theme_stylebox_override("fill", meter_fill)
		box.add_child(meter)
		row.add_child(panel)
	parent.add_child(row)


func refresh_game() -> void:
	if game.is_finished():
		show_ending()
		return
	_activate("game")
	_clear(game_content)
	var card: Dictionary = game.get_card()
	_navigation(game_content, "CAPÍTULO %02d / 08" % (game.step + 1))
	var progress = HBoxContainer.new()
	progress.add_theme_constant_override("separation", 5)
	for index in range(8):
		var segment = ColorRect.new()
		segment.custom_minimum_size.y = 3
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.color = GOLD if index <= game.step else Color("38515a")
		progress.add_child(segment)
	game_content.add_child(progress)
	var time_bar = HBoxContainer.new()
	var time_label = _label(String(card.get("time", "")), 38, GOLD, true)
	time_label.name = "StoryTime"
	time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_label.custom_minimum_size.x = 135
	time_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	time_bar.add_child(time_label)
	var time_caption = _label("ATÉ A ÚLTIMA EDIÇÃO", 11, MUTED)
	time_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_bar.add_child(time_caption)
	game_content.add_child(time_bar)
	_stats_row(game_content)
	game_content.add_child(_label("Voz aproxima aliados. Provas sustentam a verdade.\nRisco mede o perigo ao seu redor.", 13, MUTED))
	if not last_feedback.is_empty():
		var feedback = PanelContainer.new()
		feedback.name = "ChoiceFeedback"
		feedback.add_theme_stylebox_override("panel", _style(Color("203e43"), Color("3e615e"), 10))
		feedback.add_child(_label(last_feedback, 14, GREEN))
		game_content.add_child(feedback)
	_rule(game_content)
	game_content.add_child(_eyebrow("A DECISÃO É SUA"))
	var chapter_title = _label(String(card.get("title", "")), 30, INK, true)
	chapter_title.name = "ChapterTitle"
	game_content.add_child(chapter_title)
	var story = _label(String(card.get("body", "")), 20)
	story.name = "StoryBody"
	story.add_theme_constant_override("line_spacing", 5)
	game_content.add_child(story)
	var consequence: String = String(card.get("consequence", ""))
	if not consequence.is_empty():
		game_content.add_child(_label(consequence, 17, GREEN, true))
	var choices: Array = card.get("choices", [])
	for index in range(choices.size()):
		game_content.add_child(_choice_button(choices[index], index))
	if game.last_save_ok:
		game_content.add_child(_label("Cada escolha deixa uma marca. Seu progresso é salvo automaticamente.", 12, MUTED))
	else:
		game_content.add_child(_label("Não foi possível salvar neste aparelho. Você pode continuar jogando, mas o progresso desta sessão pode se perder ao sair.", 14, RED))
	game_screen.scroll_vertical = 0


func _choice_button(choice: Dictionary, index: int) -> Button:
	var button = _button("", "Choice%d" % index, choose_option.bind(index))
	button.custom_minimum_size.y = 116
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 19)
	margin.add_theme_constant_override("margin_right", 19)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	var box = _column(margin, 7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title = _label(String(choice.get("label", "")), 19, INK)
	box.add_child(title)
	var hint = _label(String(choice.get("hint", "")), 13, MUTED)
	box.add_child(hint)
	button.add_child(margin)
	# Wait for wrapped labels to get their real width before fitting the touch area.
	# A resize callback alone can retain the provisional one-letter-per-line height.
	box.minimum_size_changed.connect(func() -> void: _fit_choice.call_deferred(button, box))
	button.resized.connect(func() -> void: _fit_choice.call_deferred(button, box))
	return button


func _fit_choice(button: Button, box: VBoxContainer) -> void:
	if is_instance_valid(button) and is_instance_valid(box):
		button.custom_minimum_size.y = maxf(104.0, box.get_combined_minimum_size().y + 30.0)


func choose_option(index: int) -> void:
	var card: Dictionary = game.get_card()
	var choices: Array = card.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if not game.choose(index):
		return
	var changes: Array[String] = []
	var effects: Dictionary = choice.get("effects", {})
	for key in ["voz", "provas", "risco"]:
		var delta: int = int(effects.get(key, 0))
		if delta != 0:
			changes.append("%s %s%d" % [String(key).capitalize(), "+" if delta > 0 else "", delta])
	last_feedback = "Sua decisão: %s\n%s" % [String(choice.get("label", "")), "   ·   ".join(changes)]
	refresh_game()


func show_ending() -> void:
	_activate("ending")
	_clear(ending_content)
	var ending: Dictionary = game.get_ending()
	_navigation(ending_content, "MEIA-NOITE · EPÍLOGO")
	ending_content.add_child(_eyebrow("A CIDADE DESPERTARÁ DIFERENTE"))
	var title = _label(String(ending.get("title", "O dia seguinte")), 36, INK, true)
	title.name = "EndingTitle"
	ending_content.add_child(title)
	_rule(ending_content)
	_stats_row(ending_content)
	var body = _label(String(ending.get("body", "")), 21)
	body.add_theme_constant_override("line_spacing", 5)
	ending_content.add_child(body)
	ending_content.add_child(_label(String(ending.get("epilogue", "")), 18, MUTED, true))
	if not game.last_save_ok:
		ending_content.add_child(_label("Não foi possível salvar o desfecho neste aparelho. Leia seu final antes de sair.", 14, RED))
	ending_content.add_child(_button("Viver outra história   ↺", "ReplayButton", _request_new_game, true))
	ending_content.add_child(_button("Voltar ao início", "EndingHomeButton", show_home))
	_rule(ending_content)
	ending_content.add_child(_eyebrow("AS ESCOLHAS QUE TROUXERAM VOCÊ ATÉ AQUI"))
	for index in range(game.history.size()):
		var decision: Dictionary = game.history[index]
		var box = _column(ending_content, 5)
		box.add_child(_label("%02d  %s" % [index + 1, String(decision.get("title", ""))], 14, GOLD))
		box.add_child(_label(String(decision.get("label", "")), 16, MUTED))
	ending_content.add_child(_label("Nenhum destino é inevitável. Outras escolhas podem abrir outros caminhos.", 14, GOLD, true))
	ending_screen.scroll_vertical = 0
