extends Node3D



@export_range(1, 5, 1) var _level:int
@export var spawn_interval: float = 1.0
@onready var match_controller: Node = $MatchController
@onready var match_controller_target: Node3D = $Target
@onready var grey_box: Node3D = $GreyBox
@onready var camera_3d: Camera3D = $Camera3D

@onready var flow_field_bounds: FlowField3D = $FlowFieldBounds
@onready var target: Node3D = $Target
@onready var spawn_area_shape01: CollisionShape3D = $Spawn01/SpawnArea/CollisionShape3D
@onready var spawn_area_shape02: CollisionShape3D = $Spawn02/SpawnArea/CollisionShape3D
@onready var spawn_01: Node3D = $Spawn01
@onready var spawn_02: Node3D = $Spawn02

var _spawn_timer := 0.0
var _flow_debug_root: Node3D
var _blocks_count := 0
@onready var block_placing: Node = $BlockPlacing

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_level = GameController.actual_level 
	level_setup(_level)
	_flow_debug_root = Node3D.new()
	_flow_debug_root.name = "FlowFieldDebug"
	add_child(_flow_debug_root)
	flow_field_bounds.init_grid_from_bounds(_flow_debug_root)
	flow_field_bounds.rebuild_flow_field(update_field(), target)
	match_controller_target = target

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		match_controller.spawn_enemy_wave(spawn_01)


func level_setup(level: int):
	if level== 1:
		pass
	elif level== 2:
		pass
	else:
		pass

func update_field()->  Array[Node3D]:
	var blocks: Array[Node3D]
	_collect_blocks(self, blocks)
	return blocks


func _collect_blocks(parent: Node, blocks: Array[Node3D]) -> void:
	for node in parent.get_children():
		if node.is_in_group("blocks") and node is Node3D:
			blocks.append(node as Node3D)
		_collect_blocks(node, blocks)

func _on_flow_field_bounds_field_reviewed() -> void:
	pass






func _on_hud_block_selected() -> void:
	block_placing.begin_placement("BLOCK")

func _on_hud_tower_selected() -> void:
	block_placing.begin_placement("TOWER")


func _on_block_placing_block_added() -> void:
	flow_field_bounds.rebuild_flow_field(update_field(), target)
