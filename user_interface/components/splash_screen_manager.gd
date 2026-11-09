extends Control

@export var load_scene : PackedScene
@export var in_time : float = 0.5
@export var fade_in_time : float = 1.5
@export var pause_time : float = 1.5
@export var fade_out_time : float = 1.5
@export var out_time : float = 0.5
@export var splash_screen_container : Node

var splash_screens : Array
var _leaving := false


func _ready() -> void:
	get_screens()
	fade()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_go_to_menu()


func fade() -> void:
	for screen in splash_screens:
		var tween = self.create_tween()
		tween.tween_interval(in_time)
		tween.tween_property(screen, "modulate:a", 1.0, fade_in_time)
		tween.tween_interval(pause_time)
		tween.tween_property(screen, "modulate:a", 0.0, fade_out_time)
		tween.tween_interval(out_time)
		await tween.finished
	_go_to_menu()

func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if load_scene == null:
		push_error("SplashScreenManager richiede una scena menu in load_scene.")
		return
	var menu_host := get_tree().get_first_node_in_group(&"flexible_menu_host") as GameController
	if menu_host == null:
		push_error("SplashScreenManager non trova il nodo host del menu.")
		return
	menu_host.change_gui_scene(load_scene.resource_path, true, false, true, "Fade In", "Fade Out", 0.5)


func get_screens() -> void:
	splash_screens = splash_screen_container.get_children()
	for screen in splash_screens:
		screen.modulate.a = 0.0
