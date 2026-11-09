extends RefCounted

const PATH := "user://flexible_menu_settings.cfg"

static func load_values(defaults: Dictionary) -> Dictionary:
	var values := defaults.duplicate(true)
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return values
	for key in defaults:
		values[key] = config.get_value("settings", key, defaults[key])
	return values

static func save_values(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings", key, values[key])
	config.save(PATH)

static func load_bindings() -> Dictionary:
	var bindings := {}
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return bindings
	if not config.has_section("input"):
		return bindings
	for action in config.get_section_keys("input"):
		var event := str_to_var(config.get_value("input", action, ""))
		if event is InputEvent:
			bindings[StringName(action)] = event
	return bindings

static func save_binding(action: StringName, event: InputEvent) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("input", action, var_to_str(event))
	config.save(PATH)

static func apply_audio(bus_name: StringName, linear_value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, linear_value <= 0.0)
	if linear_value > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear_value))

static func apply_display(fullscreen: bool, resolution: Vector2i) -> void:
	# Il browser gestisce autonomamente dimensioni e fullscreen: non forzarlo.
	if OS.has_feature("web"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen and resolution.x > 0 and resolution.y > 0:
		DisplayServer.window_set_size(resolution)
