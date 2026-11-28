extends Node

# blocking = true se l'elemento piazzato modifica il flow field.
signal block_added(blocking: bool)
# Cambia il numero di elementi piazzati: l'HUD aggiorna i pulsanti.
signal inventory_changed
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
# Quanti elementi di ogni tipo sono stati piazzati (chiave = nome in OBJECTS).
var _placed_count := {}


const OBJECTS = {
	"STRILLONE": {
		"label": "Strillone",
		"scene": preload("res://placeable/strillone.tscn"),
		"ghostname": "StrilGhost",
		"blocking": false,
		# Costo in quote sindacali e numero massimo piazzabile nel livello.
		"cost": 40,
		"max": 6
	},
	"VOLANTINATORE": {
		"label": "Volantinatore",
		"scene": preload("res://placeable/volantinatore.tscn"),
		"ghostname": "VolantGhost",
		"blocking": false,
		"cost": 60,
		"max": 4
	},
	"STRISCIONE": {
		"label": "Striscione",
		"scene": preload("res://placeable/stricione.tscn"),
		"ghostname": "StriscGhost",
		"blocking": true,
		"cost": 25,
		"max": 10
	},
	"GAZEBO": {
		"label": "Gazebo",
		"scene": preload("res://placeable/gazebo.tscn"),
		"ghostname": "GazebGhost",
		"blocking": true,
		"cost": 80,
		"max": 2
	}
}


# ----------------------------------------
# COSTI E LIMITI
# ----------------------------------------

func get_cost(obj: String) -> int:
	return OBJECTS[obj]["cost"]


func get_max_count(obj: String) -> int:
	return OBJECTS[obj]["max"]


func get_placed_count(obj: String) -> int:
	return _placed_count.get(obj, 0)


func get_remaining(obj: String) -> int:
	return maxi(0, get_max_count(obj) - get_placed_count(obj))


## Vero se ci sono fondi e unità disponibili per iniziare a piazzare questo elemento.
func can_start_placement(obj: String) -> bool:
	return get_remaining(obj) > 0 and GameController.can_afford(get_cost(obj))


# Attiva la modalità costruzione e crea una copia trasparente dell'elemento.
func begin_placement(obj: String) -> void:
	if not OBJECTS.has(obj) or not can_start_placement(obj):
		return
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
	_placement_is_valid = can_start_placement(_obj) \
		and flow_field_bounds.can_place_placeable(_ghost, OBJECTS[_obj]["blocking"])
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
	# I fondi si scalano solo alla conferma, non alla selezione.
	if not GameController.spend_union_funds(get_cost(_obj)):
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
	_placed_count[_obj] = get_placed_count(_obj) + 1
	# Se l'elemento viene rimosso, la sua unità torna disponibile.
	placed.tree_exited.connect(_on_placed_removed.bind(_obj))
	block_added.emit(blocking)
	inventory_changed.emit()
	return placed


func _on_placed_removed(obj: String) -> void:
	if not is_inside_tree():
		return
	_placed_count[obj] = maxi(0, get_placed_count(obj) - 1)
	inventory_changed.emit()
