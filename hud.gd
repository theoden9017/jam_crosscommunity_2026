extends Control

signal strillone_selected
signal volantinatore_selected
signal stricioni_selected
signal gazebo_selected

@onready var days_of_strike: Label = $TopPanel/HBoxContainer/daysOfStrike
@onready var worrkers_involved: Label = $TopPanel/HBoxContainer/worrkersInvolved
@onready var market_widget: PanelContainer = $MarketWidget


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	updateHUD()

func updateHUD():
	days_of_strike.text = str(GameController.StrikeDays)
	worrkers_involved.text = str(GameController.CurrentWorkers)




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
