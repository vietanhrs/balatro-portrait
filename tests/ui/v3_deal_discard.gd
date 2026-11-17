extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate(); root.add_child(ui)
	ui.reduced_motion = false
	ui._new_run(531); ui._act({"type":"SELECT_BLIND"})
	await process_frame
	var table_id: int = ui.table.get_instance_id()
	var first: Control = ui.cards[str(ui.sorted_ids[0])]
	var start := first.position
	await create_timer(0.2).timeout
	assert(first.position.distance_to(start) > 10)
	await create_timer(1.0).timeout
	var id := str(ui.sorted_ids[0])
	var previous: Array = ui.state.hand_ids.duplicate()
	ui._act({"type":"DISCARD", "ids":[id]})
	var committed: Dictionary = ui.state.duplicate(true)
	await create_timer(0.2).timeout
	assert(ui.table.get_instance_id() == table_id)
	assert(ui.cards.has(id))
	await create_timer(1.3).timeout
	assert(not ui.animating and ui.state == committed and not ui.cards.has(id))
	assert(ui.table.get_instance_id() == table_id)
	assert(ui.sorted_ids.size() == committed.hand_ids.size())
	var changed := false
	for card_id in ui.sorted_ids:
		if not previous.has(card_id): changed = true
	assert(changed)
	print("V3_DEAL_DISCARD failures=0")
	quit()
