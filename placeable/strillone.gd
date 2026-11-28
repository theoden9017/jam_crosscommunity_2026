extends Node3D

@export_range(0.0, 100.0, 0.5) var damage_per_second: float = 10.0

@onready var influence_area: Area3D = $AreaInfluence

var _damage_timers: Dictionary = {}


func _ready() -> void:
	influence_area.body_entered.connect(_on_body_entered)
	influence_area.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	for body_id in _damage_timers.keys():
		var body := instance_from_id(body_id) as Node
		if not is_instance_valid(body):
			_damage_timers.erase(body_id)
			continue
		var elapsed: float = _damage_timers[body_id] + delta
		while elapsed >= 1.0 and is_instance_valid(body):
			elapsed -= 1.0
			body.call("take_damage", damage_per_second)
		_damage_timers[body_id] = elapsed


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		_damage_timers[body.get_instance_id()] = 0.0


func _on_body_exited(body: Node3D) -> void:
	_damage_timers.erase(body.get_instance_id())
