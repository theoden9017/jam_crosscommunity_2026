extends Node

# blocking = true se l'elemento piazzato modifica il flow field.
signal block_added(blocking: bool)
# Gestisce anteprima e conferma del piazzamento degli elementi.

@onready var world: Node3D = get_parent()
@onready var camera: Camera3D = world.get_node("Camera3D")
@onready var flow_field_bounds: FlowField3D = $"../FlowFieldBounds"

const COLOR_VALID := Color(0.2, 0.9, 0.35, 0.42)
const COLOR_INVALID := Color(1.0, 0.15, 0.12, 0.48)

var _ghost: Node3D
var _obj: String
var _yaw := 0.0
var _ghost_material: StandardMaterial3D
var _placement_is_valid := false


const OBJECTS = {
	"STRILLONE": {
		"scene": preload("res://placeable/strillone.tscn"),
		"ghostname": "StrilGhost",
		"blocking": false
	},
	"VOLANTINATORE": {
		"scene": preload("res://placeable/volantinatore.tscn"),
		"ghostname": "VolantGhost",
		"blocking": false
	},
	"STRISCIONE": {
		"scene": preload("res://placeable/stricione.tscn"),
		"ghostname": "StriscGhost",
		"blocking": true
	},
	"GAZEBO": {
		"scene": preload("res://placeable/gazebo.tscn"),
		"ghostname": "GazebGhost",
		"blocking": true
	}
}


# Attiva la modalità costruzione e crea una copia trasparente dell'elemento.
func begin_placement(obj: String) -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_obj = obj
	_ghost = OBJECTS[obj]["scene"].instantiate()
	_ghost.name = OBJECTS[obj]["ghostname"]
	# Il fantasma non deve processare né stare nella fisica: altrimenti la sua
	# AreaInfluence danneggerebbe i nemici durante l'anteprima.
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(_ghost)
	_ghost.remove_from_group("blocks")
	_ghost.remove_from_group("placeables")
	_yaw = 0.0
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


# Applica un materiale semitrasparente a tutte le mesh del fantasma
# (anche quelle annidate sotto Skeleton3D, come in Strillone e Volantinatore).
func _set_ghost_material() -> void:
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.albedo_color = COLOR_VALID
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pending: Array[Node] = [_ghost]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D:
			(current as MeshInstance3D).material_override = _ghost_material
		for child in current.get_children():
			pending.append(child)


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


# Chiede al flow field se il piazzamento è valido e colora il fantasma.
func _refresh_placement_validity() -> void:
	_placement_is_valid = flow_field_bounds.can_place_placeable(_ghost, OBJECTS[_obj]["blocking"])
	if _ghost_material:
		_ghost_material.albedo_color = COLOR_VALID if _placement_is_valid else COLOR_INVALID


# Ruota il fantasma a scatti di 15 gradi.
func _rotate_ghost(angle: float) -> void:
	_yaw = wrapf(_yaw + angle, 0.0, TAU)
	_ghost.rotation.y = _yaw
	_update_ghost_position()


# Crea l'elemento reale e lascia al mondo l'aggiornamento del flow field.
func _confirm_placement() -> void:
	# Ricontrolla al clic: il risultato è in cache, quindi non costa nulla.
	_refresh_placement_validity()
	if not _placement_is_valid:
		return
	var placement_position := _ghost.global_position + Vector3(0, 0.5, 0)
	var placement_yaw := _yaw
	_ghost.queue_free()
	_ghost = null
	add_block(placement_position, placement_yaw)


# Annulla la modalità costruzione con il tasto destro.
func _cancel_placement() -> void:
	_ghost.queue_free()
	_ghost = null


func add_block(world_position: Vector3, yaw: float) -> Node3D:
	var blocking: bool = OBJECTS[_obj]["blocking"]
	var placed: Node3D = OBJECTS[_obj]["scene"].instantiate()
	placed.add_to_group("placeables")
	add_child(placed)
	if blocking:
		placed.add_to_group("blocks")
	else:
		placed.remove_from_group("blocks")
	placed.global_position = world_position
	placed.rotation.y = yaw
	block_added.emit(blocking)
	return placed
