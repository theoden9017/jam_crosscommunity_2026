extends Node

## Autoload "SceneTransition": cambio scena con dissolvenza attraverso il nero.
## Uso: SceneTransition.change_scene("res://Levels/stage01.tscn")
## Gira anche con il gioco in pausa e, a schermo nero, toglie la pausa prima del cambio.

signal transition_started(path: String)
signal transition_finished(path: String)

const DEFAULT_FADE_OUT := 0.4
const DEFAULT_FADE_IN := 0.6

var _layer: CanvasLayer
var _veil: ColorRect
var _tween: Tween
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "Veil"
	_layer.layer = 128
	add_child(_layer)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.focus_mode = Control.FOCUS_ALL
	_veil.visible = false
	_veil.gui_input.connect(_on_veil_gui_input)
	_layer.add_child(_veil)


func is_transitioning() -> bool:
	return _busy


## Scurisce, cambia scena e schiarisce sulla nuova.
## fade_out_time = 0 se lo schermo è già nero (es. fine dello splash).
## Restituisce false se una transizione è già in corso.
func change_scene(path: String, fade_out_time := DEFAULT_FADE_OUT, fade_in_time := DEFAULT_FADE_IN) -> bool:
	if _busy:
		return false
	_busy = true
	transition_started.emit(path)
	_block_input(true)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_veil, "color:a", 1.0, fade_out_time)
	_tween.tween_callback(_swap_scene.bind(path))
	# Un frame di margine perché la nuova scena sia nell'albero prima di schiarire.
	_tween.tween_interval(0.05)
	_tween.tween_property(_veil, "color:a", 0.0, fade_in_time)
	_tween.tween_callback(_finish.bind(path))
	return true


## Scurisce lo schermo e chiude il gioco.
func quit_game(fade_out_time := DEFAULT_FADE_OUT) -> void:
	if _busy:
		return
	_busy = true
	_block_input(true)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_veil, "color:a", 1.0, fade_out_time)
	_tween.tween_callback(get_tree().quit)


func _swap_scene(path: String) -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneTransition: impossibile caricare '%s' (errore %d)." % [path, error])


func _finish(path: String) -> void:
	_block_input(false)
	_busy = false
	transition_finished.emit(path)


# Durante la transizione il velo (sopra a tutto) intercetta i clic e prende il focus,
# così consuma anche tastiera e pad: i menu sotto non ricevono pressioni accidentali.
func _block_input(blocked: bool) -> void:
	_veil.visible = blocked
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP if blocked else Control.MOUSE_FILTER_IGNORE
	if blocked:
		_veil.grab_focus()
	else:
		_veil.release_focus()


func _on_veil_gui_input(_event: InputEvent) -> void:
	_veil.accept_event()
