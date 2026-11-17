extends SceneTree
const Save = preload("res://platform/save_store.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void:
	var fixture = OS.get_environment("LEGACY_FIXTURE")
	if fixture.is_empty() or not FileAccess.file_exists(fixture):
		push_error("LEGACY_FIXTURE must name a captured real v1 Variant fixture; isolate HOME/XDG first")
		quit(2)
		return
	var old = bytes_to_var(FileAccess.get_file_as_bytes(fixture))
	var engine = load("res://core/game_engine.gd")
	if not engine.has_method("migrate_save"):
		push_error("BLOCKED: v2 migrate_save not available")
		quit(2)
		return
	Save.clear_run()
	var payload = var_to_bytes(old)
	var file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_buffer(Save.MAGIC.to_ascii_buffer())
	file.store_buffer(var_to_bytes({"format": Save.FORMAT, "payload": payload, "sha256": Save._digest(payload)}))
	file.close()
	var original_bytes = FileAccess.get_file_as_bytes(Save.PATH)
	var migrated = Save.load_run()
	check(not migrated.is_empty(), "real v1 fixture migrates")
	if migrated.is_empty():
		quit(1)
		return
	check(migrated.version == 2 and migrated.mode == "practice", "legacy uses v2 Practice")
	for key in ["deck", "money", "rng_state", "seed", "hand_ids", "draw_ids", "used_ids"]:
		check(migrated[key] == old[key], "migration preserves " + key)
	check(FileAccess.get_file_as_bytes(Save.LEGACY) == original_bytes, "exact original envelope archived")
	check(Save.save_run(migrated), "migrated snapshot writes")
	check(Save.load_run() == migrated, "v2 exact roundtrip")
	file = FileAccess.open(Save.PATH, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	check(Save.load_run() == migrated, "v1 backup migrates after v2 primary corruption")
	Save.clear_run()
	check(FileAccess.get_file_as_bytes(Save.LEGACY) == original_bytes, "reset preserves migration archive")
	quit(1 if failures else 0)
