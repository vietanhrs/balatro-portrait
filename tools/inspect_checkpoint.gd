extends SceneTree
func _initialize() -> void:
	var bytes = FileAccess.get_file_as_bytes(OS.get_environment("CHECKPOINT"))
	var envelope = bytes_to_var(bytes.slice(8))
	var state = bytes_to_var(envelope.payload)
	print(JSON.stringify(state))
	quit()
