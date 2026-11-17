extends SceneTree
var ui
var failures := 0
var prefix := ""
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(5): await process_frame
func capture(label: String) -> void:
	await settle()
	check_controls(ui.frame, label)
	if is_instance_valid(ui.overlay): check_controls(ui.overlay, label)
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await process_frame
		root.get_texture().get_image().save_png("res://tests/ui/" + prefix + label + ".png")
func check_controls(node: Node, label: String) -> void:
	if node is Button and node.is_visible_in_tree():
		if (node.size.x < 47.9 or node.size.y < 47.9) and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			push_error("Small control " + label + " " + str(node.size)); failures += 1
		if not Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(node.get_global_rect()):
			push_error("Outside viewport " + label + " " + str(node.get_global_rect())); failures += 1
	for child in node.get_children(): check_controls(child, label)
func run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	# Fixtures must never replace a real checkpoint.
	ui.saves = null
	for dimensions in [Vector2i(360,640),Vector2i(430,932)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		prefix = "redesign-%sx%s-" % [dimensions.x,dimensions.y]
		ui.reduced_motion = true
		ui._new_run(531)
		ui.save_failed = false
		ui._render()
		await capture("route")
		ui._act({"type":"SELECT_BLIND"})
		ui.save_failed = false
		ui._render()
		await capture("playing")
		for id in ui.state.hand_ids.slice(0,3): ui._select(id)
		await capture("selected")
		ui.reduced_motion = false
		ui._act({"type":"PLAY", "ids":ui.selected.duplicate()})
		await create_timer(0.6).timeout
		await capture("scoring")
		ui._finish_animation()
		ui.reduced_motion = true
		# Visual fixtures only: not balance or engine correctness evidence.
		ui.state.phase = "cashout"
		ui.state.round_score = 428
		ui.state.receipt = {"line_items":[{"label":"Blind reward","amount":3},{"label":"Unused hands","amount":3},{"label":"Interest","amount":0}],"money_before":4,"interest_base":4,"interest_cap":5,"total":6,"money_after":10,"paid":false}
		ui._render()
		await capture("receipt")
		ui.state.phase = "shop"
		ui.state.money = 20
		var passive = ui.engine.modifier("ember")
		passive.merge({"family":"passive","kind":"modifier","offer_id":"visual1","instance_id":"visual1"},true)
		var study = ui.engine.consumable("study_flush")
		study.merge({"family":"planet","kind":"consumable","offer_id":"visual2"},true)
		ui.state.shop = [passive,study]
		ui.state.voucher_offer = {"name":"Extra Hand","description":"One extra hand per round.","cost":10}
		ui.state.pack_offers = [{"family":"tarot","cost":4,"count":3,"choose":1},{"family":"planet","cost":4,"count":3,"choose":1}]
		ui._render()
		await capture("shop")
		ui._offer_detail(passive,0)
		await capture("detail")
		ui._close_overlay()
		ui.state.phase = "pack_select"
		var mutation = ui.engine.consumable("rank_lift")
		ui.state.pack_state = {"family":"tarot","remaining":1,"options":[mutation,ui.engine.consumable("scarlet_dye"),ui.engine.consumable("prune")],"target_ids":ui.state.hand_ids.duplicate()}
		ui.pack_choice = 0
		ui._render()
		await capture("pack")
		ui.targeting_pack = true
		ui.target_required = 1
		ui.target_ids = [ui.state.hand_ids[0]]
		ui._target_picker()
		await capture("targeting")
		ui._close_overlay()
	ui.queue_free()
	await settle()
	print("REDESIGN_VISUAL_FIXTURES failures=",failures)
	quit(1 if failures else 0)
