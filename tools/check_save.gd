extends SceneTree
const Save = preload("res://platform/save_store.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void:
	var engine = load("res://core/game_engine.gd")
	if engine == null:
		push_error("Core unavailable")
		quit(2)
		return
	Save.clear_run()
	var initial: Dictionary = engine.new_run(9223372036854775806)
	check(Save.save_run(initial), "valid snapshot writes")
	check(Save.load_run() == initial, "exact dictionary and 64-bit RNG roundtrip")
	var next: Dictionary = engine.dispatch(initial, {"type": "SELECT_BLIND"}).state
	check(Save.save_run(next), "next snapshot writes")
	var restored = Save.load_run()
	check(restored == next, "playing snapshot roundtrip")
	check(engine.dispatch(restored, {"type": "DISCARD", "ids": restored.hand_ids.slice(0, 1)}) == engine.dispatch(next, {"type": "DISCARD", "ids": next.hand_ids.slice(0, 1)}), "RNG continuation parity")
	check(not Save.save_run({}), "invalid snapshot rejected")
	check(Save.load_run() == next, "invalid write preserves primary")
	var file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	check(Save.load_run() == initial, "corrupt primary restores backup")
	Save.clear_run()
	file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string("unrecoverable")
	file.close()
	check(Save.load_run().is_empty() and Save.recovery_required, "unrecoverable save requires explicit reset")
	check(not Save.save_run(initial), "new run cannot silently overwrite unrecoverable save")
	check(FileAccess.get_file_as_string(Save.PATH) == "unrecoverable", "failed recovery retains original bytes")
	Save.clear_run()
	check(Save.load_run().is_empty(), "clear removes primary and backup")
	quit(1 if failures else 0)
