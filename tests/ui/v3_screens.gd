extends SceneTree
var ui
var failures := 0
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	for i in range(5): await process_frame
	for button in ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			var in_scroll := false
			var ancestor: Node = button.get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer: in_scroll = true
				ancestor = ancestor.get_parent()
			# Scroll contents may extend vertically; their viewport must remain bounded.
			var rect: Rect2 = button.get_global_rect()
			if button.size.y < 48 or rect.position.x < 0 or rect.end.x > root.get_visible_rect().size.x or (not in_scroll and not Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(rect)):
				push_error(label + " button bounds " + button.text); failures += 1
	for scroll in ui.find_children("*", "ScrollContainer", true, false):
		if scroll.is_visible_in_tree() and not Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(scroll.get_global_rect()):
			push_error(label + " scroll viewport bounds"); failures += 1
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/ui/v3-" + label + ".png")
func run() -> void:
	ui = load("res://scenes/main.tscn").instantiate(); root.add_child(ui)
	ui.reduced_motion = true
	for dimensions in [Vector2i(360,640),Vector2i(430,932)]:
		root.size = dimensions; root.content_scale_size = dimensions
		var prefix := str(dimensions.x) + "-"
		ui.screen = "menu"; ui._render(); await capture(prefix + "menu")
		ui._run_setup(); await capture(prefix + "setup"); ui._close_overlay()
		ui._new_run(531); await capture(prefix + "route")
		ui._act({"type":"SELECT_BLIND"}); await capture(prefix + "hand")
		ui._select(str(ui.sorted_ids[0])); await capture(prefix + "selected")
		ui._statistics(); await capture(prefix + "statistics"); ui._close_overlay()
		ui._collections(); await capture(prefix + "collections"); ui._close_overlay()
		ui._settings(); await capture(prefix + "settings"); ui._close_overlay()
	print("V3_SCREENS failures=",failures); quit(failures)
