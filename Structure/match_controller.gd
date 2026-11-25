extends Node


@export var enemy_scene: PackedScene
@export var target: Node3D
@export var flowfield: FlowField3D
@export var isEndless: bool

var enemyflow_operaio: Array[int]
var enemyflow_impiegato: Array[int]
var enemyflow_venditore: Array[int]
var enemyflow_dirigente: Array[int]
var indexflow =0



@export_range(4, 30, 1) var minimum_enemies_per_wave: int = 4
@export_range(4, 30, 1) var maximum_enemies_per_wave: int = 10

var target_area_shape: CollisionShape3D 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var n1 = target.get_children()
	var n2 = n1[0].get_children()
	target_area_shape = n2[0]
	
	enemyflow_operaio = 	[10	,8,	15, 0, 0, 10 ,20, 0]
	enemyflow_impiegato = 	[10	,10	,20, 0, 0, 0 ,0, 0]
	enemyflow_venditore = 	[0	,1	,2, 0, 0, 5 ,6, 0]
	enemyflow_dirigente = 	[0	,0	,0, 0, 0, 0 ,1, 6]
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Crea un gruppo casuale di nemici in posizioni casuali dentro la shape di Spawn.
func spawn_enemy_wave(spawn_area_shape: Node3D) -> void:
	var wave_size = 0
	if isEndless:
		var low_count := mini(minimum_enemies_per_wave+indexflow, maximum_enemies_per_wave+indexflow)
		var high_count := maxi(minimum_enemies_per_wave+indexflow, maximum_enemies_per_wave+indexflow)
		wave_size = randi_range(low_count, high_count)
	else:
		if indexflow == enemyflow_operaio.size():
			return
		wave_size += enemyflow_operaio[indexflow]
		wave_size += enemyflow_impiegato[indexflow]
		wave_size += enemyflow_venditore[indexflow]
		wave_size += enemyflow_dirigente[indexflow]
	for _i in range(wave_size):
		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		GameController.CurrentWorkers+=1
		var area_extents := _get_spawn_area_extents(spawn_area_shape)
		var local_offset := Vector3(
			randf_range(-area_extents.x, area_extents.x),
			0, #randf_range(-area_extents.y, area_extents.y),
			randf_range(-area_extents.z, area_extents.z)
		)
		enemy.global_position = spawn_area_shape.global_transform * local_offset
		enemy.set_flow_field(flowfield, flowfield._field_revision)
		enemy.set_target_position(target.global_position)
		enemy.set_target_shape(target_area_shape)
	
	indexflow+=1

# Restituisce le semi-dimensioni della BoxShape usata come area di spawn.
func _get_spawn_area_extents(spawn_area_shape: Node3D) -> Vector3:
	var n1 = spawn_area_shape.get_children()
	var n2 = n1[0].get_children()
	spawn_area_shape = n2[0]
	var box := spawn_area_shape.shape as BoxShape3D
	if box == null:
		push_error("La CollisionShape3D di Spawn deve usare una BoxShape3D.")
		return Vector3.ZERO
	return box.size * 0.5
