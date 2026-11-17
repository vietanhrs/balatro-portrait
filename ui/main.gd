extends Control
## Rendering and input only. All gameplay transactions belong to GameEngine.
signal back_requested
signal safe_area_changed(insets: Vector4)
const FELT = Color("176b59")
const PANEL = Color("263d40")
const CREAM = Color("fff1d2")
const GOLD = Color("f49a24")
const BLUE = Color("168be5")
const RED = Color("e94f45")
const CardView = preload("res://ui/table_card.gd")
var animating := false
var reduced_motion := false
var fast_motion := false
var presentation_token := 0
var snapshot: Dictionary = {}
var run_mode := "practice"
var pack_choice := -1
var targeting_pack := false
var target_required := 1
var engine: Script
var saves: Script
var state: Dictionary = {}
var selected: Array = []
var sorted_ids: Array = []
var screen := "menu"
var overlay: Control
var body: VBoxContainer
var footer: HBoxContainer
var frame: MarginContainer
var seed_input: LineEdit
var notice := ""
var event_lines: Array = []
var sort_suit := false
var save_failed := false
var target_index := -1
var target_ids: Array = []
var menu_resume := false
const Profile = preload("res://ui/profile_store.gd")
var profile: Dictionary = {}
var seeded_check: CheckBox
var background_material: ShaderMaterial
var table: Control
var cards: Dictionary = {}
var score_labels: Dictionary = {}
var score_panels: Dictionary = {}
var round_label: Label
var category_label: Label
var counts_label: Label
var play_button: Button
var discard_button: Button
var skip_button: Button
var motion_tweens: Array[Tween] = []
var played_ids: Array = []
var after_snapshot: Dictionary = {}
var dispatch_count := 0
var last_random_seed := 0
var selection_tweens: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	# UI units are phone dp, independent of export viewport defaults.
	get_window().content_scale_size = Vector2i(360, 640)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if ResourceLoader.exists("res://core/game_engine.gd"):
		engine = load("res://core/game_engine.gd")
	if ResourceLoader.exists("res://platform/save_store.gd"):
		saves = load("res://platform/save_store.gd")
	profile = Profile.read_profile()
	reduced_motion = bool(profile.get("settings", {}).get("reduced_motion", false))
	fast_motion = bool(profile.get("settings", {}).get("fast_motion", false))
	var background := ColorRect.new()
	background.color = FELT
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var texture_path := "res://assets/v3/background.png"
	if ResourceLoader.exists(texture_path):
		var art := TextureRect.new()
		art.texture = load(texture_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_material = ShaderMaterial.new()
		background_material.shader = preload("res://ui/felt.gdshader")
		background_material.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)
		art.material = background_material
		add_child(art)
	theme = Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(style_name, "Button", _style(PANEL if style_name != "pressed" else Color("306265"), GOLD if style_name == "focus" else Color("397070"), 8))
	frame = MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()
	_render()

func _style(fill: Color, border: Color, radius: int = 8) -> StyleBox:
	var path := "res://assets/v3/button.png" if fill == GOLD else "res://assets/v3/panel.png"
	if ResourceLoader.exists(path):
		var skin := StyleBoxTexture.new()
		skin.texture = load(path)
		if fill == BLUE: skin.modulate_color = Color(0.35, 1.4, 2.8)
		elif fill == RED: skin.modulate_color = Color(3.0, 0.65, 0.65)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			skin.set_texture_margin(side, 20)
			skin.set_content_margin(side, 6 if side in [SIDE_TOP, SIDE_BOTTOM] else 10)
		return skin
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _safe_area() -> void:
	var inset := Vector4(12, 8, 12, 8)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var physical := DisplayServer.window_get_size()
		var logical := get_viewport_rect().size
		if physical.x > 0 and physical.y > 0 and safe.size.x > 0:
			inset.x = maxf(12, safe.position.x * logical.x / physical.x)
			inset.y = maxf(8, safe.position.y * logical.y / physical.y)
			inset.z = maxf(12, (physical.x - safe.end.x) * logical.x / physical.x)
			inset.w = maxf(8, (physical.y - safe.end.y) * logical.y / physical.y)
	frame.add_theme_constant_override("margin_left", int(inset.x))
	frame.add_theme_constant_override("margin_top", int(inset.y))
	frame.add_theme_constant_override("margin_right", int(inset.z))
	frame.add_theme_constant_override("margin_bottom", int(inset.w))
	safe_area_changed.emit(inset)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_back()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED and not state.is_empty():
		_save()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _back() -> void:
	back_requested.emit()
	if animating:
		_finish_animation()
		return
	if is_instance_valid(overlay):
		_close_overlay()
	elif screen != "menu":
		screen = "menu"
		_render()
	else:
		var box := _modal("Leave the circuit?")
		_label(box, "Your last successful action is saved.")
		_button(box, "Keep playing", _close_overlay)
		_button(box, "Exit", func(): get_tree().quit())

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _render() -> void:
	if animating: return
	cards.clear()
	table = null
	_clear(frame)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	frame.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	_label(top, "" if screen == "menu" else "A%s · %s" % [state.get("ante", 1), str(state.get("mode", "practice")).capitalize()], 16)
	if screen != "menu": _label(top, "$%s" % state.get("money", 0), 24, GOLD)
	_button(top, "☰", _settings, 48).size_flags_horizontal = Control.SIZE_SHRINK_END
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	layout.add_child(body)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	layout.add_child(footer)
	if screen == "menu":
		_menu()
		return
	if state.is_empty():
		screen = "menu"
		_render()
		return
	match str(state.get("phase", "")):
		"playing": _hud(); _playing()
		"blind_select": _blind()
		"shop": _loadout(); _shop()
		"cashout": _receipt()
		"pack_select": _pack()
		"won", "lost": _terminal()
		_: _label(body, "Unknown run phase. Return to menu.")
	if not notice.is_empty(): _label(body, notice, 14, CREAM)
	if save_failed: _label(body, "Save unavailable — keep this run open.", 14, CREAM)

func _settings() -> void:
	var box := _modal("Settings")
	_button(box, "Reduced motion: " + ("on" if reduced_motion else "off"), func(): reduced_motion = not reduced_motion; _save_preferences(); _settings())
	_button(box, "Fast scoring: " + ("on" if fast_motion else "off"), func(): fast_motion = not fast_motion; _save_preferences(); _settings())
	_button(box, "How to play", _help)
	_button(box, "About", func(): _label(_modal("About"), "An independent, original poker roguelike."))
	if screen != "menu": _button(box, "Save & menu", func(): _close_overlay(); _finish_animation(); screen = "menu"; _render())

func _save_preferences() -> void:
	profile["settings"] = {"reduced_motion": reduced_motion, "fast_motion": fast_motion}
	Profile.save_profile(profile)
	if background_material: background_material.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)
	if animating and reduced_motion: _finish_animation()

func _label(parent: Node, value: String, font_size: int = 15, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, action: Callable, width: float = 0) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(width, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("356164")))
	parent.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 5)
	panel.add_child(contents)
	return contents

func _menu() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/v3/logo.png")
	logo.custom_minimum_size = Vector2(0, 112)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(logo)
	var saved: Dictionary = saves.load_run() if saves != null else {}
	menu_resume = not state.is_empty() or not saved.is_empty()
	_primary(_button(body, "Play", _run_setup))
	if menu_resume: _button(body, "Resume", _resume)
	_button(body, "Settings", _settings)
	_button(body, "Statistics", _statistics)
	_button(body, "Collections", _collections)
	_button(body, "Quit", _back)

func _run_setup() -> void:
	var box := _modal("New run")
	var mode := _button(box, "Mode: " + run_mode.capitalize(), func(): pass)
	mode.pressed.connect(func(): run_mode = "standard" if run_mode == "practice" else "practice"; mode.text = "Mode: " + run_mode.capitalize())
	seeded_check = CheckBox.new()
	seeded_check.text = "Seeded"
	seeded_check.custom_minimum_size.y = 48
	box.add_child(seeded_check)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Enter seed"
	seed_input.max_length = 40
	seed_input.custom_minimum_size.y = 48
	seed_input.visible = false
	box.add_child(seed_input)
	seeded_check.toggled.connect(func(checked): seed_input.visible = checked)
	_primary(_button(box, "Start run", _confirm_new))

func _statistics() -> void:
	var box := _modal("Statistics")
	_label(box, "Tracked on this device since this profile began.", 14)
	for key in ["runs", "plays", "discards", "wins", "losses", "best_hand"]:
		_label(box, "%s   %s" % [key.replace("_", " ").capitalize(), profile.get(key, 0)], 22)

func _collections() -> void:
	var box := _modal("Collections")
	var discovered: Dictionary = profile.get("discovered", {})
	if discovered.is_empty(): _label(box, "No items discovered yet.")
	for id in discovered:
		var item: Dictionary = discovered[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		_item_card(row, item, func(): _collection_detail(item), 70, 100)
		_label(row, str(item.get("name", id)), 20)

func _collection_detail(item: Dictionary) -> void:
	var box := _modal(str(item.get("name", "Item")))
	_item_card(box, item, func(): pass, 120, 180)
	_label(box, str(item.get("description", "")), 18)

func _confirm_new() -> void:
	var seed_text := seed_input.text.strip_edges() if seeded_check.button_pressed else ""
	if seeded_check.button_pressed and seed_text.is_empty():
		seed_input.placeholder_text = "A seed is required"
		seed_input.grab_focus()
		return
	var seed_value := _random_seed() if not seeded_check.button_pressed else (int(seed_text) if seed_text.is_valid_int() else int(seed_text.hash()))
	if saves != null and saves.recovery_required:
		var box := _modal("Save recovery required")
		_label(box, saves.last_load_error)
		_label(box, "Reset archives the original files before starting over. Cancel keeps everything unchanged.")
		_button(box, "Archive & reset", func():
			if saves.archive_and_reset():
				_close_overlay(); _new_run(seed_value)
			else:
				_label(box, "Archive failed. Original retained; reset refused."))
		_button(box, "Cancel — keep original", _close_overlay)
	elif menu_resume:
		var box := _modal("Replace saved run?")
		_label(box, "Starting a new run replaces the existing checkpoint.")
		_button(box, "Start new run", func(): _close_overlay(); _new_run(seed_value))
		_button(box, "Keep existing run", _close_overlay)
	else:
		_close_overlay()
		_new_run(seed_value)

func _random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var value := int(rng.randi())
	while value == last_random_seed: value = int(rng.randi())
	last_random_seed = value
	return value

func _new_run(seed_value: int) -> void:
	if engine == null: return
	if saves != null and saves.recovery_required: return
	state = engine.new_run(seed_value, run_mode)
	profile["runs"] = int(profile.get("runs", 0)) + 1
	Profile.save_profile(profile)
	selected.clear()
	sorted_ids.clear()
	event_lines.clear()
	notice = ""
	screen = "game"
	_save()
	_render()

func _resume() -> void:
	if state.is_empty() and saves != null:
		state = saves.load_run()
	if not state.is_empty() and engine != null and engine.validate_save(state):
		screen = "game"
		_render()
	else:
		var box := _modal("Resume unavailable")
		_label(box, "No valid checkpoint was found. You can start a new run.")

func _save() -> void:
	save_failed = saves == null
	if saves != null:
		save_failed = not saves.save_run(state)

func _act(action: Dictionary) -> void:
	if engine == null or animating: return
	var before := state.duplicate(true)
	dispatch_count += 1
	var result: Dictionary = engine.dispatch(state, action)
	var error := str(result.get("error", ""))
	if not error.is_empty():
		notice = error.replace("_", " ")
		_render()
		return
	state = result.get("state", state)
	notice = ""
	selected.clear()
	sorted_ids.clear()
	event_lines = result.get("events", []).duplicate(true)
	_save()
	_track_action(action, before)
	var upgrade: Dictionary = {}
	for event in event_lines:
		if event.get("type") == "hand_upgrade": upgrade = event
	if not upgrade.is_empty():
		_render()
		_upgrade_detail(upgrade)
	elif action.get("type") in ["PLAY", "DISCARD"] and is_instance_valid(table):
		snapshot = before.duplicate(true)
		after_snapshot = state.duplicate(true)
		played_ids = action.get("ids", []).duplicate()
		animating = true
		presentation_token += 1
		if reduced_motion: _finish_animation()
		else: _present_action(presentation_token, str(action.type))
	else:
		_render()
		if action.get("type") == "SELECT_BLIND": _initial_deal()

func _track_action(action: Dictionary, before: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	var counter := "plays" if kind == "PLAY" else ("discards" if kind == "DISCARD" else "")
	if not counter.is_empty(): profile[counter] = int(profile.get(counter, 0)) + 1
	if state.get("phase") != before.get("phase") and state.get("phase") in ["won", "lost"]:
		var key := "wins" if state.phase == "won" else "losses"
		profile[key] = int(profile.get(key, 0)) + 1
	for event in event_lines:
		if event.get("type") == "score_total": profile["best_hand"] = maxf(float(profile.get("best_hand", 0)), float(event.get("after", {}).get("total", 0)))
	var discovered: Dictionary = profile.get("discovered", {})
	for item in state.get("modifiers", []) + state.get("consumables", []) + state.get("shop", []) + state.get("pack_state", {}).get("options", []):
		if item.has("id"): discovered[str(item.id)] = item.duplicate(true)
	profile["discovered"] = discovered
	Profile.save_profile(profile)

func _upgrade_detail(event: Dictionary) -> void:
	var box := _modal("Study complete")
	_label(box, str(event.get("target_id", "Hand")).replace("_", " ").capitalize(), 28)
	var before: Dictionary = event.get("before", {})
	var after: Dictionary = event.get("after", {})
	_label(box, "Level %s → %s" % [before.get("level", 1), after.get("level", 2)], 24, GOLD)
	_label(box, "Previous base", 16)
	_score_blocks(box, before)
	_label(box, "New base · permanent for this run", 16)
	_score_blocks(box, after)

func _finish_animation() -> void:
	presentation_token += 1
	for tween in motion_tweens:
		if tween.is_valid(): tween.kill()
	motion_tweens.clear()
	animating = false
	if is_instance_valid(table):
		for child in table.get_children():
			if child is Label: child.queue_free()
	for panel in score_panels.values():
		if is_instance_valid(panel): panel.scale = Vector2.ONE
	if is_instance_valid(category_label): category_label.scale = Vector2.ONE
	snapshot.clear()
	after_snapshot.clear()
	played_ids.clear()
	if is_instance_valid(table) and screen == "game" and state.get("phase") == "playing":
		for id in cards.keys():
			if not state.get("hand_ids", []).has(id):
				cards[id].queue_free()
				cards.erase(id)
		_sort_ids()
		for id in sorted_ids:
			if not cards.has(str(id)): _spawn_card(str(id))
		for card in cards.values():
			card.rotation = 0
			card.scale = Vector2.ONE
		_layout_hand(false)
		_refresh_table()
	else: _render()

func _score_blocks(parent: Node, values: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for key in ["chips", "mult"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _style(BLUE if key == "chips" else RED, Color.TRANSPARENT, 8))
		row.add_child(panel)
		score_panels[key] = panel
		var label := _label(panel, "%s %s" % [_number(values.get(key, 0)), "CHIPS" if key == "chips" else "MULT"], 23, Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_labels[key] = label

func _loadout() -> void:
	var items: Array = state.get("modifiers", []) + state.get("consumables", [])
	if items.is_empty(): return
	var row := HBoxContainer.new()
	body.add_child(row)
	for item in items:
		var card := _item_card(row, item, func(): _inventory(), 36, 55)
		card.compact = true
		card.set_meta("source_id", item.get("instance_id", item.get("id", "")))

func _hud() -> void:
	var goal := _panel(body)
	var row := HBoxContainer.new()
	goal.add_child(row)
	_label(row, "GOAL " + _number(state.get("target", 0)), 23)
	round_label = _label(row, _number(state.get("round_score", 0)), 23, GOLD)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	progress.max_value = maxf(1, float(state.get("target", 1)))
	progress.value = float(state.get("round_score", 0))
	goal.add_child(progress)
	_loadout()

func _blind() -> void:
	_label(body, "Choose a table", 25)
	var blinds: Array = state.get("ante_blinds", [])
	for i in range(3):
		var blind: Dictionary = blinds[i] if i < blinds.size() else {}
		var current := i == int(state.get("round", 0))
		var box := _panel(body)
		var row := HBoxContainer.new()
		box.add_child(row)
		var ticket := TextureRect.new()
		ticket.custom_minimum_size = Vector2(40, 56)
		ticket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ticket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists("res://assets/v3/card_back.png"): ticket.texture = load("res://assets/v3/card_back.png")
		row.add_child(ticket)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		_label(words, ["SMALL", "BIG", "BOSS"][i], 14, GOLD if current else CREAM)
		_label(words, _number(blind.get("target", 0)), 30)
		var boss: Dictionary = blind.get("boss", {})
		_button(row, "i", func():
			var detail := _modal(str(blind.get("name", "Table")))
			_label(detail, str(boss.get("description", "Beat the required score.")))
			_label(detail, "Reward $%s" % blind.get("reward", 0))
			_label(detail, "Standard balance is experimental." if run_mode == "standard" else "Practice table."), 48)
		if current:
			var actions := HBoxContainer.new()
			box.add_child(actions)
			_primary(_button(actions, "Enter", func(): _act({"type": "SELECT_BLIND"})))
			if i < 2: _button(actions, "Skip / tag", _skip_detail)
		else:
			_label(box, str(blind.get("status", "locked")).capitalize() if i < int(state.get("round", 0)) else "Locked", 12)

func _tag_text(value: Variant) -> String:
	var effect := str(value.get("effect", value.get("id", ""))) if value is Dictionary else str(value)
	if effect.contains("cash"): return "+$5 immediately"
	if effect.contains("reroll"): return "First reroll free at the next shop"
	if effect.contains("planet"): return "Free study pack at the next shop"
	return effect.replace("_", " ").capitalize()

func _skip_detail() -> void:
	var box := _modal("Skip this table?")
	var blinds: Array = state.get("ante_blinds", [])
	var blind: Dictionary = blinds[int(state.get("round", 0))] if blinds.size() > int(state.get("round", 0)) else {}
	_label(box, _tag_text(blind.get("tag", {})), 22, GOLD)
	_label(box, "No round payout, interest or shop. The boss cannot be skipped.")
	_primary(_button(box, "Take tag & advance", func(): _close_overlay(); _act({"type": "SKIP_BLIND"})))

func _playing() -> void:
	category_label = _label(body, "", 18, CREAM)
	_score_blocks(body, {})
	counts_label = _label(body, "", 14)
	table = Control.new()
	table.name = "PersistentTable"
	table.custom_minimum_size.y = 230
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(table)
	table.resized.connect(func(): if not animating: _layout_hand(false))
	_sort_ids()
	for side in ["deck", "used"]:
		var pile := TextureRect.new()
		pile.name = side
		pile.size = Vector2(40, 56)
		pile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://assets/v3/card_back.png"): pile.texture = load("res://assets/v3/card_back.png")
		table.add_child(pile)
		table.resized.connect(func(): pile.position = Vector2(0 if side == "deck" else table.size.x - 40, 16))
	for id in sorted_ids: _spawn_card(str(id))
	var sorts := HBoxContainer.new()
	body.add_child(sorts)
	_button(sorts, "Rank", func(): _set_sort(false))
	_button(sorts, "Suit", func(): _set_sort(true))
	_button(sorts, "Details", _events)
	play_button = _button(footer, "Play hand", func(): _act({"type": "PLAY", "ids": selected.duplicate()}))
	_primary(play_button)
	discard_button = _button(footer, "Discard", func(): _act({"type": "DISCARD", "ids": selected.duplicate()}))
	skip_button = _button(footer, "Skip", _finish_animation)
	skip_button.visible = false
	_refresh_table()
	_layout_hand.call_deferred(false)

func _primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _style(GOLD, GOLD))
	button.add_theme_stylebox_override("hover", _style(Color("ffba55"), CREAM))
	button.add_theme_color_override("font_color", Color("152d32"))
	button.add_theme_color_override("font_hover_color", Color("152d32"))

func _card(id: String) -> Dictionary:
	for card in state.get("deck", []):
		if str(card.get("id", "")) == id: return card
	return {}

func _card_button(parent: Node, id: String, selection: Array, action: Callable) -> Button:
	var button := CardView.new()
	button.data = _card(id)
	button.order = selection.find(id)
	button.custom_minimum_size = Vector2(64, 100)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _item_card(parent: Node, item: Dictionary, action: Callable, width: float = 90, height: float = 150) -> Button:
	var card := CardView.new()
	card.data = item
	card.family = str(item.get("family", item.get("kind", "passive")))
	if card.family == "playing_card":
		card.family = "playing"
		card.data = item.get("card", item)
	if str(item.get("id", "")).begins_with("study"): card.family = "planet"
	card.custom_minimum_size = Vector2(width, height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(action)
	parent.add_child(card)
	return card

func _select(id: String) -> void:
	if animating: return
	if selected.has(id): selected.erase(id)
	elif selected.size() < 5: selected.append(id)
	_refresh_table()
	_layout_hand(true)

func _sort() -> void:
	_set_sort(not sort_suit)

func _set_sort(suit: bool) -> void:
	if animating: return
	sort_suit = suit
	_sort_ids()
	_layout_hand(true)

func _sort_ids() -> void:
	sorted_ids = state.get("hand_ids", []).duplicate()
	sorted_ids.sort_custom(func(a, b):
		var ca := _card(str(a))
		var cb := _card(str(b))
		if sort_suit and ca.get("suit", 0) != cb.get("suit", 0): return ca.get("suit", 0) < cb.get("suit", 0)
		if ca.get("rank", 0) != cb.get("rank", 0): return ca.get("rank", 0) > cb.get("rank", 0)
		return str(a) < str(b))

func _shop() -> void:
	_label(body, "THE NIGHT MARKET", 24, CREAM)
	var shelf := HBoxContainer.new()
	body.add_child(shelf)
	var offers: Array = state.get("shop", [])
	for i in range(maxi(2, offers.size())):
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shelf.add_child(slot)
		if i < offers.size():
			var item: Dictionary = offers[i]
			_item_card(slot, item, func(): _offer_detail(item, i), 100, 148)
			_label(slot, "$%s · %s" % [item.get("cost", 0), str(item.get("family", "passive")).capitalize()], 14).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else: _label(slot, "SOLD
Empty shelf", 20)
	var voucher: Dictionary = state.get("voucher_offer", {})
	if not voucher.is_empty():
		var title := "✓ Purchased" if voucher.get("purchased", false) else "Voucher $%s" % voucher.get("cost", 10)
		_button(body, title + " · " + str(voucher.get("name", "Run upgrade")), func(): _voucher_detail(voucher))
	var packs := HBoxContainer.new()
	body.add_child(packs)
	for offer in state.get("pack_offers", []):
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		packs.add_child(slot)
		var art: Dictionary = offer.duplicate()
		art["pack_family"] = str(offer.get("family", "passive"))
		art["family"] = "pack"
		art["name"] = str(offer.get("family", "Mystery")).capitalize() + " pack"
		var card := _item_card(slot, art, func(): _pack_detail(offer), 100, 104)
		card.compact = true
		_label(slot, "%s · $%s" % [str(offer.get("family", "Pack")).capitalize(), offer.get("cost", 4)], 14).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_button(footer, "Reroll $%s" % state.get("reroll_cost", 5), func(): _act({"type": "REROLL"})).disabled = int(state.get("money", 0)) < int(state.get("reroll_cost", 5))
	_primary(_button(footer, "Next blind →", func(): _act({"type": "NEXT"})))

func _offer_detail(item: Dictionary, index: int) -> void:
	var box := _modal(str(item.get("name", "Item")))
	_item_card(box, item, func(): pass, 120, 200).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_label(box, "%s · %s" % [str(item.get("family", "passive")).capitalize(), item.get("rarity", "Original")], 16, GOLD)
	_label(box, str(item.get("description", "")), 20)
	var passive := str(item.get("kind", "modifier")) == "modifier"
	var count: int = state.get("modifiers", []).size() if passive else state.get("consumables", []).size()
	var cap := int(state.get("passive_capacity", 5) if passive else state.get("consumable_capacity", 2))
	var reason := "" if int(state.get("money", 0)) >= int(item.get("cost", 0)) else "Not enough money"
	if count >= cap: reason = "No free slot — sell a passive or use a consumable first"
	_label(box, "%s/%s slots · %s" % [count, cap, reason if not reason.is_empty() else "Space available"], 14)
	var buy := _button(box, "Buy $%s" % item.get("cost", 0), func(): _close_overlay(); _act({"type": "BUY", "offer_id": item.get("offer_id", ""), "slot": index}))
	_primary(buy)
	buy.disabled = not reason.is_empty()

func _voucher_detail(item: Dictionary) -> void:
	var box := _modal(str(item.get("name", "Voucher")))
	var art := item.duplicate(true)
	art["family"] = "voucher"
	_item_card(box, art, func(): pass, 120, 160).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_label(box, "RUN UPGRADE · no passive slot used", 16, GOLD)
	_label(box, str(item.get("description", "")), 22)
	var bought := bool(item.get("purchased", false))
	_label(box, "Purchased for this run" if bought else "Costs $%s · balance $%s" % [item.get("cost", 10), state.get("money", 0)])
	_primary(_button(box, "Purchase voucher", func(): _close_overlay(); _act({"type": "BUY_VOUCHER"})))
	box.get_child(-1).disabled = bought or int(state.get("money", 0)) < int(item.get("cost", 10))

func _pack_detail(offer: Dictionary) -> void:
	var box := _modal(str(offer.get("family", "Mystery")).capitalize() + " pack")
	_label(box, "Choose %s of %s" % [offer.get("choose", 1), offer.get("count", 3)], 26)
	_label(box, "Opening pays once. Choices are saved until you choose or skip. Studies and mutations apply immediately; passive cards need a free slot.")
	_label(box, "Cost $%s · balance $%s" % [offer.get("cost", 4), state.get("money", 0)])
	var button := _button(box, "Open pack", func(): _close_overlay(); pack_choice = -1; _act({"type": "OPEN_PACK", "offer_id": offer.get("offer_id", "")}))
	_primary(button)
	button.disabled = int(state.get("money", 0)) < int(offer.get("cost", 4))

func _receipt() -> void:
	var receipt: Dictionary = state.get("receipt", {})
	_label(body, "TABLE CLEARED", 30, CREAM)
	_label(body, "Score %s / %s" % [_number(state.get("round_score", 0)), _number(state.get("target", 0))], 20, GOLD)
	var paper := _panel(body)
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(paper, "YOUR RECEIPT", 24)
	_label(paper, "────────────────────────", 14)
	for line in receipt.get("line_items", []):
		var row := HBoxContainer.new()
		paper.add_child(row)
		_label(row, str(line.get("label", "Reward")), 18)
		_label(row, "$%s" % line.get("amount", 0), 22, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(paper, "Interest on $%s · capped at $%s" % [receipt.get("interest_base", 0), receipt.get("interest_cap", 5)], 14)
	_label(paper, "────────────────────────", 14)
	_label(paper, "TOTAL  +$%s" % receipt.get("total", 0), 30, GOLD)
	_label(paper, "$%s → $%s after cashout" % [receipt.get("money_before", state.get("money", 0)), receipt.get("money_after", state.get("money", 0))], 18)
	_primary(_button(footer, "Cash out $%s" % receipt.get("total", 0), func(): _act({"type": "CASH_OUT"})))

func _pack() -> void:
	var pack: Dictionary = state.get("pack_state", {})
	var options: Array = pack.get("options", [])
	_label(body, str(pack.get("family", "Mystery")).to_upper() + " / REVEAL", 25)
	_label(body, "Choose %s of %s" % [pack.get("remaining", 1), options.size()], 21, GOLD)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for i in range(options.size()):
		var item: Dictionary = options[i].duplicate()
		item["family"] = pack.get("family", "passive")
		var card := _item_card(row, item, func(): pack_choice = i; _render(), 90, 190)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.order = 0 if pack_choice == i else -1
	if pack_choice >= 0 and pack_choice < options.size():
		_label(body, str(options[pack_choice].get("name", "Playing card")), 22)
		_label(body, str(options[pack_choice].get("description", "Adds this card to your deck.")), 16)
	_button(body, "Inspect loadout / sell", _inventory)
	_button(footer, "Skip pack", func(): pack_choice = -1; _act({"type": "SKIP_PACK"}))
	var confirm := _button(footer, "Choose card", _choose_pack)
	_primary(confirm)
	confirm.disabled = pack_choice < 0 or pack_choice >= options.size()

func _choose_pack() -> void:
	var pack: Dictionary = state.get("pack_state", {})
	var item: Dictionary = pack.get("options", [])[pack_choice]
	if str(pack.get("family", "")) == "tarot":
		targeting_pack = true
		target_required = int(item.get("target_count", 2 if item.get("id") == "rank_copy" else 1))
		target_ids.clear()
		_target_picker()
	else:
		_act({"type": "CHOOSE_PACK", "option_id": item.get("option_id", ""), "targets": []})
		pack_choice = -1

func _terminal() -> void:
	var won: bool = state.get("phase", "") == "won"
	_label(body, "CIRCUIT COMPLETE" if won else "THE LIGHTS DIM", 30, GOLD)
	_label(body, "All eight antes conquered." if won else "Every run teaches a different rhythm.", 20)
	_label(body, "Ante %s · Score %s · Seed %s" % [state.get("ante", 1), _number(state.get("round_score", 0)), state.get("seed", 0)])
	_button(body, "Inspect final score", _events)
	_button(footer, "New run / menu", func(): screen = "menu"; _render())

func _modal(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.08, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, maxi(20, frame.get_theme_constant("margin_" + side)))
	overlay.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	_label(stack, title, 24, GOLD)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)
	_button(stack, "Close", _close_overlay)
	return content

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _inventory() -> void:
	var box := _modal("Your loadout")
	_label(box, "MODIFIERS · left to right", 14, BLUE)
	var mods: Array = state.get("modifiers", [])
	if mods.is_empty(): _label(box, "Find modifiers at the night market.")
	for i in range(mods.size()):
		var item: Dictionary = mods[i]
		var panel := _panel(box)
		_label(panel, "◆ %s  %s" % [i + 1, item.get("name", "Modifier")], 18, GOLD)
		_label(panel, str(item.get("description", "")))
		_label(panel, "%s · %s · stored %s" % [item.get("rarity", "original"), item.get("stage", "effect"), item.get("stored", 0)], 14)
		var row := HBoxContainer.new()
		panel.add_child(row)
		_button(row, "←", func(): _move_modifier(i, -1), 48).disabled = i == 0
		_button(row, "→", func(): _move_modifier(i, 1), 48).disabled = i == mods.size() - 1
		_button(row, "Sell $%s" % maxi(1, int(item.get("cost", 0)) / 2), func(): _close_overlay(); _act({"type": "SELL", "instance_id": item.get("instance_id", ""), "index": i}); _inventory()).disabled = not state.get("phase", "") in ["shop", "pack_select"]
	_label(box, "CONSUMABLES", 14, BLUE)
	var items: Array = state.get("consumables", [])
	if items.is_empty(): _label(box, "No consumables held.")
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var panel := _panel(box)
		_label(panel, str(item.get("name", "Item")), 18, GOLD)
		_label(panel, str(item.get("description", "")))
		_button(panel, "Use", func(): _use_item(i)).disabled = not state.get("phase", "") in ["playing", "shop"]

func _move_modifier(index: int, direction: int) -> void:
	var ids: Array = []
	for item in state.get("modifiers", []): ids.append(item.get("instance_id", item.get("id", "")))
	var swap = ids[index]
	ids[index] = ids[index + direction]
	ids[index + direction] = swap
	_act({"type": "REORDER", "ids": ids})
	_inventory()

func _use_item(index: int) -> void:
	var item: Dictionary = state.get("consumables", [])[index]
	targeting_pack = false
	target_required = int(item.get("target_count", 2 if item.get("id") == "rank_copy" else 1))
	var id := str(item.get("id", ""))
	var name_text := str(item.get("name", ""))
	if id.begins_with("study") or name_text.begins_with("Study") or item.get("target_count", -1) == 0:
		_close_overlay()
		_act({"type": "USE", "instance_id": item.get("instance_id", ""), "index": index, "targets": []})
	else:
		target_index = index
		target_ids.clear()
		_target_picker()

func _target_picker() -> void:
	var box := _modal("Choose %s card%s" % [target_required, "s" if target_required > 1 else ""])
	_label(box, "First SOURCE, then TARGET. Cancel consumes nothing." if target_required == 2 else "Permanent deck change. Cancel consumes nothing.")
	var ids: Array = state.get("hand_ids", []).duplicate()
	if targeting_pack: ids = state.get("pack_state", {}).get("target_ids", []).duplicate()
	elif state.get("phase", "") == "shop":
		ids.clear()
		for card in state.get("deck", []): ids.append(card.get("id", ""))
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for id in ids:
		_card_button(grid, str(id), target_ids, func():
			if target_ids.has(str(id)): target_ids.erase(str(id))
			elif target_ids.size() < target_required: target_ids.append(str(id))
			_target_picker())
	var fixed_actions: Node = box.get_parent().get_parent()
	var apply := _button(fixed_actions, "Apply · %s/%s selected" % [target_ids.size(), target_required], _apply_target)
	_primary(apply)
	apply.disabled = target_ids.size() != target_required
	fixed_actions.move_child(apply, fixed_actions.get_child_count() - 2)

func _apply_target() -> void:
	var action: Dictionary
	if targeting_pack:
		var item: Dictionary = state.get("pack_state", {}).get("options", [])[pack_choice]
		action = {"type": "CHOOSE_PACK", "option_id": item.get("option_id", ""), "targets": target_ids.duplicate()}
	else:
		var item: Dictionary = state.get("consumables", [])[target_index]
		action = {"type": "USE", "instance_id": item.get("instance_id", ""), "index": target_index, "targets": target_ids.duplicate()}
	_close_overlay()
	_act(action)
	pack_choice = -1
	target_ids.clear()

func _events() -> void:
	var box := _modal("Score / action receipt")
	if event_lines.is_empty(): _label(box, "No action receipt in this session yet. Your checkpoint is unaffected.")
	for event in event_lines:
		if event is Dictionary:
			var line := ""
			for key in event:
				line += "%s: %s  " % [str(key).replace("_", " "), str(event[key])]
			_label(_panel(box), line, 14)
		else: _label(box, str(event))

func _help() -> void:
	var box := _modal("A quick field guide")
	for section in [
		["01 / Make a hand", "Tap 1–5 cards, then Play. Only cards belonging to your poker category normally score. Discard unwanted cards to draw replacements. Tap order is scoring order; numbered cards show it. Sorting never changes that order."],
		["02 / Chips × multiplier", "Blue chips times coral multiplier gives your score. Card effects resolve first, then held-card effects, then modifiers from left to right. Preview is calculated by the same engine as play."],
		["03 / Build your circuit", "Beat the goal to visit the market. Buy modifiers and consumables, sell modifiers in the loadout, or reroll offers. Use the arrow buttons to reorder effects; adding multiplier before multiplying it matters."],
		["04 / Change the deck", "Studies improve a hand category for this run. Other items target one card: choose from your hand during play, or the whole deck in the shop. Changes are permanent for this run."],
		["05 / Know the table", "Every ante has a small, big and boss round. Boss rules appear before entry and above your hand. Beat the eighth boss to win. Run out of hands below the goal and the run ends."],
		["Poker order / weak to strong", "High card • Pair • Two pair • Three of a kind • Straight • Flush • Full house • Four of a kind • Straight flush • Five of a kind • Flush house • Flush five. Aces can be low in A–2–3–4–5, but straights cannot wrap around."],
		["Offline / checkpoints", "Each successful action saves automatically. Menu → Resume returns to that checkpoint. Back closes a panel, then opens the menu. A repeated seed starts the same run; your choices change its path."]]:
		_label(box, section[0], 18, GOLD)
		_label(box, section[1], 15)

func _number(value: Variant) -> String:
	var number := float(value)
	if absf(number) >= 1000000: return "%.2fm" % (number / 1000000.0)
	if absf(number) >= 10000: return "%.1fk" % (number / 1000.0)
	if number == floorf(number): return str(int(number))
	return "%.1f" % number

func _spawn_card(id: String) -> Control:
	var card := CardView.new()
	card.data = _card(id).duplicate(true)
	card.size = Vector2(68, 100)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = card.size / 2
	table.add_child(card)
	cards[id] = card
	return card

func _hand_position(index: int, count: int) -> Vector2:
	var width := table.size.x
	var step := minf(48, (width - 70) / maxf(1, count - 1))
	return Vector2((width - (step * (count - 1) + 68)) / 2 + index * step, table.size.y - 116)

func _layout_hand(moving: bool) -> void:
	if not is_instance_valid(table): return
	for i in range(sorted_ids.size()):
		var id: String = str(sorted_ids[i])
		if not cards.has(id): continue
		var card: Control = cards[id]
		card.z_index = i
		card.order = selected.find(id)
		card.queue_redraw()
		var destination := _hand_position(i, sorted_ids.size()) - Vector2(0, 18 if selected.has(id) else 0)
		if selection_tweens.has(id) and selection_tweens[id].is_valid(): selection_tweens[id].kill()
		if moving and not reduced_motion:
			var tween := create_tween()
			selection_tweens[id] = tween
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "position", destination, 0.16)
		else: card.position = destination

func _input(event: InputEvent) -> void:
	if animating or is_instance_valid(overlay) or not is_instance_valid(table): return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: point = event.position
	elif event is InputEventScreenTouch and event.pressed: point = event.position
	else: return
	# Reverse draw order resolves overlapping rectangles, including lifted cards.
	for i in range(sorted_ids.size() - 1, -1, -1):
		var id := str(sorted_ids[i])
		if cards.has(id) and cards[id].get_global_rect().has_point(point):
			_select(id)
			get_viewport().set_input_as_handled()
			return

func _refresh_table() -> void:
	if not is_instance_valid(table): return
	var preview: Dictionary = engine.preview(state, selected) if not selected.is_empty() else {}
	category_label.text = str(preview.get("category", "")).replace("_", " ").capitalize()
	for key in ["chips", "mult"]: _score_number(float(preview.get(key, 0)), key)
	counts_label.text = "%s hands   /   %s discards" % [state.get("hands_left", 0), state.get("discards_left", 0)]
	round_label.text = _number(state.get("round_score", 0))
	play_button.disabled = selected.is_empty() or animating
	discard_button.disabled = selected.is_empty() or animating or int(state.get("discards_left", 0)) <= 0
	skip_button.visible = animating

func _duration(value: float) -> float:
	return 0.025 if reduced_motion else value * (0.45 if fast_motion else 1.0)

func _tween() -> Tween:
	var tween := create_tween()
	motion_tweens.append(tween)
	return tween

func _move(card: Control, destination: Vector2, seconds: float, delay: float = 0.0) -> void:
	var tween := _tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", destination, _duration(seconds)).set_delay(_duration(delay) if delay > 0 else 0.0)

func _pause(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout

func _pulse(control: Control) -> void:
	if reduced_motion: return
	control.pivot_offset = control.size / 2
	var tween := _tween()
	tween.tween_property(control, "scale", Vector2(1.09, 1.09), _duration(0.08))
	tween.tween_property(control, "scale", Vector2.ONE, _duration(0.15))

func _wiggle(control: Control) -> void:
	if reduced_motion: return
	var tween := _tween()
	tween.tween_property(control, "rotation", -0.07, _duration(0.07))
	tween.tween_property(control, "rotation", 0.06, _duration(0.09))
	tween.tween_property(control, "rotation", 0.0, _duration(0.07))
	_pulse(control)

func _score_number(value: float, key: String) -> void:
	if is_instance_valid(score_labels.get(key)): score_labels[key].text = _number(value) + (" CHIPS" if key == "chips" else " MULT")

func _present_action(token: int, kind: String) -> void:
	for tween in selection_tweens.values():
		if tween.is_valid(): tween.kill()
	selection_tweens.clear()
	_refresh_table()
	round_label.text = _number(snapshot.get("round_score", 0))
	for key in ["chips", "mult"]: _score_number(0, key)
	if kind == "PLAY":
		for i in range(played_ids.size()):
			var id := str(played_ids[i])
			if cards.has(id):
				cards[id].z_index = 30 + i
				_move(cards[id], Vector2((table.size.x - played_ids.size() * 57) / 2 + i * 57, 12), 0.32, i * 0.035)
		await _pause(0.52)
		if token != presentation_token: return
		for event in event_lines:
			if token != presentation_token: return
			var event_type := str(event.get("type", ""))
			if event_type in ["action", "receipt", "growth", "score"]: continue
			category_label.text = str(event.get("label", "")).replace("_", " ").capitalize()
			var source := str(event.get("source_id", ""))
			if cards.has(source): _wiggle(cards[source])
			var target := str(event.get("target_id", ""))
			if target != source and cards.has(target): _wiggle(cards[target])
			for item in body.find_children("*", "Button", true, false):
				if item.get_meta("source_id", "") == source and not source.is_empty(): _wiggle(item)
			var after: Dictionary = event.get("after", {})
			var before: Dictionary = event.get("before", {})
			for key in ["chips", "mult"]:
				if after.has(key) and float(after[key]) != float(before.get(key, 0)):
					_pulse(score_panels[key])
					var tween := _tween()
					tween.tween_method(_score_number.bind(key), float(before.get(key, 0)), float(after[key]), _duration(0.22))
			if event_type == "score_total":
				category_label.text = "%s × %s = %s" % [_number(after.get("chips", 0)), _number(after.get("mult", 0)), _number(after.get("total", 0))]
				_pulse(category_label)
			if event_type == "round_total":
				var flying := _label(table, "+" + _number(event.get("delta", {}).get("total", 0)), 30, GOLD)
				flying.autowrap_mode = TextServer.AUTOWRAP_OFF
				flying.size = Vector2(100, 40)
				flying.position = Vector2(table.size.x / 2 - 45, 0)
				_move(flying, (round_label.global_position - table.global_position), 0.45)
				var tween := _tween()
				tween.tween_method(func(value): round_label.text = _number(roundf(value)), float(snapshot.get("round_score", 0)), float(after_snapshot.get("round_score", 0)), _duration(0.5))
				tween.tween_callback(flying.queue_free)
			await _pause(0.55 if event_type in ["round_total", "score_total"] else 0.32)
	if token != presentation_token: return
	# Same selected nodes leave the table; they are not replaced by scoring replicas.
	for i in range(played_ids.size()):
		var id := str(played_ids[i])
		if cards.has(id):
			_move(cards[id], Vector2(table.size.x - 68, 0), 0.32, i * 0.025)
			var shrink := _tween()
			shrink.tween_property(cards[id], "scale", Vector2(0.55, 0.55), _duration(0.32))
	await _pause(0.5)
	if token != presentation_token: return
	for id in played_ids:
		if cards.has(str(id)):
			cards[str(id)].queue_free()
			cards.erase(str(id))
	_sort_ids()
	var draw_index := 0
	for id in sorted_ids:
		if not cards.has(str(id)):
			var card := _spawn_card(str(id))
			card.position = Vector2(0, 16)
			_move(card, _hand_position(sorted_ids.find(id), sorted_ids.size()), 0.4, draw_index * 0.065)
			draw_index += 1
		else: _move(cards[str(id)], _hand_position(sorted_ids.find(id), sorted_ids.size()), 0.25)
	await _pause(0.48 + draw_index * 0.065)
	if token == presentation_token: _finish_animation()

func _initial_deal() -> void:
	if not is_instance_valid(table) or reduced_motion: return
	animating = true
	presentation_token += 1
	var token := presentation_token
	_refresh_table()
	await get_tree().process_frame
	if token != presentation_token: return
	for i in range(sorted_ids.size()):
		var card: Control = cards[str(sorted_ids[i])]
		card.position = Vector2(0, 16)
		_move(card, _hand_position(i, sorted_ids.size()), 0.42, i * 0.065)
	await _pause(0.5 + sorted_ids.size() * 0.065)
	if token == presentation_token: _finish_animation()
