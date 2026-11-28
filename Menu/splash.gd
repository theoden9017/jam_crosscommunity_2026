extends Control

## Schermate iniziali con i loghi. Ogni figlio di $Slides è una schermata:
## appare in dissolvenza, resta visibile, scompare in dissolvenza, poi tocca alla successiva.
## Per aggiungere, togliere o riordinare le schermate basta modificare i figli di Slides nell'editor.
## Clic, tasto o pulsante del pad saltano la schermata corrente; Esc salta tutto.

@export_file("*.tscn") var next_scene: String = "res://Menu/main.tscn"
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_in_time: float = 0.8
@export_range(0.0, 10.0, 0.1, "suffix:s") var hold_time: float = 1.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var fade_out_time: float = 0.8
## Pausa sul nero tra una schermata e l'altra (e prima della prima).
@export_range(0.0, 3.0, 0.05, "suffix:s") var gap_time: float = 0.35
## Dissolvenza dal nero con cui compare la scena successiva (il menu iniziale).
@export_range(0.0, 3.0, 0.05, "suffix:s") var next_scene_fade_in_time: float = 0.8
## Se si salta tutto con Esc, tempo per scurire lo schermo prima del cambio scena.
@export_range(0.0, 1.0, 0.05, "suffix:s") var skip_fade_out_time: float = 0.25

@onready var _slides: Control = $Slides

var _tween: Tween
var _index := -1
var _finished := false


func _ready() -> void:
	for slide in _slides.get_children():
		if slide is CanvasItem:
			slide.visible = false
			slide.modulate.a = 0.0
	_show_next.call_deferred()


func _show_next() -> void:
	if _finished:
		return
	_index += 1
	if _index >= _slides.get_child_count():
		_go_to_next_scene()
		return
	var slide := _slides.get_child(_index) as CanvasItem
	if slide == null:
		_show_next()
		return
	slide.visible = true
	slide.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_interval(gap_time)
	_tween.tween_property(slide, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(slide, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(_end_slide.bind(slide))


func _end_slide(slide: CanvasItem) -> void:
	slide.visible = false
	_show_next()


# Salta la schermata corrente con una dissolvenza in uscita veloce.
func _skip_current() -> void:
	if _index < 0 or _index >= _slides.get_child_count():
		return
	var slide := _slides.get_child(_index) as CanvasItem
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(slide, "modulate:a", 0.0, minf(0.2, fade_out_time) * slide.modulate.a)
	_tween.tween_callback(_end_slide.bind(slide))


func _go_to_next_scene() -> void:
	if _finished:
		return
	_finished = true
	if _tween:
		_tween.kill()
	# Alla fine normale lo schermo è già nero: niente dissolvenza in uscita.
	var current: CanvasItem = null
	if _index >= 0 and _index < _slides.get_child_count():
		current = _slides.get_child(_index) as CanvasItem
	var already_black := current == null or not current.visible or current.modulate.a <= 0.0
	SceneTransition.change_scene(next_scene, 0.0 if already_black else skip_fade_out_time, next_scene_fade_in_time)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_go_to_next_scene()
		else:
			_skip_current()
	elif (event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
		get_viewport().set_input_as_handled()
		_skip_current()
