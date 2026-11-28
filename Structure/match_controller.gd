extends Node

## Gestisce la progressione delle ondate: pausa -> spawn uno alla volta -> ondata successiva.
## La composizione delle ondate sta in una WaveTable (.tres), modificabile dall'Inspector.

signal wave_started(wave_number: int, total_waves: int)
## Emesso quando l'ultima ondata della tabella ha finito di comparire (mai in endless).
signal all_waves_spawned

@export var enemy_scene: PackedScene
@export var target: Node3D
@export var flowfield: FlowField3D
@export var isEndless: bool
@export var debug_enemy_health_bars: bool = false

## Tabella delle ondate del livello.
@export var wave_table: WaveTable = preload("res://Enemies/waves_stage01.tres")

# Tipi usati dalla modalità endless.
@export_group("Tipi di nemico")
@export var operaio_stats: EnemyStats = preload("res://Enemies/operaio.tres")
@export var impiegato_stats: EnemyStats = preload("res://Enemies/impiegato.tres")
@export var venditore_stats: EnemyStats = preload("res://Enemies/venditore.tres")
@export var dirigente_stats: EnemyStats = preload("res://Enemies/dirigente.tres")
@export_group("")

@export_group("Endless")
@export_range(4, 30, 1) var minimum_enemies_per_wave: int = 4
@export_range(4, 30, 1) var maximum_enemies_per_wave: int = 10
@export_range(0.0, 60.0, 0.5, "suffix:s") var endless_pause_before: float = 8.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var endless_spawn_interval: float = 0.25
@export_group("")

enum State { IDLE, WAITING, SPAWNING, WAITING_CLEAR, DONE }

var target_area_shape: CollisionShape3D
# Numero dell'ondata corrente, partendo da 0.
var indexflow := 0

var _state := State.IDLE
var _spawn_area: Node3D
var _current_wave: WaveData
var _spawn_queue: Array[EnemyStats] = []
var _timer := 0.0


func _ready() -> void:
	var n1 = target.get_children()
	var n2 = n1[0].get_children()
	target_area_shape = n2[0]


## Avvia la sequenza delle ondate dall'area di spawn indicata.
func start_waves(spawn_area: Node3D) -> void:
	_spawn_area = spawn_area
	indexflow = 0
	_prepare_wave()


func get_total_waves() -> int:
	if isEndless or wave_table == null:
		return -1
	return wave_table.size()


## Secondi mancanti all'inizio della prossima ondata (0 se non si è in attesa).
func get_time_to_next_wave() -> float:
	return _timer if _state == State.WAITING else 0.0


func _process(delta: float) -> void:
	match _state:
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_begin_spawning()
		State.SPAWNING:
			_timer -= delta
			while _timer <= 0.0 and not _spawn_queue.is_empty():
				_spawn_enemy(_spawn_queue.pop_back())
				if _current_wave.spawn_interval <= 0.0:
					continue
				_timer += _current_wave.spawn_interval
			if _spawn_queue.is_empty():
				_finish_wave()
		State.WAITING_CLEAR:
			if get_tree().get_nodes_in_group("enemies").is_empty():
				_prepare_wave()


# Carica la prossima ondata (dalla tabella o generata) e avvia la pausa.
func _prepare_wave() -> void:
	_current_wave = _build_endless_wave() if isEndless else (wave_table.get_wave(indexflow) if wave_table else null)
	if _current_wave == null:
		_state = State.DONE
		all_waves_spawned.emit()
		return
	_timer = _current_wave.pause_before
	_state = State.WAITING


func _begin_spawning() -> void:
	_spawn_queue = _current_wave.build_spawn_list()
	_timer = 0.0
	_state = State.SPAWNING
	wave_started.emit(indexflow + 1, get_total_waves())


func _finish_wave() -> void:
	var wait_clear := _current_wave.wait_for_clear
	indexflow += 1
	if wait_clear:
		_state = State.WAITING_CLEAR
	else:
		_prepare_wave()


# Genera un'ondata casuale che cresce con il numero dell'ondata.
func _build_endless_wave() -> WaveData:
	var wave := WaveData.new()
	wave.pause_before = endless_pause_before
	wave.spawn_interval = endless_spawn_interval
	var low_count := mini(minimum_enemies_per_wave, maximum_enemies_per_wave) + indexflow
	var high_count := maxi(minimum_enemies_per_wave, maximum_enemies_per_wave) + indexflow
	for _i in range(randi_range(low_count, high_count)):
		var picked := _pick_endless_type()
		wave.enemies[picked] = wave.enemies.get(picked, 0) + 1
	return wave


func _spawn_enemy(enemy_stats: EnemyStats) -> void:
	var enemy := enemy_scene.instantiate()
	# Va assegnato prima di add_child, perché _ready lo legge.
	enemy.stats = enemy_stats
	add_child(enemy)
	enemy.set_debug_health_bar_enabled(debug_enemy_health_bars)
	GameController.CurrentWorkers += 1
	var area_extents := _get_spawn_area_extents(_spawn_area)
	var local_offset := Vector3(
		randf_range(-area_extents.x, area_extents.x),
		0,
		randf_range(-area_extents.z, area_extents.z)
	)
	enemy.global_position = _spawn_area.global_transform * local_offset
	enemy.set_flow_field(flowfield, flowfield._field_revision)
	enemy.set_target_position(target.global_position)
	enemy.set_target_shape(target_area_shape)


# Sceglie un tipo a caso, pesato su endless_weight.
func _pick_endless_type() -> EnemyStats:
	var types: Array[EnemyStats] = [operaio_stats, impiegato_stats, venditore_stats, dirigente_stats]
	var total := 0.0
	for t in types:
		total += t.endless_weight
	var roll := randf() * total
	for t in types:
		roll -= t.endless_weight
		if roll <= 0.0:
			return t
	return types[0]


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
