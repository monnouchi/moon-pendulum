extends SceneTree
## Preserve the engine's own license data with the distributable Web game.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass one output path for ENGINE_NOTICES.txt")
		quit(1)
		return
	var output := FileAccess.open(args[0],FileAccess.WRITE)
	if output == null:
		push_error("Cannot write engine notices")
		quit(1)
		return
	output.store_string("GODOT ENGINE\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHT INFORMATION\n\n")
	output.store_string(JSON.stringify(Engine.get_copyright_info(),"  ") + "\n\nTHIRD-PARTY LICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	for name in licenses:
		output.store_string(str(name) + "\n\n" + str(licenses[name]) + "\n\n")
	output.close()
	quit(0)
