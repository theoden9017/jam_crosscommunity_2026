extends Control

signal strillone_selected
signal volantinatore_selected
signal stricioni_selected
signal gazebo_selected

@onready var days_of_strike: Label = $TopPanel/HBoxContainer/daysOfStrike
@onready var worrkers_involved: Label = $TopPanel/HBoxContainer/worrkersInvolved
@onready var union_funds: Label = $TopPanel/HBoxContainer/unionFunds
@onready var wave_info: Label = $TopPanel/HBoxContainer/waveInfo
@onready var market_widget: PanelContainer = $MarketWidget

# Pulsante dell'HUD per ogni elemento piazzabile (chiavi = nomi in BlockPlacing.OBJECTS).
@onready var _build_buttons := {
	"STRILLONE": $BottomPanel2/HBoxContainer/Strillone,
	"VOLANTINATORE": $BottomPanel2/HBoxContainer/Volantinatore,
	"GAZEBO": $BottomPanel2/HBoxContainer/Gazebo,
	"STRISCIONE": $BottomPanel2/HBoxContainer/Striscioni,
}

var _block_placing: Node
var _match_controller: Node
var _wave_number := 0
var _total_waves := -1


func _ready() -> void:
	GameController.union_funds_changed.connect(_on_union_funds_changed)
	_on_union_funds_changed(GameController.UnionFunds)


## Collega l'HUD al sistema di piazzamento per mostrare costi e disponibilità.
func bind_block_placing(block_placing: Node) -> void:
	_block_placing = block_placing
	_block_placing.inventory_changed.connect(refresh_build_buttons)
	refresh_build_buttons()


## Collega l'HUD al MatchController per mostrare l'ondata corrente.
func bind_match_controller(match_controller: Node) -> void:
	_match_controller = match_controller
	_total_waves = match_controller.get_total_waves()
	match_controller.wave_started.connect(_on_wave_started)
	match_controller.all_waves_spawned.connect(_on_all_waves_spawned)


func _process(delta: float) -> void:
	updateHUD()


func updateHUD():
	days_of_strike.text = str(GameController.StrikeDays)
	worrkers_involved.text = str(GameController.CurrentWorkers)
	_update_wave_info()


func _on_union_funds_changed(amount: int) -> void:
	union_funds.text = str(amount)
	refresh_build_buttons()


# Disattiva i pulsanti se mancano fondi o unità e mostra costo e disponibilità.
func refresh_build_buttons() -> void:
	if _block_placing == null:
		return
	for obj in _build_buttons:
		var button: Button = _build_buttons[obj]
		var cost: int = _block_placing.get_cost(obj)
		var remaining: int = _block_placing.get_remaining(obj)
		button.text = "%s\n%d quote · %d/%d" % [
			_block_placing.OBJECTS[obj]["label"], cost, remaining, _block_placing.get_max_count(obj)
		]
		button.disabled = not _block_placing.can_start_placement(obj)
		if remaining <= 0:
			button.tooltip_text = "Limite raggiunto"
		elif not GameController.can_afford(cost):
			button.tooltip_text = "Fondi insufficienti"
		else:
			button.tooltip_text = ""


func _on_wave_started(wave_number: int, total_waves: int) -> void:
	_wave_number = wave_number
	_total_waves = total_waves


func _on_all_waves_spawned() -> void:
	_wave_number = -1


func _update_wave_info() -> void:
	if _match_controller == null:
		wave_info.text = ""
		return
	if _wave_number < 0:
		wave_info.text = "Ultima ondata in campo"
		return
	var label := "Ondata %d" % maxi(_wave_number, 0)
	if _total_waves > 0:
		label += "/%d" % _total_waves
	var countdown: float = _match_controller.get_time_to_next_wave()
	if countdown > 0.0:
		label = "Prossima ondata tra %ds" % ceili(countdown)
	wave_info.text = label




#------ Buttons -----------
func _on_volantinatore_pressed() -> void:
	volantinatore_selected.emit()

func _on_striscioni_pressed() -> void:
	stricioni_selected.emit()

func _on_strillone_pressed() -> void:
	strillone_selected.emit()

func _on_index_button_pressed() -> void:
	market_widget.visible= true

func _on_market_widget_closed() -> void:
	market_widget.visible= false


func _on_gazebo_pressed() -> void:
	gazebo_selected.emit()
