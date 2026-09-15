@tool
extends EditorPlugin

var export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name: String = "MathKnightMLKit"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		if platform is EditorExportPlatformAndroid:
			return true
		return false

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["math_knight_mlkit/bin/debug/MathKnightMLKit-debug.aar"])
		else:
			return PackedStringArray(["math_knight_mlkit/bin/release/MathKnightMLKit-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.google.mlkit:digital-ink-recognition:18.1.0",
			"com.google.android.gms:play-services-tasks:18.2.0"
		])

	func _get_name() -> String:
		return _plugin_name
