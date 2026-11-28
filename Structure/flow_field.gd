@tool
class_name FlowField3D
extends Node3D

signal field_reviewed

# ----------------------------------------
# PROPERTY
# ----------------------------------------

var _shape: Shape3D

@export_group("Shape")

@export var shape: Shape3D:
	get:
		return _shape
	set(value):
		if _shape == value:
			return

		if is_instance_valid(_shape):
			if _shape.changed.is_connected(_on_shape_changed):
				_shape.changed.disconnect(_on_shape_changed)

		_shape = value

		if is_instance_valid(_shape):
			_shape.changed.connect(_on_shape_changed)

		_update_preview()
@export var cell_size: float = 1.0
@export var show_flow_field: bool = true
@export var flow_arrow_height: float = 0.08


@export_range(0.0, 3.0, 0.1) var blocks_clearance: float = 0.6
@export_range(0.0, 1.0, 0.05) var placed_blocks_clearance: float = 0.1

var grid_origin: Vector2
var grid_world_size: Vector2
var grid_width: float
var grid_height: float
var _blocked: Array[bool] = []
var _distances: Array[float] = []

# --- Piazzamento (stessa griglia fine del flow field) ---
# 1 = cella occupata da un elemento già piazzato (bloccante o no).
var _occupied := PackedByteArray()
# 1 = cella di target o di spawn: non ci si può costruire sopra.
var _reserved := PackedByteArray()
# 1 = cella di spawn raggiungibile che deve restare collegata al target.
var _spawn_mask := PackedByteArray()
var _spawn_indices := PackedInt32Array()
var _goal_indices := PackedInt32Array()
var _spawn_areas: Array[Node3D] = []
# Buffer riusati dal test di connettività, per non allocare a ogni movimento del mouse.
var _test_blocked := PackedByteArray()
var _test_visited := PackedByteArray()
var _test_queue := PackedInt32Array()
# Cache dell'ultimo test: si ricalcola solo se cambiano le celle del ghost o il campo.
var _placement_cache_key := 0
var _placement_cache_result := false
var _field_revision := 0
var _flow: Array[Vector2] = []
var _escape_directions: Array[Vector2] = []
var _flow_debug_root: Node3D
var _flow_arrows: Array[Node3D] = []

# Le otto celle vicine usate per calcolare le distanze sulla griglia.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

# ----------------------------------------
# PREVIEW
# ----------------------------------------

@export_group("Preview")

@export var preview_color: Color = Color(0.2, 0.7, 1.0, 0.25):
	set(value):
		preview_color = value
		_update_preview()


var _preview: MeshInstance3D


# ----------------------------------------
# LIFECYCLE
# ----------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return

	_ensure_preview()
	_update_preview()


# ----------------------------------------
# PREVIEW MANAGEMENT
# ----------------------------------------

func _ensure_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if is_instance_valid(_preview):
		return

	_preview = get_node_or_null("_ShapePreview") as MeshInstance3D

	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.name = "_ShapePreview"

		add_child(_preview)

		# Non salvare l'anteprima nella scena
		_preview.owner = null


# ----------------------------------------
# SHAPE UPDATE
# ----------------------------------------

func _on_shape_changed() -> void:
	_update_preview()

func _update_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if not is_inside_tree():
		return

	_ensure_preview()

	if not is_instance_valid(_preview):
		return

	if _shape == null:
		_preview.mesh = null
		return

	# Generazione geometria
	_preview.mesh = _shape.get_debug_mesh()

	# Materiale trasparente
	var material := StandardMaterial3D.new()

	material.albedo_color = preview_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_preview.material_override = material

	# Nessuna ombra
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ----------------------------------------
# FLOWFIELD FUNCTIONS
# ----------------------------------------

func rebuild_flow_field(blocks: Array[Node3D], target: Node3D) -> void:
	_blocked.fill(false)
	for node in blocks:
		_mark_blocked_cells(node)
	_calculate_distances_from_target(target)
	_rebuild_reserved_cells()
	refresh_occupancy()
	_calculate_flow_vectors()
	_calculate_escape_directions_fast()
	_field_revision += 1
	_update_flow_visualization_cached()
	field_reviewed.emit()
	
	
func init_grid_from_bounds(flow_debug_root: Node3D ) -> void:
	_flow_debug_root = flow_debug_root
	var bounds_shape := _shape as BoxShape3D
	if bounds_shape == null:
		push_error("FlowField must use a BoxShape3D.")
		return
	# Il BoxShape3D assegnato al FlowField definisce sempre l'area della griglia.
	# Trasforma i suoi limiti nel mondo, senza modificarli in base agli ostacoli.
	var local_bounds := AABB(-bounds_shape.size * 0.5, bounds_shape.size)
	var world_bounds := _transform_aabb(local_bounds, global_transform)
	grid_origin = Vector2(world_bounds.position.x, world_bounds.position.z)
	grid_world_size = Vector2(world_bounds.size.x, world_bounds.size.z)
	grid_width = maxi(1, ceili(world_bounds.size.x / cell_size))
	grid_height = maxi(1, ceili(world_bounds.size.z / cell_size))
	_blocked.resize(grid_width * grid_height)
	var count := int(grid_width * grid_height)
	_occupied.resize(count)
	_reserved.resize(count)
	_spawn_mask.resize(count)
	_test_blocked.resize(count)
	_test_visited.resize(count)
	_initialize_flow_visualization()
	
func cell_to_world(cell: Vector2i) -> Vector2:
	return grid_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
	
# Converte una coppia di indici nell'indice dell'array lineare.
func _index(cell: Vector2i) -> int:
	return cell.y * grid_width + cell.x


# Rettangolo XZ che contiene tutti i poligoni dell'ingombro.
func _footprints_rect(footprints: Array[PackedVector2Array]) -> Rect2:
	var rect := Rect2(footprints[0][0], Vector2.ZERO)
	for polygon in footprints:
		for point in polygon:
			rect = rect.expand(point)
	return rect


# Celle (indici lineari) toccate dall'ingombro, con la stessa regola usata per gli ostacoli.
# Scorre solo le celle vicine al rettangolo dell'ingombro invece di tutta la griglia.
func _rasterize_footprints(footprints: Array[PackedVector2Array], clearance: float) -> PackedInt32Array:
	var cells := PackedInt32Array()
	if footprints.is_empty():
		return cells
	var rect := _footprints_rect(footprints)
	var margin := cell_size * 0.5 + clearance
	var min_cell := _clamp_cell(world_to_cell(Vector3(rect.position.x - margin, 0.0, rect.position.y - margin)))
	var max_cell := _clamp_cell(world_to_cell(Vector3(rect.end.x + margin, 0.0, rect.end.y + margin)))
	for z in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, z)
			if _cell_intersects_footprints(cell, footprints, clearance):
				cells.append(_index(cell))
	return cells


# Segna come riservate le celle del target e degli spawn e raccoglie le celle di spawn
# raggiungibili, che il test di connettività deve mantenere collegate.
func _rebuild_reserved_cells() -> void:
	_reserved.fill(0)
	_spawn_mask.fill(0)
	_spawn_indices.clear()
	for goal in _goal_indices:
		_reserved[goal] = 1
	for area in _spawn_areas:
		if not is_instance_valid(area):
			continue
		for cell in _get_area_cells(area):
			var index := _index(cell)
			_reserved[index] = 1
			if _blocked[index] or is_inf(_distances[index]) or _spawn_mask[index] == 1:
				continue
			_spawn_mask[index] = 1
			_spawn_indices.append(index)
	_placement_cache_key = 0


func _mark_blocked_cells(blocks: Node3D) -> void:
	var footprints := _get_node_footprints(blocks)
	if footprints.is_empty():
		push_warning("Flow field: impossibile ricavare le dimensioni del blocco '%s'." % blocks.name)
		return
	for index in _rasterize_footprints(footprints, placed_blocks_clearance):
		_blocked[index] = true


func _get_node_footprints(node: Node3D) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		# Le Area3D figlie descrivono effetti o raggi, non l'ingombro fisico piazzato.
		if current is Area3D:
			continue
		if current is CollisionShape3D:
			var collision := current as CollisionShape3D
			if collision.shape != null and not collision.disabled:
				var shape_mesh := collision.shape.get_debug_mesh()
				var points := PackedVector2Array()
				for surface in range(shape_mesh.get_surface_count()):
					var arrays := shape_mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for vertex in vertices:
						var world_vertex: Vector3 = collision.global_transform * vertex
						points.append(Vector2(world_vertex.x, world_vertex.z))
				if points.size() >= 3:
					result.append(Geometry2D.convex_hull(points))
		for child in current.get_children():
			pending.append(child)
	if not result.is_empty():
		return result
	# Le forme CSG sono scomposte nei triangoli della mesh generata.
	if node is CSGShape3D:
		var meshes := (node as CSGShape3D).get_meshes()
		if meshes.size() > 1 and meshes[1] is ArrayMesh:
			var mesh := meshes[1] as ArrayMesh
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				var triangle := PackedVector2Array()
				for j in range(3):
					var point: Vector3 = meshes[0] * vertices[indices[i + j]]
					triangle.append(Vector2(point.x, point.z))
				result.append(triangle)
	return result


func _cell_intersects_footprints(cell: Vector2i, footprints: Array[PackedVector2Array], clearance: float) -> bool:
	var center := cell_to_world(cell)
	var half := cell_size * 0.5 + clearance
	var square := [center + Vector2(-half, -half), center + Vector2(half, -half), center + Vector2(half, half), center + Vector2(-half, half)]
	for polygon in footprints:
		for point in polygon:
			if absf(point.x - center.x) <= half and absf(point.y - center.y) <= half:
				return true
		for point in square:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return true
		for i in range(polygon.size()):
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			for j in range(4):
				if Geometry2D.segment_intersects_segment(a, b, square[j], square[(j + 1) % 4]) != null:
					return true
	return false


func _get_node_world_aabb(node: Node3D) -> AABB:
	# Per i CSG usa il mesh effettivamente generato: l'AABB del nodo CSG può
	# essere vuoto prima che la geometria sia stata aggiornata.
	if node is CSGShape3D:
		var csg := node as CSGShape3D
		var generated_mesh := csg.get_meshes()
		if generated_mesh.size() > 1 and generated_mesh[1] is ArrayMesh:
			var csg_mesh := generated_mesh[1] as ArrayMesh
			if not csg_mesh.get_aabb().size.is_zero_approx():
				return _transform_aabb(csg_mesh.get_aabb(), generated_mesh[0])
		# Ultimo fallback CSG: bounds del nodo se disponibili.
		var csg_aabb := csg.get_aabb()
		if not csg_aabb.size.is_zero_approx():
			return _transform_aabb(csg_aabb, csg.global_transform)
	# I nodi di geometria non CSG espongono un AABB locale.
	if node is VisualInstance3D:
		var local_aabb: AABB = (node as VisualInstance3D).get_aabb()
		return _transform_aabb(local_aabb, (node as VisualInstance3D).global_transform)
	# Fallback generico per nodi senza geometria visibile: unisce le forme collisione
	# proprie e quelle dei discendenti nello spazio mondiale.
	var result := AABB()
	var found := false
	var collision_nodes: Array[Node] = [node]
	while not collision_nodes.is_empty():
		var current: Node = collision_nodes.pop_back()
		if current is CollisionShape3D:
			var collision := current as CollisionShape3D
			if collision.shape != null:
				var shape_aabb := collision.shape.get_debug_mesh().get_aabb()
				var world_shape_aabb := _transform_aabb(shape_aabb, collision.global_transform)
				result = world_shape_aabb if not found else result.merge(world_shape_aabb)
				found = true
		for child in current.get_children():
			collision_nodes.append(child)
	return result if found else AABB()


func _transform_aabb(local_aabb: AABB, transform: Transform3D) -> AABB:
	var first := transform * local_aabb.position
	var result := AABB(first, Vector3.ZERO)
	for x_sign in [0.0, 1.0]:
		for y_sign in [0.0, 1.0]:
			for z_sign in [0.0, 1.0]:
				var corner := local_aabb.position + Vector3(local_aabb.size.x * x_sign, local_aabb.size.y * y_sign, local_aabb.size.z * z_sign)
				result = result.expand(transform * corner)
	return result

# Celle il cui centro cade dentro le BoxShape3D del nodo (target o spawn).
# Se il nodo non ha box, usa la cella della sua posizione.
func _get_area_cells(area: Node3D) -> Array[Vector2i]:
	var shapes: Array[CollisionShape3D] = []
	var pending: Array[Node] = [area]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is CollisionShape3D:
			var collision := current as CollisionShape3D
			if collision.shape is BoxShape3D:
				shapes.append(collision)
		for child in current.get_children():
			pending.append(child)
	var cells: Array[Vector2i] = []
	if shapes.is_empty():
		cells.append(_clamp_cell(world_to_cell(area.global_position)))
		return cells
	for z in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, z)
			var center := cell_to_world(cell)
			for collision in shapes:
				var box := collision.shape as BoxShape3D
				var local := collision.global_transform.affine_inverse() * Vector3(center.x, collision.global_position.y, center.y)
				if absf(local.x) <= box.size.x * 0.5 and absf(local.z) <= box.size.z * 0.5:
					cells.append(cell)
					break
	return cells


func _get_target_cells(target: Node3D) -> Array[Vector2i]:
	var goals: Array[Vector2i] = []
	for cell in _get_area_cells(target):
		if not _blocked[_index(cell)]:
			goals.append(cell)
	return goals


# Calcola la distanza minima di ogni cella libera dal target con Dijkstra.

func _calculate_distances_from_target(target: Node3D) -> void:
	var count := grid_width * grid_height
	_distances.resize(count)
	_distances.fill(INF)
	_goal_indices.clear()
	var goals := _get_target_cells(target)
	if goals.is_empty():
		# Se l'area target è coperta, prova prima la cella più vicina al centro.
		var target_cell := _clamp_cell(world_to_cell(target.global_position))
		var best_cell := Vector2i(-1, -1)
		var best_distance := INF
		for z in range(grid_height):
			for x in range(grid_width):
				var candidate := Vector2i(x, z)
				if _blocked[_index(candidate)]:
					continue
				var distance := candidate.distance_squared_to(target_cell)
				if distance < best_distance:
					best_distance = distance
					best_cell = candidate
		if best_cell.x < 0:
			push_warning("Flow field: there are no free cells to reach the target.")
			return
		goals.append(best_cell)

	var visited := PackedByteArray()
	visited.resize(count)
	var frontier: Array[int] = []
	for goal in goals:
		var goal_index := _index(goal)
		_goal_indices.append(goal_index)
		_distances[goal_index] = 0.0
		frontier.append(goal_index)
	while not frontier.is_empty():
		var best_frontier_index := 0
		for i in range(1, frontier.size()):
			if _distances[frontier[i]] < _distances[frontier[best_frontier_index]]:
				best_frontier_index = i
		var current_index: int = frontier.pop_at(best_frontier_index)
		if visited[current_index] == 1:
			continue
		visited[current_index] = 1
		var current := _cell_from_index(current_index)
		for offset in NEIGHBORS:
			var next := current + offset
			if not _inside_grid(next) or _blocked[_index(next)]:
				continue
			if offset.x != 0 and offset.y != 0:
				if _blocked[_index(current + Vector2i(offset.x, 0))] or _blocked[_index(current + Vector2i(0, offset.y))]:
					continue
			var step_cost := 1.41421356 if offset.x != 0 and offset.y != 0 else 1.0
			var next_index := _index(next)
			var candidate_distance: float = _distances[current_index] + step_cost
			if candidate_distance < _distances[next_index]:
				_distances[next_index] = candidate_distance
				frontier.append(next_index)

# Converte una posizione del mondo in indici di cella X/Z.
func world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori((world_position.x - grid_origin.x) / cell_size),
		floori((world_position.z - grid_origin.y) / cell_size)
	)

# Limita una cella ai bordi validi della griglia.
func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, grid_width - 1), clampi(cell.y, 0, grid_height - 1))

# Indica se una cella è dentro i limiti della griglia.
func _inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

# Converte l'indice lineare dell'array nelle coordinate della cella.
func _cell_from_index(index: int) -> Vector2i:
	var width := int(grid_width)
	return Vector2i(index % width, floori(float(index) / float(width)))

# Per ogni cella sceglie il vicino con distanza minore e crea il vettore locale.
func _calculate_flow_vectors() -> void:
	_flow.resize(grid_width * grid_height)
	_flow.fill(Vector2.ZERO)
	for z in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, z)
			var index := _index(cell)
			if _blocked[index] or is_inf(_distances[index]) or _distances[index] == 0.0:
				continue
			var best_neighbor := cell
			var best_distance: float = _distances[index]
			for offset in NEIGHBORS:
				var neighbor := cell + offset
				if not _inside_grid(neighbor) or _blocked[_index(neighbor)]:
					continue
				# Mantiene la stessa regola del calcolo distanze: niente diagonali
				# che tagliano l'angolo tra due celle bloccate.
				if offset.x != 0 and offset.y != 0:
					if _blocked[_index(cell + Vector2i(offset.x, 0))] or _blocked[_index(cell + Vector2i(0, offset.y))]:
						continue
				var neighbor_distance: float = _distances[_index(neighbor)]
				if neighbor_distance < best_distance:
					best_distance = neighbor_distance
					best_neighbor = neighbor
			if best_neighbor != cell:
				_flow[index] = Vector2(best_neighbor.x - x, best_neighbor.y - z).normalized()

# Ricrea le frecce di debug, colorate secondo distanza e celle bloccate.
# Propaga le direzioni di fuga dai passaggi liberi alle celle bloccate in O(N).
func _calculate_escape_directions_fast() -> void:
	_escape_directions.resize(grid_width * grid_height)
	_escape_directions.fill(Vector2.ZERO)
	var discovered := PackedByteArray()
	discovered.resize(grid_width * grid_height)
	var queue: Array[Vector2i] = []
	# Ogni cella libera e raggiungibile è un punto da cui si può uscire.
	for z in range(grid_height):
		for x in range(grid_width):
			var open_cell := Vector2i(x, z)
			var open_index := _index(open_cell)
			if _blocked[open_index] or is_inf(_distances[open_index]):
				continue
			for i in range(4):
				var blocked_cell := open_cell + NEIGHBORS[i]
				if not _inside_grid(blocked_cell):
					continue
				var blocked_index := _index(blocked_cell)
				if _blocked[blocked_index] and discovered[blocked_index] == 0:
					discovered[blocked_index] = 1
					_escape_directions[blocked_index] = Vector2(open_cell - blocked_cell)
					queue.append(blocked_cell)
	# Diffonde poi la prima direzione utile attraverso le regioni bloccate.
	var queue_index := 0
	while queue_index < queue.size():
		var current := queue[queue_index]
		queue_index += 1
		for i in range(4):
			var next := current + NEIGHBORS[i]
			if not _inside_grid(next):
				continue
			var next_index := _index(next)
			if _blocked[next_index] and discovered[next_index] == 0:
				discovered[next_index] = 1
				_escape_directions[next_index] = Vector2(current - next)
				queue.append(next)
	for i in range(_escape_directions.size()):
		if _escape_directions[i] != Vector2.ZERO:
			_escape_directions[i] = _escape_directions[i].normalized()

# Restituisce la direzione interpolata da seguire nella posizione del nemico.
func get_flow_direction(world_position: Vector3) -> Vector3:
	var cell := _clamp_cell(world_to_cell(world_position))
	var index := _index(cell)
	if _blocked[index]:
		var escape: Vector2 = _escape_directions[index]
		return Vector3(escape.x, 0.0, escape.y)
	# Interpola le direzioni delle quattro celle più vicine per ridurre gli scatti.
	var grid_position := Vector2(
		(world_position.x - grid_origin.x) / cell_size - 0.5,
		(world_position.z - grid_origin.y) / cell_size - 0.5
	)
	var base := Vector2i(floori(grid_position.x), floori(grid_position.y))
	var fraction := Vector2(grid_position.x - base.x, grid_position.y - base.y)
	var direction := Vector2.ZERO
	for dz in range(2):
		for dx in range(2):
			var sample_cell := base + Vector2i(dx, dz)
			if not _inside_grid(sample_cell):
				continue
			var sample_index := _index(sample_cell)
			if _blocked[sample_index]:
				continue
			var weight_x := fraction.x if dx == 1 else 1.0 - fraction.x
			var weight_z := fraction.y if dz == 1 else 1.0 - fraction.y
			direction += _flow[sample_index] * weight_x * weight_z
	if direction == Vector2.ZERO:
		return Vector3.ZERO
	direction = direction.normalized()
	return Vector3(direction.x, 0.0, direction.y)


# Aggiorna le frecce esistenti senza liberarle e ricrearle dopo ogni piazzamento.
func _update_flow_visualization_cached() -> void:
	_flow_debug_root.visible = show_flow_field
	if not show_flow_field:
		return
	var max_distance := 1.0
	for distance in _distances:
		if not is_inf(distance):
			max_distance = maxf(max_distance, distance)
	for z in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, z)
			var index := _index(cell)
			var arrow := _flow_arrows[index]
			# Le celle bloccate hanno distanza INF per definizione, ma devono
			# restare visibili nella preview per mostrare dove il passaggio è chiuso.
			arrow.visible = _blocked[index] or not is_inf(_distances[index])
			if not arrow.visible:
				continue
			var cell_position := cell_to_world(cell)
			arrow.position = Vector3(cell_position.x, flow_arrow_height, cell_position.y)
			var direction: Vector2 = _flow[index]
			if direction != Vector2.ZERO:
				arrow.rotation.y = -atan2(direction.y, direction.x) + PI * 0.5
			var color: Color
			if _blocked[index]:
				color = Color(1.0, 0.12, 0.04, 1.0)
			else:
				var normalized_distance := _distances[index] / max_distance
				color = Color(0.15, 0.95 - normalized_distance * 0.55, 1.0 - normalized_distance * 0.75, 1.0)
			_set_arrow_color(arrow, color)

# Applica alla freccia un materiale non influenzato dall'illuminazione.
func _set_arrow_color(arrow: Node3D, color: Color) -> void:
	for mesh_instance in arrow.get_children():
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh_instance.material_override = material
		material.albedo_color = color

# Crea una sola volta le frecce di debug, una per cella della griglia.
func _initialize_flow_visualization() -> void:
	_flow_arrows.resize(grid_width * grid_height)
	for i in range(_flow_arrows.size()):
		var arrow := _make_flow_arrow()
		_flow_debug_root.add_child(arrow)
		_flow_arrows[i] = arrow

# Crea la freccia di una cella usando un'asta e una punta.
func _make_flow_arrow() -> Node3D:
	var arrow := Node3D.new()
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.08, 0.025, cell_size * 0.42)
	shaft.mesh = shaft_mesh
	shaft.position.z = -cell_size * 0.13
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(0.28, 0.035, 0.28)
	head.mesh = head_mesh
	head.position.z = -cell_size * 0.35
	arrow.add_child(shaft)
	arrow.add_child(head)
	return arrow



# ----------------------------------------
# PIAZZAMENTO
# ----------------------------------------

# Registra le aree di spawn che devono restare collegate al target.
# Va chiamata prima di rebuild_flow_field().
func set_spawn_areas(areas: Array) -> void:
	_spawn_areas.clear()
	for area in areas:
		if area is Node3D:
			_spawn_areas.append(area)


# Ricalcola le celle occupate dagli elementi piazzati (gruppo "placeables").
# Basta questa, senza rebuild del flow field, dopo aver piazzato un'unità non bloccante.
func refresh_occupancy() -> void:
	_occupied.fill(0)
	for placed in get_tree().get_nodes_in_group("placeables"):
		if not is_instance_valid(placed) or not placed is Node3D:
			continue
		for index in _rasterize_footprints(_get_node_footprints(placed as Node3D), 0.0):
			_occupied[index] = 1
	_placement_cache_key = 0


# Valida l'anteprima. Regole:
# 1. l'ingombro deve stare tutto dentro il flow field;
# 2. le celle toccate devono essere libere, raggiungibili, non occupate e non di spawn/target;
# 3. se l'elemento è bloccante, dopo il piazzamento ogni cella di spawn deve ancora
#    raggiungere il target (simulato con la stessa rasterizzazione del rebuild).
func can_place_placeable(placement_node: Node3D, blocking: bool) -> bool:
	if _distances.is_empty() or _occupied.is_empty():
		return false
	var footprints := _get_node_footprints(placement_node)
	if footprints.is_empty():
		return false

	var rect := _footprints_rect(footprints)
	if rect.position.x < grid_origin.x or rect.position.y < grid_origin.y \
	or rect.end.x > grid_origin.x + grid_world_size.x \
	or rect.end.y > grid_origin.y + grid_world_size.y:
		return false

	var body_cells := _rasterize_footprints(footprints, 0.0)
	if body_cells.is_empty():
		return false
	for index in body_cells:
		if _blocked[index] or is_inf(_distances[index]) or _reserved[index] == 1 or _occupied[index] == 1:
			return false

	if not blocking:
		return true

	var block_cells := _rasterize_footprints(footprints, placed_blocks_clearance)
	var key := hash([block_cells, _field_revision])
	if key == _placement_cache_key:
		return _placement_cache_result
	_placement_cache_result = _keeps_spawns_connected(block_cells)
	_placement_cache_key = key
	return _placement_cache_result


# BFS dal target con le celle del nuovo blocco considerate chiuse.
# Usa gli stessi vicini e la stessa regola sulle diagonali del calcolo distanze.
func _keeps_spawns_connected(block_cells: PackedInt32Array) -> bool:
	if _spawn_indices.is_empty():
		return true
	_test_blocked.fill(0)
	for index in block_cells:
		_test_blocked[index] = 1
	# Un blocco che copre una cella di spawn la renderebbe irraggiungibile.
	for index in _spawn_indices:
		if _test_blocked[index] == 1:
			return false

	_test_visited.fill(0)
	_test_queue.clear()
	for goal in _goal_indices:
		if not _is_test_blocked(goal):
			_test_visited[goal] = 1
			_test_queue.append(goal)

	var remaining := _spawn_indices.size()
	var head := 0
	while head < _test_queue.size():
		var current_index := _test_queue[head]
		head += 1
		if _spawn_mask[current_index] == 1:
			remaining -= 1
			if remaining == 0:
				return true
		var current := _cell_from_index(current_index)
		for offset in NEIGHBORS:
			var next := current + offset
			if not _inside_grid(next):
				continue
			var next_index := _index(next)
			if _test_visited[next_index] == 1 or _is_test_blocked(next_index):
				continue
			if offset.x != 0 and offset.y != 0:
				if _is_test_blocked(_index(current + Vector2i(offset.x, 0))) \
				or _is_test_blocked(_index(current + Vector2i(0, offset.y))):
					continue
			_test_visited[next_index] = 1
			_test_queue.append(next_index)
	return false


func _is_test_blocked(index: int) -> bool:
	return _blocked[index] or _test_blocked[index] == 1
