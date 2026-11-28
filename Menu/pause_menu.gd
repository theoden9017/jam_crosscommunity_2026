extends CanvasLayer

## Menu di pausa: Esc lo apre e lo chiude. Mette in pausa l'albero di scena,
## quindi si fermano anche nemici, ondate, danni e piazzamento.
## Questo nodo usa process_mode = ALWAYS per continuare a ricevere input in pausa.

const MAIN_MENU := "res://Menu/main.tscn"
const SETTINGS_SCENE := preload("res://Menu/settings.tscn")
const QUIT_CONFIRM_SCENE := preload("res://Menu/quit_confirm.tscn")

@onready var _root: Control = $Root
@onready var _resume_button: Button = $Root/Panel/VBox/Resume

var _settings_instance: Control
var _quit_dialog: Control


func _ready() -> void:
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(_settings_instance):
		# Esc con le opzioni aperte le chiude (salvando), come il pulsante "Chiudi".
		_settings_instance._on_button_pressed()
	elif get_tree().paused:
		resume()
	else:
		pause()


func pause() -> void:
	get_tree().paused = true
	_root.visible = true
	_resume_button.grab_focus()


func resume() -> void:
	if is_instance_valid(_settings_instance):
		_settings_instance._on_button_pressed()
	if is_instance_valid(_quit_dialog):
		_quit_dialog.close()
	_root.visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	resume()


func _on_settings_pressed() -> void:
	if is_instance_valid(_settings_instance) or is_instance_valid(_quit_dialog):
		return
	# Se il livello è stato avviato direttamente (F6) le impostazioni non sono ancora caricate.
	if GameController._settings.is_empty():
		GameController._settings = GameController.load_settings(GameController._defaults)
	_settings_instance = SETTINGS_SCENE.instantiate()
	_root.add_child(_settings_instance)


func _on_main_menu_pressed() -> void:
	# SceneTransition toglie la pausa a schermo nero, prima di cambiare scena.
	SceneTransition.change_scene(MAIN_MENU)


# Apre la conferma di uscita (Esc la chiude da sola, senza riprendere il gioco).
func _on_quit_pressed() -> void:
	if is_instance_valid(_quit_dialog) or is_instance_valid(_settings_instance):
		return
	_quit_dialog = QUIT_CONFIRM_SCENE.instantiate()
	_root.add_child(_quit_dialog)
