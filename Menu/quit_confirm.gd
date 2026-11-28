extends Control

## Conferma di uscita.
## "Sì" -> torna alla schermata principale (se si è già lì, chiude solo la finestra).
## "No" -> salva e chiude il gioco.
## Esc chiude la finestra senza fare nulla.

const MAIN_MENU := "res://Menu/main.tscn"


func _ready() -> void:
	$Panel/Buttons/Yes.grab_focus()


func close() -> void:
	queue_free()


func _on_yes_pressed() -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == MAIN_MENU:
		close()
	else:
		SceneTransition.change_scene(MAIN_MENU)


func _on_no_pressed() -> void:
	GameController._inGame["actual_level"] = GameController.actual_level
	GameController.save_inGame(GameController._inGame)
	SceneTransition.quit_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
