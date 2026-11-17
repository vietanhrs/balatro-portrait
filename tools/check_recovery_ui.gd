extends SceneTree
var failures = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var Save = load("res://platform/save_store.gd")
	Save.clear_run()
	var file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string("retained-corruption")
	file.close()
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	check(Save.recovery_required, "menu detects unrecoverable save")
	ui._confirm_new()
	check(is_instance_valid(ui.overlay) and ui.state.is_empty(), "new run requests explicit confirmation")
	ui._back()
	check(FileAccess.get_file_as_string(Save.PATH) == "retained-corruption", "Back cancels without discarding")
	ui._new_run(1)
	check(ui.state.is_empty(), "direct new run cannot bypass recovery gate")
	check(Save.archive_and_reset(), "confirmed recovery archives before reset")
	var found = false
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("run.save.recovery-"):
			found = FileAccess.get_file_as_string("user://"+name) == "retained-corruption"
	check(found, "original corrupt bytes available in archive")
	ui._new_run(1)
	check(not ui.state.is_empty() and not ui.save_failed, "new run saves after confirmed reset")
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)
