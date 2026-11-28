extends Control



var livello := "res://Levels/stage01.tscn"
var settings := preload("res://Menu/settings.tscn")
var credits := preload("res://Menu/credits.tscn")
var quit_confirm := preload("res://Menu/quit_confirm.tscn")

# Finestra di crediti o conferma uscita aperta (una alla volta).
var _dialog: Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameController._settings = GameController.load_settings(GameController._defaults)
	GameController.load_settings(GameController._settings)
	GameController._inGame = GameController.load_inGame(GameController._defaults_inGame)
	GameController.load_inGame(GameController._inGame)
	GameController._apply_settings()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_new_game_btm_pressed() -> void:
	SceneTransition.change_scene(livello)


func _on_settings_btm_pressed() -> void:
	var settings_instance = settings.instantiate()
	add_child(settings_instance)


# Chiede conferma: il salvataggio e l'uscita li gestisce quit_confirm.gd.
func _on_end_btm_pressed() -> void:
	_open_dialog(quit_confirm)


func _on_credits_btm_pressed() -> void:
	_open_dialog(credits)


func _open_dialog(scene: PackedScene) -> void:
	if is_instance_valid(_dialog):
		return
	_dialog = scene.instantiate()
	add_child(_dialog)
