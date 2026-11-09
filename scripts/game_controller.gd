class_name GameController extends Node

@export var gui : Control
@export var transition_controller : SceneTransitionController
@onready var debug: Debug = $Debug

var current_gui_scene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(&"flexible_menu_host")
	current_gui_scene = $GUI/SplashScreenManager
	
func _unhandled_input(event):
	if event.is_action_pressed("debug"):
		debug.visible = not debug.visible

func _physics_process(_delta: float) -> void:
	debug.add_debug_property("FPS", Engine.get_frames_per_second(), 1)


func change_gui_scene(
		new_scene: String, 
		delete: bool = true, 
		keep_running: bool = false, 
		transition: bool = true, 
		transition_in: String = "Fade In", 
		transition_out: String = "Fade Out", 
		seconds: float = 1.0
	) -> void:
		
	if transition:
		transition_controller.transition(transition_out, seconds)
		await transition_controller.animation_player.animation_finished
	if current_gui_scene != null:
		if delete:
			current_gui_scene.queue_free() # Removes node entirely
		elif keep_running:
			current_gui_scene.visible = false # Keeps in memory and running
		else:
			gui.remove_child(current_gui_scene) # Keeps in memory, does not run
	var packed_scene := load(new_scene) as PackedScene
	if packed_scene == null:
		push_error("Scena GUI non trovata: %s" % new_scene)
		return
	var new_gui := packed_scene.instantiate() as Control
	if new_gui == null:
		push_error("La scena GUI deve avere un nodo Control come radice: %s" % new_scene)
		return
	gui.add_child(new_gui)
	current_gui_scene = new_gui
	transition_controller.transition(transition_in, seconds)
