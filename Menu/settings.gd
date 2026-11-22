extends Control


@onready var master_volume: HSlider = $Panel/HBoxContainer/Settings/master_volume
@onready var music_volume: HSlider = $Panel/HBoxContainer/Settings/music_volume
@onready var effect_volume: HSlider = $Panel/HBoxContainer/Settings/effect_volume


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	master_volume.value = GameController._settings["master_volume"]
	music_volume.value = GameController._settings["music_volume"]
	effect_volume.value = GameController._settings["effects_volume"]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	GameController.save_settings(GameController._settings)
	queue_free()


func _on_master_volume_drag_ended(value_changed: bool) -> void:
	GameController._settings["master_volume"] = master_volume.value
	GameController._update_volume("Master", master_volume.value)


func _on_music_volume_drag_ended(value_changed: bool) -> void:
	GameController._settings["music_volume"] = music_volume.value
	GameController._update_volume("Music", music_volume.value)


func _on_effect_volume_drag_ended(value_changed: bool) -> void:
	GameController._settings["effects_volume"] = effect_volume.value
	GameController._update_volume("Effect", effect_volume.value)
