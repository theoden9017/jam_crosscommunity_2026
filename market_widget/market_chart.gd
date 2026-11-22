
extends Control

var values: Array[float] = []

@export var line_color := Color("#FF5555")

func _draw() -> void:

	var chart_size = size

	# Griglia
	for i in range(1, 4):
		var y = chart_size.y * i / 4.0

		draw_line(
			Vector2(0, y),
			Vector2(chart_size.x, y),
			Color("#344653"),
			1.0
		)

	if values.size() < 2:
		return

	var points := PackedVector2Array()

	var min_value = 0.0
	var max_value = 100.0

	for value in values:
		min_value = minf(min_value, value)
		max_value = maxf(max_value, value)

	var value_range = maxf(max_value - min_value, 1.0)

	for i in range(values.size()):

		var x = float(i) / (values.size() - 1) * chart_size.x

		var normalized = (
			values[i] - min_value
		) / value_range

		var y = chart_size.y * (1.0 - normalized)

		points.append(Vector2(x, y))

	# Area sotto il grafico
	var polygon := PackedVector2Array()

	polygon.append(Vector2(0, chart_size.y))

	for point in points:
		polygon.append(point)

	polygon.append(Vector2(chart_size.x, chart_size.y))

	draw_colored_polygon(
		polygon,
		Color(line_color, 0.12)
	)

	# Linea
	draw_polyline(
		points,
		line_color,
		2.0,
		true
	)

	# Punto finale
	draw_circle(
		points[-1],
		3.5,
		line_color
	)


func update_chart(new_values: Array[float]) -> void:

	values = new_values
	queue_redraw()
