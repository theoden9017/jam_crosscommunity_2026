extends Control

signal closed

@export var starting_money: float = 5_000_000.0
@onready var window = $Window
@onready var money_label = $Window/MarginContainer/VBoxContainer/MoneyLabel
@onready var chart = $Window/MarginContainer/VBoxContainer/MarketChart

var current_money: float = 5_000_000.0

var chart_values: Array[float] = []

var max_points: int = 60


func _ready() -> void:

	current_money = starting_money

	# Posizione finestra
	window.position = Vector2(20, 20)
	window.size = Vector2(320, 190)

	# Grafico iniziale
	for i in range(20):
		chart_values.append(100.0)
	chart.update_chart(chart_values)
	_update_money()

func _on_close_button_pressed() -> void:
	closed.emit()
	#window.hide()

func update_money(new_money: float) -> void:

	var old_money = current_money

	current_money = new_money

	# Cambia colore in base all'andamento
	if current_money < old_money:

		money_label.add_theme_color_override(
			"font_color",
			Color("#FF5555")
		)

	elif current_money > old_money:

		money_label.add_theme_color_override(
			"font_color",
			Color("#55DD88")
		)

	_update_money()

	# Aggiorna grafico
	var percentage = (
		current_money / starting_money
	) * 100.0

	chart_values.append(percentage)

	if chart_values.size() > max_points:
		chart_values.pop_front()

	chart.update_chart(chart_values)


func _update_money() -> void:

	money_label.text = "€ " + _format_money(current_money)


func _format_money(value: float) -> String:

	var number = int(round(value))
	var raw = str(number)
	var result = ""
	var counter = 0

	for i in range(raw.length() - 1, -1, -1):

		result = raw[i] + result
		counter += 1

		if counter % 3 == 0 and i > 0:
			result = "." + result

	return result


func add_losses(amount: float) -> void:

	update_money(
		maxf(current_money - amount, 0.0)
	)


func add_revenue(amount: float) -> void:

	update_money(
		current_money + amount
	)
