extends Node

const map1 := "res://Levels/stage01.tscn"
const map2 := "res://Levels/stage01.tscn"
const map3 := "res://Levels/stage01.tscn"
const map4 := "res://Levels/stage01.tscn"
const PATH_SETTINGS := "user://ccjam_settings.cfg"
const PATH_GAME := "user://ccjam_game.cfg"

var actual_level = 1
var StrikeDays = 1
var CurrentWorkers = 0

# Casse sindacali: si riempiono con le quote dei lavoratori convinti
# e si svuotano costruendo strutture.
signal union_funds_changed(new_amount: int)
const STARTING_UNION_FUNDS := 100
var UnionFunds: int = STARTING_UNION_FUNDS

var _settings: Dictionary
var _awaiting_action := StringName()
var _defaults := {
	"master_volume": 1.0, "music_volume": 1.0, "effects_volume": 1.0
}

var _inGame: Dictionary
var _defaults_inGame := {
	"actual_level": 1, "strike_days": 1
}


# Da chiamare all'inizio di ogni livello.
func reset_union_funds() -> void:
	UnionFunds = STARTING_UNION_FUNDS
	union_funds_changed.emit(UnionFunds)

func add_union_funds(amount: int) -> void:
	if amount <= 0:
		return
	UnionFunds += amount
	union_funds_changed.emit(UnionFunds)

func can_afford(cost: int) -> bool:
	return UnionFunds >= cost

# Restituisce false (e non scala nulla) se i fondi non bastano.
func spend_union_funds(cost: int) -> bool:
	if not can_afford(cost):
		return false
	UnionFunds -= cost
	union_funds_changed.emit(UnionFunds)
	return true


static func load_settings(defaults: Dictionary) -> Dictionary:
	var values := defaults.duplicate(true)
	var config := ConfigFile.new()
	if config.load(PATH_SETTINGS) != OK:
		return values
	for key in defaults:
		values[key] = config.get_value("settings", key, defaults[key])
	return values

static func load_inGame(defaults: Dictionary) -> Dictionary:
	var values := defaults.duplicate(true)
	var config := ConfigFile.new()
	if config.load(PATH_GAME) != OK:
		return values
	for key in defaults:
		values[key] = config.get_value("game", key, defaults[key])
	return values

static func save_settings(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings", key, values[key])
	config.save(PATH_SETTINGS)
	
static func save_inGame(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("game", key, values[key])
	config.save(PATH_GAME)

func _apply_settings() -> void:
	if _settings.is_empty():
		return
		
	_update_volume("Master", _settings["master_volume"])
	_update_volume("Music", _settings["music_volume"])
	_update_volume("Effect", _settings["effects_volume"])

func _update_volume(bus_name: String,  linear_value: float):
	var bus := AudioServer.get_bus_index(bus_name) 
	if bus <0:
		return
	else:
		AudioServer.set_bus_mute(bus, linear_value <= 0.0)
		if linear_value > 0.0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(linear_value))
