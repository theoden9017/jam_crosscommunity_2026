extends RefCounted

const DIRECTORY := "user://saves"

static func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var dir := DirAccess.open(DIRECTORY)
	if dir == null:
		return slots
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and file.begins_with("slot_") and file.ends_with(".json"):
			var data := load_slot(file.trim_prefix("slot_").trim_suffix(".json"))
			if not data.is_empty():
				slots.append(data)
		file = dir.get_next()
	dir.list_dir_end()
	slots.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("updated_at", 0)) > int(b.get("updated_at", 0)))
	return slots

static func has_any_slot() -> bool:
	return not list_slots().is_empty()

static func save_slot(slot_id: String, payload: Dictionary, label := "") -> Error:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var data := {
		"slot_id": slot_id,
		"label": label if not label.is_empty() else slot_id,
		"updated_at": Time.get_unix_time_from_system(),
		"payload": payload,
	}
	var file := FileAccess.open("%s/slot_%s.json" % [DIRECTORY, slot_id.validate_filename()], FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	return OK

static func load_slot(slot_id: String) -> Dictionary:
	var file := FileAccess.open("%s/slot_%s.json" % [DIRECTORY, slot_id.validate_filename()], FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	return json.data

static func delete_slot(slot_id: String) -> Error:
	return DirAccess.remove_absolute("%s/slot_%s.json" % [DIRECTORY, slot_id.validate_filename()])
