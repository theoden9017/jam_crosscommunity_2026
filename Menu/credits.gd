extends Control

## Schermata dei crediti ("Straordinari"). Il testo si modifica in Panel/Scroll/Text.
## Si chiude con il pulsante "Chiudi" o con Esc.


func _ready() -> void:
	$Panel/Close.grab_focus()


func close() -> void:
	queue_free()


func _on_close_pressed() -> void:
	close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
