extends Node

@export var camera: Camera3D
@export var pan_sensitivity: float = 0.01
@export var pan_limit_bottom: Vector2 = Vector2(-4, 6)
@export var pan_limit_top: Vector2 = Vector2(10, 9)
var _is_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_panning = event.pressed
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _is_panning:
		_pan_camera(event.relative)
		get_viewport().set_input_as_handled()


# Sposta la camera sul piano X/Z seguendo il trascinamento del mouse.
func _pan_camera(mouse_delta: Vector2) -> void:
	var right := camera.global_basis.x
	right.y = 0.0
	if right.length_squared() > 0.001:
		right = right.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()
	var movement := -right * mouse_delta.x + forward * mouse_delta.y
	camera.global_position += movement * pan_sensitivity
	
		# Applica i limiti di movimento
	camera.global_position.x = clampf(
		camera.global_position.x,
		pan_limit_bottom.x,
		pan_limit_top.x
	)

	camera.global_position.z = clampf(
		camera.global_position.z,
		pan_limit_bottom.y,
		pan_limit_top.y
	)
