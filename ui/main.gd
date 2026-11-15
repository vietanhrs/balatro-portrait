extends Control
## Rendering and input only. All gameplay transactions belong to GameEngine.
signal back_requested
signal safe_area_changed(insets: Vector4)
const FELT = Color("102e31")
const PANEL = Color("193e40")
const CREAM = Color("f5e7c8")
const GOLD = Color("e0b66c")
const BLUE = Color("65bce8")
const RED = Color("ee8179")
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
	layout.add_theme_constant_override("separation", 7)
	frame.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var title := _label(top, "VELVET / CIRCUIT", 18, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "?", _help, 48).size_flags_horizontal = Control.SIZE_SHRINK_END
	if screen != "menu":
		_button(top, "Menu", func(): screen = "menu"; _render(), 60).size_flags_horizontal = Control.SIZE_SHRINK_END
	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroller)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	scroller.add_child(body)
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
	_hud()
	match str(state.get("phase", "")):
		"playing": _playing()
		"blind_select": _blind()
		"shop": _shop()
		"won", "lost": _terminal()
		_: _label(body, "Unknown run phase. Return to the menu.")
	if not notice.is_empty():
		_label(body, notice, 13, GOLD)
	if save_failed:
		_label(body, "Save unavailable — keep the app open to preserve this run.", 13, RED)

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
	_label(box, "Eight antes. Twenty-four rounds. Turn a small hand into a remarkable score.")
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Seed (optional number or word)"
	seed_input.custom_minimum_size.y = 48
	seed_input.max_length = 40
	box.add_child(seed_input)
	_button(box, "New seeded run", _confirm_new).disabled = engine == null
	var saved: Dictionary = {}
	if saves != null:
		saved = saves.load_run()
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
	if menu_resume:
		var box := _modal("Replace saved run?")
		_label(box, "Starting a new run replaces the existing checkpoint.")
		_button(box, "Start new run", func(): _close_overlay(); _new_run(seed_value))
		_button(box, "Keep existing run", _close_overlay)
	else:
		_new_run(seed_value)

func _new_run(seed_value: int) -> void:
	if engine == null: return
	state = engine.new_run(seed_value)
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
	if engine == null: return
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
	_render()

func _hud() -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	_label(row, "ANTE %s / 8  ·  %s" % [state.get("ante", 1), ["SMALL", "BIG", "BOSS"][clampi(int(state.get("round", 0)), 0, 2)]] , 14, GOLD)
	_label(row, "$%s" % state.get("money", 0), 22, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var panel := _panel(body)
	var scores := HBoxContainer.new()
	panel.add_child(scores)
	_label(scores, "SCORE  %s" % _number(state.get("round_score", 0)), 20, BLUE)
	_label(scores, "GOAL  %s" % _number(state.get("target", 0)), 16)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 7
	progress.show_percentage = false
	progress.max_value = maxf(1, float(state.get("target", 1)))
	progress.value = float(state.get("round_score", 0))
	panel.add_child(progress)
	var mods: Array = state.get("modifiers", [])
	var ribbon := HBoxContainer.new()
	body.add_child(ribbon)
	for i in range(5):
		var caption := "◇
EMPTY"
		if i < mods.size(): caption = "◆ %s
%s" % [i + 1, str(mods[i].get("name", "Modifier")).get_slice(" ", 0)]
		var button := _button(ribbon, caption, _inventory)
		button.add_theme_font_size_override("font_size", 11)
		button.clip_text = true
	if state.get("phase", "") != "playing":
		_button(body, "Loadout  %s/5 modifiers · %s/2 items" % [mods.size(), state.get("consumables", []).size()], _inventory)

func _blind() -> void:
	var box := _panel(body)
	_label(box, "NEXT TABLE", 13, BLUE)
	_label(box, "Beat %s points" % _number(state.get("target", 0)), 29)
	if int(state.get("round", 0)) == 2:
		var boss: Dictionary = state.get("boss", {})
		_label(box, str(boss.get("name", "Boss round")), 20, GOLD)
		_label(box, str(boss.get("description", "Read the table rule before playing.")))
	else:
		_label(box, "Play up to five cards at a time. Reach the goal before your hands run out.")
	_label(box, "Seed %s" % state.get("seed", ""), 13)
	_button(footer, "Enter table", func(): _act({"type": "SELECT_BLIND"}))

func _playing() -> void:
	if int(state.get("round", 0)) == 2:
		_label(body, "%s · %s" % [state.get("boss", {}).get("name", "Boss"), state.get("boss", {}).get("description", "")], 12, GOLD)
	var preview: Dictionary = {}
	if not selected.is_empty() and engine != null:
		preview = engine.preview(state, selected)
	var stage := _panel(body)
	var category := str(preview.get("category", "Choose 1–5 cards")).replace("_", " ").capitalize()
	_label(stage, category, 18)
	var score_row := HBoxContainer.new()
	stage.add_child(score_row)
	_label(score_row, "%s chips" % _number(preview.get("chips", 0)), 18, BLUE)
	_label(score_row, "× %s mult" % _number(preview.get("mult", 0)), 18, RED)
	_label(stage, "Preview %s  ·  %s/5 selected" % [_number(preview.get("total", 0)), selected.size()], 12, GOLD)
	if not str(preview.get("error", "")).is_empty(): _label(stage, str(preview.error).replace("_", " "), 12, RED)
	var row := HBoxContainer.new()
	body.add_child(row)
	_label(row, "%s hands  ·  %s discards" % [state.get("hands_left", 0), state.get("discards_left", 0)], 14)
	_button(row, "Items %s" % state.get("consumables", []).size(), _inventory, 60).size_flags_horizontal = Control.SIZE_SHRINK_END
	_button(row, "Sort", _sort, 58).size_flags_horizontal = Control.SIZE_SHRINK_END
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var ids: Array = state.get("hand_ids", []) if sorted_ids.is_empty() else sorted_ids
	for id in ids:
		_card_button(grid, str(id), selected, func(): _select(str(id)))
	var play := _button(footer, "Play hand", func(): _act({"type": "PLAY", "ids": selected.duplicate()}))
	play.disabled = selected.is_empty()
	var discard := _button(footer, "Discard", func(): _act({"type": "DISCARD", "ids": selected.duplicate()}))
	discard.disabled = selected.is_empty() or int(state.get("discards_left", 0)) <= 0
	if not event_lines.is_empty():
		_button(body, "Last action · score breakdown", _events)

func _card(id: String) -> Dictionary:
	for card in state.get("deck", []):
		if str(card.get("id", "")) == id: return card
	return {}

func _card_button(parent: Node, id: String, selection: Array, action: Callable) -> Button:
	var card := _card(id)
	var rank := int(card.get("rank", 2))
	var rank_name := str(rank)
	if rank >= 11: rank_name = ["J", "Q", "K", "A"][clampi(rank - 11, 0, 3)]
	var suit := clampi(int(card.get("suit", 0)), 0, 3)
	var order := selection.find(id)
	var caption := "%s %s" % [rank_name, ["♠", "♥", "♦", "♣"][suit]]
	caption += "
#%s" % (order + 1) if order >= 0 else "
%s" % ["SPADE", "HEART", "DIAM", "CLUB"][suit]
	if int(card.get("bonus_chips", 0)) > 0: caption += " +%s" % card.bonus_chips
	var button := _button(parent, caption, action)
	button.custom_minimum_size = Vector2(48, 68)
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("a83d43") if suit in [1, 2] else Color("243c42"))
	button.add_theme_color_override("font_hover_color", Color("243c42"))
	button.add_theme_color_override("font_pressed_color", Color("243c42"))
	button.add_theme_stylebox_override("normal", _style(Color("f9d58e") if order >= 0 else CREAM, GOLD if order >= 0 else Color("d7c6a4"), 5))
	button.add_theme_stylebox_override("hover", _style(Color("fff1d6"), GOLD, 5))
	button.add_theme_stylebox_override("pressed", _style(Color("f9d58e"), GOLD, 5))
	button.tooltip_text = "%s of %s • selection order determines scoring order" % [rank_name, ["Spades", "Hearts", "Diamonds", "Clubs"][suit]]
	return button

func _select(id: String) -> void:
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
	_label(body, "THE NIGHT MARKET", 23, GOLD)
	_label(body, "Modifiers resolve left to right. Shape your next hand.", 13)
	var offers: Array = state.get("shop", [])
	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var box := _panel(body)
		_label(box, "◆  " + str(offer.get("name", offer.get("id", "Offer"))), 18, GOLD)
		_label(box, str(offer.get("description", offer.get("kind", ""))), 14)
		_button(box, "Buy  $%s" % offer.get("cost", 0), func(): _act({"type": "BUY", "slot": i})).disabled = int(state.get("money", 0)) < int(offer.get("cost", 0)) or bool(offer.get("sold", false))
	_button(body, "Reroll offers  $%s" % state.get("reroll_cost", 5), func(): _act({"type": "REROLL"})).disabled = int(state.get("money", 0)) < int(state.get("reroll_cost", 5))
	_button(body, "Round receipt", _events)
	_button(footer, "Next table →", func(): _act({"type": "NEXT"}))

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
		var row := HBoxContainer.new()
		panel.add_child(row)
		_button(row, "←", func(): _move_modifier(i, -1), 48).disabled = i == 0
		_button(row, "→", func(): _move_modifier(i, 1), 48).disabled = i == mods.size() - 1
		_button(row, "Sell $%s" % maxi(1, int(item.get("cost", 0)) / 2), func(): _close_overlay(); _act({"type": "SELL", "index": i}); _inventory()).disabled = state.get("phase", "") != "shop"
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
	for item in state.get("modifiers", []): ids.append(item.get("id", ""))
	var swap = ids[index]
	ids[index] = ids[index + direction]
	ids[index + direction] = swap
	_act({"type": "REORDER", "ids": ids})
	_inventory()

func _use_item(index: int) -> void:
	var item: Dictionary = state.get("consumables", [])[index]
	var id := str(item.get("id", ""))
	var name_text := str(item.get("name", ""))
	if id.begins_with("study") or name_text.begins_with("Study") or item.get("target_count", -1) == 0:
		_close_overlay()
		_act({"type": "USE", "index": index, "targets": []})
	else:
		target_index = index
		target_ids.clear()
		_target_picker()

func _target_picker() -> void:
	var box := _modal("Choose one card")
	_label(box, "The item permanently changes this card in your deck.")
	var ids: Array = state.get("hand_ids", []).duplicate()
	if state.get("phase", "") == "shop":
		ids.clear()
		for card in state.get("deck", []): ids.append(card.get("id", ""))
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for id in ids:
		_card_button(grid, str(id), target_ids, func(): target_ids = [str(id)]; _target_picker())
	var fixed_actions: Node = box.get_parent().get_parent()
	var apply := _button(fixed_actions, "Apply item", func(): _close_overlay(); _act({"type": "USE", "index": target_index, "targets": target_ids.duplicate()}))
	apply.disabled = target_ids.size() != 1
	fixed_actions.move_child(apply, fixed_actions.get_child_count() - 2)

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
