extends RefCounted
## Versioned binary Variant saves preserve signed 64-bit RNG values exactly.
const PATH = "user://run.save"
const BACKUP = "user://run.save.bak"
const TEMP = "user://run.save.tmp"
const FORMAT = 1
const MAGIC = "VCSAVE01"
const BACKUP_TEMP = "user://run.save.bak.tmp"
const MAX_BYTES = 4194304
# Retained across normal clear/new-run operations for manual recovery.
const LEGACY = "user://run.save.v1.archive"
static var last_load_error = ""
static var recovery_required = false

static func _valid(state: Dictionary) -> bool:
	var engine = load("res://core/game_engine.gd")
	return engine != null and engine.validate_save(state)

static func _read_raw(path: String) -> Dictionary:
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
	if not state is Dictionary:
		return {}
	return state

static func _read(path: String) -> Dictionary:
	var state = _read_raw(path)
	if _valid(state):
		return state
	if state.get("version", 0) == 1:
		var engine = load("res://core/game_engine.gd")
		if engine != null and engine.has_method("migrate_save"):
			var migrated = engine.migrate_save(state.duplicate(true))
			if migrated is Dictionary and _valid(migrated):
				return migrated
	return {}

static func _digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func load_run() -> Dictionary:
	last_load_error = ""
	recovery_required = false
	for path in [PATH, BACKUP]:
		var state = _read(path)
		if state.is_empty():
			continue
		if _read_raw(path).get("version", 0) == 1 and state.get("version", 0) != 1:
			if not FileAccess.file_exists(LEGACY):
				if DirAccess.copy_absolute(path, LEGACY) != OK or _read_raw(LEGACY) != _read_raw(path):
					last_load_error = "Cannot archive legacy save; original retained. Recovery required."
					recovery_required = true
					return {}
		return state
	recovery_required = FileAccess.file_exists(PATH) or FileAccess.file_exists(BACKUP)
	if recovery_required:
		last_load_error = "Save cannot be validated or migrated. Original files retained; confirm reset before starting over."
	return {}

static func save_run(state: Dictionary) -> bool:
	if not _valid(state) or recovery_required:
		return false
	# Refuse overwrite even if a caller did not load first.
	if (FileAccess.file_exists(PATH) or FileAccess.file_exists(BACKUP)) and load_run().is_empty():
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

static func archive_and_reset() -> bool:
	var stamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	for path in [PATH, BACKUP]:
		if FileAccess.file_exists(path):
			var archive = path + ".recovery-" + stamp
			if DirAccess.copy_absolute(path, archive) != OK or FileAccess.get_file_as_bytes(path) != FileAccess.get_file_as_bytes(archive):
				return false
	clear_run()
	return true

static func clear_run() -> void:
	# Explicit caller-confirmed reset only; never called by migration/load failure.
	recovery_required = false
	last_load_error = ""
	for path in [PATH, BACKUP, TEMP, BACKUP_TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
