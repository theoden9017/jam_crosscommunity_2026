extends CharacterBody3D


# Velocità massima e regolarizzazione di accelerazione e sterzata.
@export var move_speed: float = 3.0
@export var acceleration: float = 12.0
@export var turn_speed_degrees: float = 240.0
@export_range(0.0, 0.5, 0.01) var crowd_variation: float = 0.16
@export_range(0.0, 2.0, 0.05) var crowd_variation_frequency: float = 0.45
@export var stuck_timeout: float = 5.0
@export var minimum_progress_distance: float = 0.25
@export var recovery_duration: float = 1.2

# Riferimenti al campo di flusso e alla forma che determina il despawn.
var _flow_field: Node
var _field_revision := -1
var _move_direction := Vector3.ZERO
var _target_position := Vector3.ZERO
var _target_shape: CollisionShape3D
var _wander_phase := 0.0
var _lane_bias := 0.0
var _speed_factor := 1.0
var _elapsed_time := 0.0
var _progress_check_position := Vector3.ZERO
var _stuck_check_timer := 0.0
var _recovery_timer := 0.0
var _recovery_direction := Vector3.ZERO


# Assegna a ogni nemico una lieve variazione individuale di traiettoria e velocità.
func _ready() -> void:
	_wander_phase = randf_range(0.0, TAU)
	_lane_bias = randf_range(-crowd_variation, crowd_variation)
	_speed_factor = randf_range(0.92, 1.08)
	_progress_check_position = global_position


# Salva la posizione del target; utile anche se il nodo target si muove.
func set_target_position(position: Vector3) -> void:
	_target_position = position


# Salva la CollisionShape del target usata per verificare l'ingresso nel volume.
func set_target_shape(shape: CollisionShape3D) -> void:
	_target_shape = shape


# Collega il nemico al gestore che fornisce le direzioni del campo condiviso.
func set_flow_field(flow_field: Node, revision: int) -> void:
	_flow_field = flow_field
	_field_revision = revision


# A ogni frame fisico controlla il target e muove l'enemy lungo il campo.
func _physics_process(delta: float) -> void:
	_elapsed_time += delta
	# Durante il recupero arretra brevemente e poi riprende il flow field.
	if _recovery_timer > 0.0:
		_recovery_timer = maxf(0.0, _recovery_timer - delta)
		_move_recovery_direction(delta)
		if _recovery_timer == 0.0:
			_stuck_check_timer = 0.0
			_progress_check_position = global_position
		return
	# Rimuove l'istanza non appena il centro entra nella forma del target.
	if is_instance_valid(_target_shape) and _is_inside_target_shape():
		queue_free()
		return

	# Se il campo non è disponibile, rallenta dolcemente fino a fermarsi.
	if not is_instance_valid(_flow_field):
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
		move_and_slide()
		return

	var direction: Vector3 = _flow_field.get_flow_direction(global_position)
	if direction.length_squared() < 0.0001:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
		move_and_slide()
		return

	# Il movimento avviene sul piano X/Z; ignora la componente verticale.
	direction.y = 0.0
	direction = direction.normalized()
	_check_for_stuck(delta, direction)
	if _recovery_timer > 0.0:
		_move_recovery_direction(delta)
		return
	# Applica un piccolo scostamento laterale, diverso per ogni istanza.
	# La sinusoide lenta evita cambi casuali bruschi da un frame al successivo.
	var lateral := Vector3(-direction.z, 0.0, direction.x)
	var sway := sin(_elapsed_time * crowd_variation_frequency + _wander_phase) * crowd_variation
	direction = (direction + lateral * (sway + _lane_bias)).normalized()
	if _move_direction.length_squared() < 0.0001:
		_move_direction = direction
	else:
		# Limita la rotazione per evitare cambi istantanei di direzione.
		var max_turn := deg_to_rad(turn_speed_degrees) * delta
		var current_angle := atan2(_move_direction.z, _move_direction.x)
		var target_angle := atan2(direction.z, direction.x)
		var angle_delta := wrapf(target_angle - current_angle, -PI, PI)
		var smoothed_angle := current_angle + clampf(angle_delta, -max_turn, max_turn)
		_move_direction = Vector3(cos(smoothed_angle), 0.0, sin(smoothed_angle))

	# Avvicina gradualmente la velocità attuale a quella desiderata.
	var desired_velocity := _move_direction * move_speed * _speed_factor
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	look_at(global_position + _move_direction, Vector3.UP)
	move_and_slide()


# Controlla ogni cinque secondi se il nemico ha fatto abbastanza progressi.
func _check_for_stuck(delta: float, desired_direction: Vector3) -> void:
	_stuck_check_timer += delta
	if _stuck_check_timer < stuck_timeout:
		return
	var traveled_distance := global_position.distance_to(_progress_check_position)
	if traveled_distance < minimum_progress_distance:
		_begin_recovery(desired_direction)
	_stuck_check_timer = 0.0
	_progress_check_position = global_position


# Sceglie una direzione all'indietro con una componente laterale casuale.
func _begin_recovery(desired_direction: Vector3) -> void:
	var backward := -desired_direction
	var lateral := Vector3(-desired_direction.z, 0.0, desired_direction.x)
	_recovery_direction = (backward + lateral * randf_range(-0.7, 0.7)).normalized()
	_recovery_timer = recovery_duration
	_move_direction = _recovery_direction


# Muove il nemico nella direzione di recupero con velocità controllata.
func _move_recovery_direction(delta: float) -> void:
	var recovery_velocity := _recovery_direction * move_speed * 0.75
	velocity.x = move_toward(velocity.x, recovery_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, recovery_velocity.z, acceleration * delta)
	if _recovery_direction.length_squared() > 0.0001:
		look_at(global_position + _recovery_direction, Vector3.UP)
	move_and_slide()


# Verifica se il nemico è dentro una CollisionShape3D di tipo BoxShape3D.
func _is_inside_target_shape() -> bool:
	var box := _target_shape.shape as BoxShape3D
	if box == null:
		return false
	# Trasforma il punto del nemico nello spazio locale della forma.
	var local_position := _target_shape.global_transform.affine_inverse() * global_position
	var half_size := box.size * 0.5
	return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y and absf(local_position.z) <= half_size.z
