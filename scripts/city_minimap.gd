extends Control
# Lightweight offline OpenStreetMap driving minimap (north-up).
var road_lines: Array[PackedVector2Array] = []
var car_map_position := Vector2.ZERO
var car_heading := 0.0
var checkpoint_position := Vector2.ZERO
var has_checkpoint := false
var meters_to_pixels := 0.85

func configure(data: Dictionary) -> void:
	road_lines.clear()
	for road in data.get("roads", []):
		var points := PackedVector2Array()
		for p in road.get("points", []):
			points.append(Vector2(float(p[0]), float(p[1])))
		if points.size() >= 2:
			road_lines.append(points)
	queue_redraw()

func follow(car_position: Vector3, heading: float, target: Vector3, target_visible: bool) -> void:
	car_map_position = Vector2(car_position.x, car_position.z)
	car_heading = heading
	checkpoint_position = Vector2(target.x, target.z)
	has_checkpoint = target_visible
	queue_redraw()

func _map_point(world: Vector2) -> Vector2:
	return size * 0.5 + (world - car_map_position) * meters_to_pixels

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.075, 0.11, 0.92), true)
	var extended := Rect2(-Vector2.ONE * 25.0, size + Vector2.ONE * 50.0)
	for polyline in road_lines:
		for i in range(polyline.size() - 1):
			var a := _map_point(polyline[i])
			var b := _map_point(polyline[i + 1])
			# Screen-space bounds check avoids drawing the full OSM network.
			var low := Vector2(minf(a.x, b.x), minf(a.y, b.y))
			var high := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
			if not extended.intersects(Rect2(low, (high - low).max(Vector2.ONE))):
				continue
			draw_line(a, b, Color(0.42, 0.55, 0.59, 0.95), 3.0, true)
	if has_checkpoint:
		var mark := _map_point(checkpoint_position)
		if extended.has_point(mark):
			draw_circle(mark, 8.5, Color(0.14, 0.98, 0.72))
			draw_arc(mark, 12.0, 0.0, TAU, 24, Color(0.86, 1.0, 0.94), 2.0)
	var center := size * 0.5
	var forward := Vector2(-sin(car_heading), -cos(car_heading))
	var right := Vector2(-forward.y, forward.x)
	var triangle := PackedVector2Array([
		center + forward * 12.0,
		center - forward * 8.0 - right * 7.0,
		center - forward * 8.0 + right * 7.0
	])
	draw_colored_polygon(triangle, Color(1.0, 0.78, 0.15))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.90, 0.87), false, 2.0)
