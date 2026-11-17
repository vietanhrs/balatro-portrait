extends SceneTree
# Run only against v1 core, in an isolated user directory, before integration.
func _initialize() -> void:
	var engine = load("res://core/game_engine.gd")
	var state = engine.new_run(1)
	if state.version != 1:
		quit(2)
		return
	var file = FileAccess.open(OS.get_environment("LEGACY_FIXTURE"), FileAccess.WRITE)
	file.store_buffer(var_to_bytes(state))
	file.close()
	quit()
