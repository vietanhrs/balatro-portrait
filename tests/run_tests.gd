extends SceneTree
## Standalone save suite. Core's own test runner remains independently runnable.
func _initialize() -> void:
	var output: Array = []
	var code = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/check_save.gd"], output, true)
	for line in output: print(line)
	quit(code)
