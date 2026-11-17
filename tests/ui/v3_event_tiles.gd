extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate(); root.add_child(ui)
	ui.reduced_motion = true
	ui._new_run(531); ui._act({"type":"SELECT_BLIND"})
	for i in range(5): await process_frame
	ui.reduced_motion = false
	var ids: Array = [ui.sorted_ids[0]]
	ui._select(str(ids[0])); ui._act({"type":"PLAY", "ids":ids})
	await create_timer(0.9).timeout
	var chip_scale: Vector2 = ui.score_panels.chips.scale
	var mult_scale: Vector2 = ui.score_panels.mult.scale
	if chip_scale == Vector2.ONE or mult_scale != Vector2.ONE:
		push_error("card-chips event should pulse only chips"); quit(1); return
	ui._finish_animation()
	ui.reduced_motion = true; ui._save_preferences()
	var profile: Dictionary = ui.Profile.read_profile()
	assert(profile.settings.reduced_motion)
	print("V3_EVENT_TILES failures=0")
	quit()
