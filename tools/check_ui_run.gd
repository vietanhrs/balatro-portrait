extends SceneTree
var failures = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func settle() -> void:
	for i in range(5): await process_frame
func capture(label: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/ui/integration-%s.png" % label)
func run() -> void:
	var replay = JSON.parse_string(FileAccess.get_file_as_string("res://tests/core/winning_replay.json"))
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui._new_run(int(replay.seed))
	var actions = 0
	var captured = {}
	for action in replay.actions:
		var expected = ui.engine.dispatch(ui.state, action)
		check(expected.error == "", "Replay action valid")
		if action.type in ["PLAY", "DISCARD"]:
			for id in action.ids: ui._select(str(id))
			check(ui.selected == action.ids, "Stable card selection matches replay")
			ui._act({"type": action.type, "ids": ui.selected.duplicate()})
		else:
			ui._act(action)
		check(ui.state == expected.state, "UI commits engine result")
		check(not ui.save_failed, "Every UI action saves")
		check(ui.saves.load_run() == ui.state, "Disk checkpoint equals committed state")
		actions += 1
		if not captured.has(ui.state.phase):
			captured[ui.state.phase] = true
			await capture(ui.state.phase)
		if actions % 25 == 0:
			var prior = ui.state.duplicate(true)
			ui.queue_free()
			await settle()
			ui = load("res://scenes/main.tscn").instantiate()
			root.add_child(ui)
			await settle()
			ui._resume()
			check(ui.state == prior, "Fresh UI instance resumes exact persisted checkpoint")
		await process_frame
	check(ui.state.phase == "won" and ui.state.rounds_won == 24, "Full honest replay wins 24 rounds")
	# Loss path uses only legal low-scoring actions, never fixture state edits.
	ui._new_run(9)
	ui._act({"type": "SELECT_BLIND"})
	while ui.state.phase == "playing":
		ui._act({"type": "PLAY", "ids": [ui.state.hand_ids[0]]})
	check(ui.state.phase == "lost", "Real exhausted-hands loss")
	await capture("lost")
	ui._new_run(531)
	ui._act({"type": "SELECT_BLIND"})
	for dimensions in [Vector2i(360,640), Vector2i(430,932)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("%sx%s" % [dimensions.x, dimensions.y])
	ui.saves.clear_run()
	ui.queue_free()
	await settle()
	print("UI_FULL_RUN actions=", actions, " rounds=24 fresh_resume=6 real_loss=true failures=", failures)
	quit(1 if failures else 0)
