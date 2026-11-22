extends Node


@export var enemy_scene: PackedScene
@export var target: Node3D
@export var flowfield: FlowField3D
#@onready var target_area_shape: CollisionShape3D = $Target/TargetArea/CollisionShape3D

@export_range(4, 30, 1) var minimum_enemies_per_wave: int = 4
@export_range(4, 30, 1) var maximum_enemies_per_wave: int = 10

var target_area_shape: CollisionShape3D 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var n1 = target.get_children()
	var n2 = n1[0].get_children()
	target_area_shape = n2[0]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Crea un gruppo casuale di nemici in posizioni casuali dentro la shape di Spawn.
func spawn_enemy_wave(spawn_area_shape: Node3D) -> void:
	var low_count := mini(minimum_enemies_per_wave, maximum_enemies_per_wave)
	var high_count := maxi(minimum_enemies_per_wave, maximum_enemies_per_wave)
	var wave_size := randi_range(low_count, high_count)
	for _i in range(wave_size):
		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		var area_extents := _get_spawn_area_extents(spawn_area_shape)
		var local_offset := Vector3(
			randf_range(-area_extents.x, area_extents.x),
			randf_range(-area_extents.y, area_extents.y),
			randf_range(-area_extents.z, area_extents.z)
		)
		enemy.global_position = spawn_area_shape.global_transform * local_offset
		enemy.set_flow_field(flowfield, flowfield._field_revision)
		enemy.set_target_position(target.global_position)
		enemy.set_target_shape(target_area_shape)

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
