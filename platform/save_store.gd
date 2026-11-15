extends RefCounted
## Versioned binary Variant saves preserve signed 64-bit RNG values exactly.
const PATH = "user://run.save"
const BACKUP = "user://run.save.bak"
const TEMP = "user://run.save.tmp"
const FORMAT = 1
const MAGIC = "VCSAVE01"
const BACKUP_TEMP = "user://run.save.bak.tmp"
const MAX_BYTES = 4194304

static func _valid(state: Dictionary) -> bool:
	var engine = load("res://core/game_engine.gd")
	return engine != null and engine.validate_save(state)

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES or file.get_length() < 8:
		return {}
	if file.get_buffer(8).get_string_from_ascii() != MAGIC:
		return {}
	var envelope = bytes_to_var(file.get_buffer(file.get_length() - 8))
	if not envelope is Dictionary or envelope.get("format") != FORMAT:
		return {}
	var payload = envelope.get("payload")
	if not payload is PackedByteArray or envelope.get("sha256") != _digest(payload):
		return {}
	var state = bytes_to_var(payload)
	if not state is Dictionary or not _valid(state):
		return {}
	return state

static func _digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func load_run() -> Dictionary:
	var state = _read(PATH)
	return _read(BACKUP) if state.is_empty() else state

static func save_run(state: Dictionary) -> bool:
	if not _valid(state):
		return false
	var payload = var_to_bytes(state)
	var bytes = var_to_bytes({"format": FORMAT, "payload": payload, "sha256": _digest(payload)})
	if bytes.size() + MAGIC.length() > MAX_BYTES:
		return false
	var file = FileAccess.open(TEMP, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_buffer(bytes)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or _read(TEMP).is_empty():
		return false
	# Only a validated primary may replace the last known-good backup.
	if not _read(PATH).is_empty():
		if DirAccess.copy_absolute(PATH, BACKUP_TEMP) != OK or _read(BACKUP_TEMP).is_empty():
			return false
		if DirAccess.rename_absolute(BACKUP_TEMP, BACKUP) != OK:
			return false
	return DirAccess.rename_absolute(TEMP, PATH) == OK

static func clear_run() -> void:
	for path in [PATH, BACKUP, TEMP, BACKUP_TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
