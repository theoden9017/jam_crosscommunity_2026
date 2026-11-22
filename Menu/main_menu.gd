extends Control



var livello := "res://prototype/world.tscn"
var settings := preload("res://Menu/settings.tscn")


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
	get_tree().change_scene_to_file(livello)


func _on_settings_btm_pressed() -> void:
	var settings_instance = settings.instantiate()
	add_child(settings_instance)


func _on_end_btm_pressed() -> void:
	GameController._inGame["actual_level"]=  GameController.actual_level
	GameController.save_inGame(GameController._inGame)
	get_tree().quit()
