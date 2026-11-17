extends SceneTree
var ui
var failures := 0
var capture_index := 0
var capturing := false
var prefix := "360"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
func settle() -> void:
	for i in range(4): await process_frame
func frames() -> void:
	while capturing:
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/ui/v3-final-motion-%s-%03d.png" % [prefix, capture_index])
			capture_index += 1
		await create_timer(0.09).timeout
func run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui._run_setup()
	check(not ui.seed_input.visible and not ui.seeded_check.button_pressed, "seed hidden and random default")
	ui.seeded_check.button_pressed = true
	check(ui.seed_input.visible, "seed checkbox reveals input")
	ui._close_overlay()
	var seeds := {}
	for i in range(100): seeds[ui._random_seed()] = true
	check(seeds.size() == 100, "unique random starts")
	check(ui.engine.new_run(81) == ui.engine.new_run(81), "deterministic entered seed")
	for dimensions in [Vector2i(360,640), Vector2i(430,932)]:
		prefix = str(dimensions.x)
		root.size = dimensions
		root.content_scale_size = dimensions
		ui._new_run(531)
		ui.reduced_motion = false
		ui._act({"type":"SELECT_BLIND"})
		check(ui.animating, "initial deal locks input")
		await create_timer(1.2).timeout
		await settle()
		check(not ui.animating, "initial deal completes")
		var table_id: int = ui.table.get_instance_id()
		for hand_id in ui.sorted_ids:
			var hit := InputEventMouseButton.new()
			hit.button_index = MOUSE_BUTTON_LEFT
			hit.pressed = true
			hit.position = ui.cards[str(hand_id)].global_position + Vector2(12, 55)
			ui._input(hit)
			check(ui.selected.has(hand_id), "exposed card strip selectable")
			var duplicate := hit.duplicate()
			duplicate.device = InputEvent.DEVICE_ID_EMULATION
			ui._input(duplicate)
			check(ui.selected.has(hand_id), "emulated Android mouse cannot toggle touch twice")
			ui._select(str(hand_id))
		for button in ui.body.find_children("*", "Button", true, false): check(button.text != "+", "empty rails have no plus placeholders")
		var y: float = ui.cards[str(ui.sorted_ids[0])].position.y
		for id in ui.sorted_ids:
			check(is_equal_approx(ui.cards[str(id)].position.y, y), "one horizontal hand row")
			check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(ui.cards[str(id)].get_global_rect()), "hand in viewport")
		for suit in [true, false]:
			ui._set_sort(suit)
			for i in range(1, ui.sorted_ids.size()):
				var a: Dictionary = ui._card(str(ui.sorted_ids[i-1]))
				var b: Dictionary = ui._card(str(ui.sorted_ids[i]))
				check(a.suit <= b.suit if suit else a.rank >= b.rank, "sort order")
		await create_timer(0.3).timeout
		var id := str(ui.sorted_ids[0])
		var card: Control = ui.cards[id]
		var card_id := card.get_instance_id()
		ui._select(id)
		await create_timer(0.25).timeout
		var origin := card.position
		var dispatch_before: int = ui.dispatch_count
		capture_index = 0
		capturing = true
		frames()
		ui._act({"type":"PLAY", "ids":[id]})
		var committed: Dictionary = ui.state.duplicate(true)
		check(ui.saves.load_run() == committed, "save committed before motion")
		ui._act({"type":"PLAY", "ids":[id]})
		check(ui.dispatch_count == dispatch_before + 1, "one dispatch during locked timeline")
		await create_timer(0.15).timeout
		check(ui.table.get_instance_id() == table_id and card.get_instance_id() == card_id, "same table and real card nodes")
		check(card.position.distance_to(origin) > 10, "actual tween trajectory")
		var before_frozen: Dictionary = ui.snapshot.duplicate(true)
		var after_frozen: Dictionary = ui.after_snapshot.duplicate(true)
		await create_timer(0.8).timeout
		check(ui.snapshot == before_frozen and ui.after_snapshot == after_frozen, "presentation snapshots immutable")
		for tick in range(100):
			if not ui.animating: break
			await create_timer(0.1).timeout
		capturing = false
		check(not ui.animating, "play timeline finishes")
		check(ui.state == committed, "animation cannot mutate committed state")
		if ui.state.phase == "playing":
			check(ui.table.get_instance_id() == table_id, "table remains after refill")
			ui._select(str(ui.sorted_ids[0]))
			ui._act({"type":"DISCARD", "ids":ui.selected.duplicate()})
			var seq: int = ui.dispatch_count
			ui._back()
			check(not ui.animating and ui.dispatch_count == seq, "Back skips without redispatch")
			check(ui.cards.size() == ui.state.hand_ids.size(), "skip reconciles hand")
		ui._statistics(); check(is_instance_valid(ui.overlay), "statistics functional"); ui._close_overlay()
		ui._collections(); check(is_instance_valid(ui.overlay), "collections functional"); ui._close_overlay()
		ui._settings(); check(is_instance_valid(ui.overlay), "settings functional"); ui._close_overlay()
	print("V3_MOTION failures=", failures)
	quit(failures)
