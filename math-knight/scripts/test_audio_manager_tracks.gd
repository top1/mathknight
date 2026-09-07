extends SceneTree

func _init() -> void:
	var runner = Node.new()
	runner.set_script(load("res://scripts/test_audio_runner.gd"))
	root.call_deferred("add_child", runner)
