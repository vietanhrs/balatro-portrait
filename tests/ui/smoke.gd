extends SceneTree
var failures := 0
var ui
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(5): await process_frame
func run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	check(ui.engine != null, "Real engine loaded")
	# Do not overwrite any player's checkpoint during automated testing.
	ui.saves = null
	ui.reduced_motion = true
	ui._new_run(531)
	check(ui.state.phase == "blind_select", "New run reaches blind selection")
	ui._act({"type":"SELECT_BLIND"})
	check(ui.state.phase == "playing", "Enter blind")
	var id: String = ui.state.hand_ids[0]
	ui._select(id)
	var before: Dictionary = ui.state.duplicate(true)
	ui._sort()
	check(ui.selected == [id], "Sorting preserves stable selection ID/order")
	check(ui.state == before, "Preview and sort do not mutate state")
	ui._act({"type":"DISCARD", "ids":[id]})
	check(ui.state.discards_left == 2, "Discard passes through engine")
	check(ui.selected.is_empty(), "Successful transaction clears selection")
	for dimensions in [Vector2i(360,640), Vector2i(430,932)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		check(ui.footer.get_global_rect().end.y <= dimensions.y + 1, "Bottom actions fit screen")
		check(ui.body.size.x <= dimensions.x, "No horizontal overflow in playing")
		for grid in ui.body.find_children("*", "GridContainer", true, false):
			check(grid.get_global_rect().end.y <= ui.footer.global_position.y, "Entire 4x2 hand visible above actions")
		for node in ui.find_children("*", "Button", true, false):
			check(node.size.y >= 48, "48dp button height: " + node.text)
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://tests/ui/portrait-%sx%s.png" % [dimensions.x, dimensions.y])
		ui._help()
		await settle()
		check(is_instance_valid(ui.overlay), "Help overlay opens")
		ui._back()
		check(not is_instance_valid(ui.overlay), "Back closes overlay")
	ui._select(str(ui.state.hand_ids[0]))
	ui._act({"type":"PLAY", "ids":ui.selected.duplicate()})
	check(not ui.event_lines.is_empty(), "Real action receipt available")
	ui._events()
	ui._close_overlay()
	# Presentation fixtures only: engine economy/terminal correctness lives in core tests.
	var actual: Dictionary = ui.state.duplicate(true)
	ui.state.phase = "shop"
	ui.state.shop = [{"id":"ember","kind":"modifier","name":"Ember Pin","description":"Add multiplier.","cost":4}]
	ui.state.modifiers = [{"id":"ember","name":"Ember Pin","description":"Add multiplier.","cost":4}]
	ui.state.consumables = [{"id":"rank_lift","name":"Rank Lift","description":"Raise one rank.","cost":4}]
	ui._render()
	await settle()
	ui._inventory()
	await settle()
	ui._use_item(0)
	await settle()
	check(ui.overlay.find_children("*", "Button", true, false).size() >= 54, "Shop deck picker includes 52 cards and actions")
	ui._close_overlay()
	for ending in ["won", "lost"]:
		ui.state.phase = ending
		ui._render()
		await settle()
	ui.state = actual
	ui._back()
	check(ui.screen == "menu", "Back opens menu")
	ui._resume()
	check(ui.screen == "game", "Resume live checkpoint")
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://tests/ui/smoke-playing.png")
	ui.queue_free()
	await settle()
	print("UI_SMOKE failures=", failures)
	quit(1 if failures else 0)
