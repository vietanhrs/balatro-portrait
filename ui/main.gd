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
var timeline_value: Dictionary = {}
var timeline_label := ""
var timeline_source := ""
var timeline_delta := ""
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
	var background := ColorRect.new()
	background.color = FELT
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
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

func _style(fill: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
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
	_clear(frame)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	frame.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	_label(top, "VELVET / CIRCUIT" if screen == "menu" else "A%s · %s" % [state.get("ante", 1), str(state.get("mode", "practice")).capitalize()], 16)
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
	if animating:
		_scoring()
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
	var box := _modal("Table settings")
	_button(box, "Reduced motion: " + ("on" if reduced_motion else "off"), func(): reduced_motion = not reduced_motion; _settings())
	_button(box, "Fast scoring: " + ("on" if fast_motion else "off"), func(): fast_motion = not fast_motion; _settings())
	_button(box, "How to play", _help)
	_button(box, "Save & menu", func(): _close_overlay(); _finish_animation(); screen = "menu"; _render())

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
	_label(body, "A little luck.
A deliberate order.", 32, CREAM)
	_label(body, "An original portrait poker roguelike", 15, BLUE)
	var box := _panel(body)
	_label(box, "BUILD A RUN", 13, GOLD)
	_label(box, "Practice recommended. Standard is EXPERIMENTAL: reference targets, balance not established.")
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Seed (optional number or word)"
	seed_input.custom_minimum_size.y = 48
	seed_input.max_length = 40
	box.add_child(seed_input)
	_button(box, "Mode: " + run_mode.capitalize(), func(): run_mode = "standard" if run_mode == "practice" else "practice"; _render())
	_button(box, "New seeded run", _confirm_new).disabled = engine == null
	var saved: Dictionary = {}
	if saves != null:
		saved = saves.load_run()
	if saves != null and saves.recovery_required:
		_label(box, "Save recovery required — original retained. New run requires confirmed reset.", 14, GOLD)
	menu_resume = not state.is_empty() or not saved.is_empty()
	_button(box, "Resume run", _resume).disabled = not menu_resume
	_button(box, "How to play", _help)
	_label(body, "Cream cards • blue chips • coral multiplier", 13, GOLD)
	_label(body, "Unofficial independent game inspired by Balatro. Not affiliated with LocalThunk or Playstack. No real-money gambling.", 12)
	if engine == null:
		_label(body, "Game engine is not installed. Gameplay is unavailable.", 14, RED)

func _confirm_new() -> void:
	var seed_text := seed_input.text.strip_edges()
	var seed_value := int(Time.get_unix_time_from_system()) if seed_text.is_empty() else (int(seed_text) if seed_text.is_valid_int() else int(seed_text.hash()))
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
		_new_run(seed_value)

func _new_run(seed_value: int) -> void:
	if engine == null: return
	if saves != null and saves.recovery_required: return
	state = engine.new_run(seed_value, run_mode)
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
	var upgrade: Dictionary = {}
	for event in event_lines:
		if event.get("type") == "hand_upgrade": upgrade = event
	if not upgrade.is_empty():
		_render()
		_upgrade_detail(upgrade)
	elif action.get("type") == "PLAY" and not reduced_motion:
		snapshot = before
		snapshot["played_ids"] = action.get("ids", []).duplicate()
		animating = true
		presentation_token += 1
		_present(presentation_token)
	else: _render()

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

func _present(token: int) -> void:
	timeline_value = {}
	for event in event_lines:
		if token != presentation_token or not animating: return
		if not event is Dictionary: continue
		if event.get("type") in ["action", "receipt"]: continue
		timeline_label = str(event.get("label", event.get("type", "Scoring"))).replace("_", " ").capitalize()
		timeline_source = str(event.get("source_id", ""))
		timeline_delta = ""
		var delta: Dictionary = event.get("delta", {})
		if str(event.get("operation", "")) in ["multiply", "xmult", "×", "mul"]:
			var before_mult := float(event.get("before", {}).get("mult", 0))
			timeline_delta = "×%s multiplier" % _number(float(event.get("after", {}).get("mult", 0)) / before_mult) if before_mult > 0 else "× multiplier"
		else:
			for key in ["chips", "mult"]:
				if float(delta.get(key, 0)) != 0: timeline_delta += "+%s %s  " % [_number(delta[key]), key]
		if event.get("type") == "score_total": timeline_delta = "Chips × Mult → hand score"
		if event.get("type") == "round_total": timeline_delta = "+%s to round score" % _number(delta.get("total", 0))
		if event.get("after") is Dictionary and str(event.get("stage", "")) != "receipt": timeline_value.merge(event.after, true)
		for key in ["chips", "mult", "total"]:
			if event.has(key): timeline_value[key] = event[key]
		_render()
		await get_tree().create_timer(0.05 if fast_motion else clampf(1.6 / maxf(event_lines.size(), 1), 0.06, 0.22)).timeout
	if token == presentation_token: _finish_animation()

func _finish_animation() -> void:
	presentation_token += 1
	animating = false
	snapshot.clear()
	_render()

func _score_blocks(parent: Node, values: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for key in ["chips", "mult"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _style(BLUE if key == "chips" else RED, Color.TRANSPARENT, 8))
		row.add_child(panel)
		var label := _label(panel, "%s %s" % [_number(values.get(key, 0)), "CHIPS" if key == "chips" else "MULT"], 23, Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _scoring() -> void:
	_label(body, "RESOLVING HAND", 16, CREAM)
	_label(body, timeline_label, 24)
	_label(body, timeline_delta, 20, GOLD)
	_score_blocks(body, timeline_value)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for id in snapshot.get("played_ids", []):
		var c := CardView.new()
		for card in snapshot.get("deck", []):
			if card.id == id: c.data = card
		c.order = 0 if str(id) == timeline_source else -1
		c.custom_minimum_size = Vector2(48, 110)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(c)
	var sources := HBoxContainer.new()
	body.add_child(sources)
	for item in snapshot.get("modifiers", []):
		var source := _item_card(sources, item, func(): pass, 48, 64)
		source.compact = true
		source.order = 0 if item.get("instance_id", item.get("id", "")) == timeline_source else -1
	_label(body, "TOTAL  " + _number(timeline_value.get("total", 0)), 32, GOLD)
	_label(body, "Checkpoint saved · effects resolve in order", 14)
	_button(footer, "Skip animation →", _finish_animation)

func _loadout() -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var mods: Array = state.get("modifiers", [])
	for i in range(int(state.get("passive_capacity", 5))):
		if i < mods.size():
			var card := _item_card(row, mods[i], func(): _inventory(), 48, 60)
			card.compact = true
		else:
			var slot := _button(row, "+", _inventory, 48)
			slot.add_theme_color_override("font_color", Color("91b5a7"))
	var count := _label(row, "%s/5" % mods.size(), 12)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.custom_minimum_size.x = 24
	count.size_flags_horizontal = Control.SIZE_SHRINK_END

func _hud() -> void:
	var goal := _panel(body)
	var row := HBoxContainer.new()
	goal.add_child(row)
	_label(row, "GOAL " + _number(state.get("target", 0)), 23)
	_label(row, _number(state.get("round_score", 0)), 23, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	progress.max_value = maxf(1, float(state.get("target", 1)))
	progress.value = float(state.get("round_score", 0))
	goal.add_child(progress)
	_loadout()

func _blind() -> void:
	_label(body, "CHOOSE YOUR TABLE", 25)
	_label(body, "Ante %s / 8 · one table at a time" % state.get("ante", 1), 14)
	var blinds: Array = state.get("ante_blinds", [])
	for i in range(3):
		var blind: Dictionary = blinds[i] if i < blinds.size() else {}
		var current := i == int(state.get("round", 0))
		var box := _panel(body)
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var status := "AVAILABLE" if current else (str(blind.get("status", "complete")).to_upper() if i < int(state.get("round", 0)) else "LOCKED")
		_label(box, "%s  /  %s" % [["01 SMALL", "02 BIG", "03 BOSS"][i], status], 16, GOLD if current else CREAM)
		_label(box, "%s points · reward $%s" % [_number(blind.get("target", state.get("target", 0) if current else 0)), blind.get("reward", i + 3)], 21)
		var boss: Dictionary = blind.get("boss", state.get("boss", {}) if i == 2 else {})
		_label(box, str(boss.get("description", "Build a hand. Beat the target.")), 14)
		if current:
			var row := HBoxContainer.new()
			box.add_child(row)
			_primary(_button(row, "Enter table", func(): _act({"type": "SELECT_BLIND"})))
			if i < 2 and int(state.get("version", 1)) >= 2: _button(row, "Skip / tag", _skip_detail)
	_label(body, "Seed %s · skips grant a tag, not a payout" % state.get("seed", 0), 14)

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
	var preview: Dictionary = {}
	if not selected.is_empty() and engine != null: preview = engine.preview(state, selected)
	var stage := _panel(body)
	var category := str(preview.get("category", "Choose 1–5 cards")).replace("_", " ").capitalize()
	_label(stage, category + "  ·  " + str(selected.size()) + "/5", 17)
	_score_blocks(stage, preview)
	var row := HBoxContainer.new()
	body.add_child(row)
	_label(row, "%s hands · %s discards" % [state.get("hands_left", 0), state.get("discards_left", 0)], 14)
	_button(row, "Items %s/%s" % [state.get("consumables", []).size(), state.get("consumable_capacity", 2)], _inventory, 82).size_flags_horizontal = Control.SIZE_SHRINK_END
	_button(row, "Sort", _sort, 48).size_flags_horizontal = Control.SIZE_SHRINK_END
	var hand_space := VBoxContainer.new()
	hand_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_space.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(hand_space)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0)
	hand_space.add_child(grid)
	var ids: Array = state.get("hand_ids", []) if sorted_ids.is_empty() else sorted_ids
	for id in ids: _card_button(grid, str(id), selected, func(): _select(str(id)))
	var boss: Dictionary = state.get("boss", {})
	_label(body, str(boss.get("description", "Tap order = scoring order · selection lifts cards")), 14)
	var play := _button(footer, "Play hand", func(): _act({"type": "PLAY", "ids": selected.duplicate()}))
	_primary(play)
	play.disabled = selected.is_empty()
	var discard := _button(footer, "Discard", func(): _act({"type": "DISCARD", "ids": selected.duplicate()}))
	discard.disabled = selected.is_empty() or int(state.get("discards_left", 0)) <= 0

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
	_render()

func _sort() -> void:
	sort_suit = not sort_suit
	sorted_ids = state.get("hand_ids", []).duplicate()
	sorted_ids.sort_custom(func(a, b):
		var ca := _card(str(a))
		var cb := _card(str(b))
		if sort_suit and ca.get("suit", 0) != cb.get("suit", 0): return ca.get("suit", 0) < cb.get("suit", 0)
		return ca.get("rank", 0) > cb.get("rank", 0))
	_render()

func _shop() -> void:
	_label(body, "THE NIGHT MARKET", 24, CREAM)
	_label(body, "Tap a card to inspect · passives resolve left to right", 14)
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
	_label(body, "Your reward is pending. Collect it exactly once.", 14)
	_primary(_button(footer, "Cash out $%s" % receipt.get("total", 0), func(): _act({"type": "CASH_OUT"})))

func _pack() -> void:
	var pack: Dictionary = state.get("pack_state", {})
	var options: Array = pack.get("options", [])
	_label(body, str(pack.get("family", "Mystery")).to_upper() + " / REVEAL", 25)
	_label(body, "Choose %s of %s" % [pack.get("remaining", 1), options.size()], 21, GOLD)
	_label(body, "Tap to select. Confirm to keep; skip for no refund.", 14)
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
