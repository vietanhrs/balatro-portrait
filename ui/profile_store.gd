extends RefCounted
## Only observations since this profile was created; never infer historical totals.
const PATH = "user://ui_profile.json"
static func read_profile() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	return value if value is Dictionary else {"settings": {}, "runs": 0, "plays": 0, "discards": 0, "wins": 0, "losses": 0, "best_hand": 0, "discovered": {}}
static func save_profile(profile: Dictionary) -> bool:
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(profile))
	file.close()
	return DirAccess.rename_absolute(PATH + ".tmp", PATH) == OK
