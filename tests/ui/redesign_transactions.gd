extends SceneTree
var ui
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle() -> void:
	for i in range(4): await process_frame
func best_ids(state: Dictionary) -> Array:
	var best: Array = []
	var score := -1
	for mask in range(1, 1 << state.hand_ids.size()):
		var ids: Array = []
		for i in range(state.hand_ids.size()):
			if mask & (1 << i): ids.append(state.hand_ids[i])
		if ids.size() > 5: continue
		var value: Dictionary = ui.engine.preview(state, ids)
		if int(value.total) > score: score = int(value.total); best = ids
	return best
func run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui._new_run(531)
	ui._act({"type":"SELECT_BLIND"})
	var action := {"type":"PLAY","ids":best_ids(ui.state)}
	var expected: Dictionary = ui.engine.dispatch(ui.state,action)
	ui._act(action)
	check(ui.state == expected.state,"Play commits once before presentation")
	check(ui.saves.load_run() == ui.state,"Presentation checkpoint already on disk")
	var seq: int = ui.state.action_seq
	ui._act(action)
	check(ui.state.action_seq == seq,"Input locked during animation")
	ui._finish_animation()
	check(ui.state.action_seq == seq,"Skip presentation never dispatches")
	ui.reduced_motion = true
	while ui.state.phase == "playing": ui._act({"type":"PLAY","ids":best_ids(ui.state)})
	check(ui.state.phase == "cashout","Reach real receipt")
	var receipt_state: Dictionary = ui.state.duplicate(true)
	ui.state = {}; ui._resume()
	check(ui.state == receipt_state,"Receipt resume exact")
	ui._act({"type":"CASH_OUT"})
	check(ui.state.phase == "shop","Cashout enters shop")
	var paid: Dictionary = ui.state.duplicate(true)
	ui._act({"type":"CASH_OUT"})
	check(ui.state == paid,"Repeated cashout does not pay twice")
	var offer: Dictionary = ui.state.pack_offers[0]
	ui._act({"type":"OPEN_PACK","offer_id":offer.offer_id})
	check(ui.state.phase == "pack_select","Open real paid pack")
	var pack: Dictionary = ui.state.duplicate(true)
	ui.state = {}; ui._resume()
	check(ui.state == pack,"Pack resume exact; no repayment or reroll")
	ui._back()
	check(ui.screen == "menu" and ui.state == pack,"Back preserves pending pack")
	ui._resume()
	ui._act({"type":"SKIP_PACK"})
	check(ui.state.phase == "shop","Skip pack returns to shop")
	ui.queue_free()
	await settle()
	print("REDESIGN_TRANSACTIONS failures=",failures)
	quit(1 if failures else 0)
