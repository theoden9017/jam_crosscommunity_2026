extends Node

# Gestisce anteprima e conferma del piazzamento delle barracks.

@onready var world: Node3D = get_parent()
@onready var camera: Camera3D = world.get_node("Camera3D")
@onready var flow_field_bounds: FlowField3D = $"../FlowFieldBounds"

var _ghost: Node3D
var _yaw := 0.0
var _ghost_material: StandardMaterial3D
var _placement_is_valid := false

# Attiva la modalità costruzione e crea una copia trasparente della barracks.
func begin_placement() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = preload("res://tower.tscn").instantiate()
	_ghost.name = "TowerGhost"
	world.add_child(_ghost)
	_ghost.remove_from_group("blocks")
	_yaw = 0.0
	_set_ghost_non_blocking()
	_set_ghost_material()
	_update_ghost_position()


# Consuma gli input durante il piazzamento, così non attivano il panning.
func _input(event: InputEvent) -> void:
	if not is_instance_valid(_ghost):
		return

	if event is InputEventMouseMotion:
		_update_ghost_position()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_placement()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rotate_ghost(PI / 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rotate_ghost(-PI / 12.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()
		get_viewport().set_input_as_handled()


# Disattiva fisica e collisioni sulla copia fantasma.
func _set_ghost_non_blocking() -> void:
	var body := _ghost.get_node_or_null("StaticBody3D") as StaticBody3D
	if body:
		body.collision_layer = 0
		body.collision_mask = 0
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape:
			shape.disabled = true


# Applica un materiale semitrasparente per distinguere l'anteprima.
func _set_ghost_material() -> void:
	var mesh := _ghost.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.albedo_color = Color(0.2, 0.9, 0.35, 0.42)
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = _ghost_material


# Proietta il mouse sul piano del terreno e posiziona l'anteprima.
func _update_ghost_position() -> void:
	if not is_instance_valid(_ghost):
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if hit != null:
		_ghost.global_position = hit
		_ghost.rotation.y = _yaw
		_refresh_placement_validity()


# Controlla la connettività e colora il fantasma verde o rosso.
func _refresh_placement_validity() -> void:
	_placement_is_valid = flow_field_bounds.can_place_blocks(_ghost.global_position, _yaw, world.target, world.spawn_area_shape01)
	if _ghost_material:
		if _placement_is_valid:
			_ghost_material.albedo_color = Color(0.2, 0.9, 0.35, 0.42)
		else:
			_ghost_material.albedo_color = Color(1.0, 0.15, 0.12, 0.48)


# Ruota il fantasma a scatti di 15 gradi.
func _rotate_ghost(angle: float) -> void:
	_yaw = wrapf(_yaw + angle, 0.0, TAU)
	_ghost.rotation.y = _yaw
	_update_ghost_position()


# Crea la struttura reale e lascia al mondo il ricalcolo del flow field.
func _confirm_placement() -> void:
	if not _placement_is_valid:
		return
	var placement_position := _ghost.global_position
	var placement_yaw := _yaw
	_ghost.queue_free()
	_ghost = null
	var block: Node3D = world.add_block(placement_position)
	block.rotation.y = placement_yaw


# Annulla la modalità costruzione con il tasto destro.
func _cancel_placement() -> void:
	_ghost.queue_free()
	_ghost = null
