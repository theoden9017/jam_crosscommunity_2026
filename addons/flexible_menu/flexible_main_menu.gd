@tool
extends Control

const SettingsStore = preload("res://addons/flexible_menu/settings_store.gd")
const SaveRepository = preload("res://addons/flexible_menu/save_repository.gd")

## Un menu autosufficiente. Le funzioni specifiche del gioco sono esposte come segnali.
signal new_game_requested
signal continue_requested(save_data: Dictionary)
signal load_game_requested(save_data: Dictionary)
signal settings_requested
signal credits_requested
signal quit_requested
signal accessibility_changed(values: Dictionary)

@export_category("Branding")
@export var game_title := "GAME TITLE"
@export_multiline var credits_text := "Creato con Godot"
@export var theme_override: Theme
@export var background_color: Color = Color("00000000")

@export_category("Voci del menu")
@export var show_new_game := true
@export var show_continue := true
@export var show_load_game := true
@export var show_settings := true
@export var show_credits := true
@export var show_quit := true

@export_category("Pagine integrate")
@export var use_builtin_settings := true
@export var enable_save_system := true
@export var enable_audio_settings := true
@export var enable_display_settings := true
@export var enable_accessibility_settings := true
@export var enable_controls_settings := true
## Lascia vuoto per mostrare tutte le azioni Input Map non riservate all'interfaccia.
@export var remappable_actions: PackedStringArray = []
@export var enable_language_settings := true
@export var supported_locales: PackedStringArray = []

@export_category("Integrazione gioco")
@export_file("*.tscn") var new_game_scene := ""
@export_file("*.tscn") var after_load_scene := ""
@export var master_bus: StringName = &"Master"
@export var music_bus: StringName = &"Music"
@export var effects_bus: StringName = &"Effect"

var _content: VBoxContainer
var _settings: Dictionary
var _awaiting_action := StringName()
var _defaults := {
	"master_volume": 1.0, "music_volume": 1.0, "effects_volume": 1.0,
	"fullscreen": false, "resolution": Vector2i(1280, 720),
	"large_text": false, "high_contrast": false, "reduce_motion": false,
	"subtitles": true, "locale": "",
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings = SettingsStore.load_values(_defaults)
	_apply_saved_bindings()
	_apply_settings()
	show_main_page()

func _clear_page() -> void:
	for child in get_children():
		child.queue_free()
	var background := ColorRect.new()
	background.color = background_color if not _settings.get("high_contrast", false) else Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	if theme_override: panel.theme = theme_override
	center.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	panel.add_child(_content)

func _heading(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42 if not _settings.get("large_text", false) else 54)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(title)

func _button(text: String, callback: Callable, disabled := false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, 52)
	result.disabled = disabled
	result.focus_mode = Control.FOCUS_ALL
	result.pressed.connect(callback)
	_content.add_child(result)
	return result

func show_main_page() -> void:
	_clear_page()
	_heading(game_title)
	var first: Button
	if show_new_game: first = _button(tr("FM_NEW_GAME"), _new_game)
	if show_continue:
		var continue_button := _button(tr("FM_CONTINUE"), _continue_game, not enable_save_system or not SaveRepository.has_any_slot())
		if first == null: first = continue_button
	if show_load_game and enable_save_system:
		var load_button := _button(tr("FM_LOAD_GAME"), show_load_page)
		if first == null: first = load_button
	if show_settings:
		var settings_button := _button(tr("FM_SETTINGS"), show_settings_page if use_builtin_settings else func(): settings_requested.emit())
		if first == null: first = settings_button
	if show_credits: _button(tr("FM_CREDITS"), show_credits_page)
	if show_quit and not OS.has_feature("web"): _button(tr("FM_QUIT"), _quit)
	if first: first.call_deferred("grab_focus")

func show_settings_page() -> void:
	_clear_page()
	_heading(tr("FM_SETTINGS"))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 420)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(tabs)
	var game_tab := _make_tab(tabs, tr("FM_GAME"))
	var graphics_tab := _make_tab(tabs, tr("FM_GRAPHICS"))
	var audio_tab := _make_tab(tabs, tr("FM_AUDIO"))

	# Gioco: preferenze che non dipendono dall'hardware dell'utente.
	if enable_accessibility_settings:
		_add_check(game_tab, tr("FM_LARGE_TEXT"), "large_text", func(_v): show_settings_page())
		_add_check(game_tab, tr("FM_REDUCE_MOTION"), "reduce_motion", _accessibility_value_changed)
		_add_check(game_tab, tr("FM_SUBTITLES"), "subtitles", _accessibility_value_changed)
	if enable_controls_settings:
		_add_control_rebinds(game_tab)
	if enable_language_settings:
		_add_language_selector(game_tab)
	if game_tab.get_child_count() == 0:
		_add_empty_state(game_tab)

	# Grafica: impostazioni di presentazione; quelle desktop non sono offerte sul web.
	if enable_display_settings and not OS.has_feature("web"):
		_add_check(graphics_tab, tr("FM_FULLSCREEN"), "fullscreen", func(_v): _apply_display())
		_add_resolution_selector(graphics_tab)
	if enable_accessibility_settings:
		_add_check(graphics_tab, tr("FM_HIGH_CONTRAST"), "high_contrast", func(_v): show_settings_page())
	if graphics_tab.get_child_count() == 0:
		_add_empty_state(graphics_tab)

	# Audio: i bus assenti vengono ignorati in sicurezza dal servizio impostazioni.
	if enable_audio_settings:
		_add_slider(audio_tab, tr("FM_MASTER_VOLUME"), "master_volume", func(v): SettingsStore.apply_audio(master_bus, v))
		_add_slider(audio_tab, tr("FM_MUSIC"), "music_volume", func(v): SettingsStore.apply_audio(music_bus, v))
		_add_slider(audio_tab, tr("FM_EFFECTS"), "effects_volume", func(v): SettingsStore.apply_audio(effects_bus, v))
	else:
		_add_empty_state(audio_tab)
	_button(tr("FM_RESET_DEFAULTS"), _restore_defaults)
	_button(tr("FM_BACK"), _save_and_show_main)

func _make_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroll.add_child(page)
	return page

func _add_empty_state(container: VBoxContainer) -> void:
	var empty := Label.new()
	empty.text = tr("FM_NO_OPTIONS")
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(empty)

func _add_slider(container: VBoxContainer, label_text: String, key: String, changed: Callable) -> void:
	var label := Label.new(); label.text = label_text; container.add_child(label)
	var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 1; slider.step = 0.01; slider.value = _settings[key]
	slider.value_changed.connect(func(value): _settings[key] = value; changed.call(value))
	container.add_child(slider)

func _add_check(container: VBoxContainer, label_text: String, key: String, changed: Callable) -> void:
	var check := CheckButton.new(); check.text = label_text; check.button_pressed = _settings[key]
	check.toggled.connect(func(value): _settings[key] = value; changed.call(value))
	container.add_child(check)

func _add_resolution_selector(container: VBoxContainer) -> void:
	var label := Label.new(); label.text = tr("FM_RESOLUTION"); container.add_child(label)
	var option := OptionButton.new()
	var resolutions := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
	for resolution in resolutions:
		option.add_item("%d × %d" % [resolution.x, resolution.y])
		if resolution == _settings["resolution"]: option.select(option.item_count - 1)
	option.item_selected.connect(func(index): _settings["resolution"] = resolutions[index]; _apply_display())
	container.add_child(option)

func _add_language_selector(container: VBoxContainer) -> void:
	var label := Label.new()
	label.text = tr("FM_LANGUAGE")
	container.add_child(label)
	var option := OptionButton.new()
	var locales := supported_locales
	if locales.is_empty():
		locales = TranslationServer.get_loaded_locales()
	if locales.is_empty():
		locales.append(TranslationServer.get_locale())
	for locale in locales:
		option.add_item(TranslationServer.get_locale_name(locale))
		if locale == _settings["locale"]: option.select(option.item_count - 1)
	option.item_selected.connect(func(index): _settings["locale"] = locales[index]; TranslationServer.set_locale(_settings["locale"]); show_settings_page())
	container.add_child(option)

func _add_control_rebinds(container: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = tr("FM_CONTROLS")
	heading.add_theme_font_size_override("font_size", 24)
	container.add_child(heading)
	var actions: Array[StringName] = []
	if remappable_actions.is_empty():
		for action in InputMap.get_actions():
			if not str(action).begins_with("ui_"):
				actions.append(action)
	else:
		for action in remappable_actions:
			if InputMap.has_action(action): actions.append(action)
	for action in actions:
		var button := Button.new()
		button.text = "%s: %s" % [action, _binding_text(action)]
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(func(): _begin_rebind(action, button))
		container.add_child(button)

func _binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	return tr("FM_UNASSIGNED") if events.is_empty() else events[0].as_text()

func _begin_rebind(action: StringName, button: Button) -> void:
	_awaiting_action = action
	button.text = tr("FM_REBIND_PROMPT").format({"action": action})
	button.grab_focus()

func show_load_page() -> void:
	_clear_page(); _heading(tr("FM_SAVED_GAMES"))
	var slots := SaveRepository.list_slots()
	if slots.is_empty():
		var empty := Label.new(); empty.text = tr("FM_NO_SAVED_GAMES"); empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _content.add_child(empty)
	for slot in slots:
		_button("%s" % slot.get("label", slot.get("slot_id", "Salvataggio")), func(): _load_game(slot))
	_button(tr("FM_BACK"), show_main_page)

func show_credits_page() -> void:
	credits_requested.emit()
	_clear_page(); _heading(tr("FM_CREDITS"))
	var text := Label.new(); text.text = tr("FM_CREDITS_TEXT"); text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _content.add_child(text)
	_button(tr("FM_BACK"), show_main_page)

func _new_game() -> void:
	new_game_requested.emit()
	_change_scene_if_set(new_game_scene)

func _continue_game() -> void:
	var slots := SaveRepository.list_slots()
	if not slots.is_empty(): _load_game(slots[0])

func _load_game(slot: Dictionary) -> void:
	var most_recent := SaveRepository.list_slots().front()
	if slot == most_recent:
		continue_requested.emit(slot)
	else:
		load_game_requested.emit(slot)
	_change_scene_if_set(after_load_scene)

func _quit() -> void:
	quit_requested.emit(); get_tree().quit()

func _save_and_show_main() -> void:
	SettingsStore.save_values(_settings)
	show_main_page()

func _restore_defaults() -> void:
	_settings = _defaults.duplicate(true)
	_apply_settings()
	show_settings_page()

func _apply_settings() -> void:
	SettingsStore.apply_audio(master_bus, _settings["master_volume"])
	SettingsStore.apply_audio(music_bus, _settings["music_volume"])
	SettingsStore.apply_audio(effects_bus, _settings["effects_volume"])
	_apply_display()
	if not str(_settings["locale"]).is_empty(): TranslationServer.set_locale(_settings["locale"])
	accessibility_changed.emit(_settings.duplicate(true))

func _apply_saved_bindings() -> void:
	var bindings := SettingsStore.load_bindings()
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, bindings[action])

func _accessibility_value_changed(_value: bool) -> void:
	accessibility_changed.emit(_settings.duplicate(true))

func _apply_display() -> void:
	if Engine.is_editor_hint():
		return
	SettingsStore.apply_display(_settings["fullscreen"], _settings["resolution"])

func _change_scene_if_set(path: String) -> void:
	if not path.is_empty(): get_tree().change_scene_to_file(path)

func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_action.is_empty():
		var can_bind := false
		if event is InputEventKey:
			can_bind = event.pressed and not event.echo
		elif event is InputEventJoypadButton:
			can_bind = event.pressed
		if can_bind:
			InputMap.action_erase_events(_awaiting_action)
			InputMap.action_add_event(_awaiting_action, event)
			SettingsStore.save_binding(_awaiting_action, event)
			_awaiting_action = &""
			show_settings_page()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and _content and _content.get_child_count() > 0:
		show_main_page()
		get_viewport().set_input_as_handled()
