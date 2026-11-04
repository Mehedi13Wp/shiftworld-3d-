extends Node3D
# A real, repeatable driving objective placed on OSM road geometry.
# Lightweight, offline and independent of character/walking work.
signal checkpoint_reached(reward: int)
signal run_completed(reward: int)

const CHECKPOINT_OFFSETS := [55.0, 110.0, 175.0]
var checkpoints: Array[Vector3] = []
var gates: Array[Node3D] = []
var active_index := 0
var elapsed := 0.0
var running := false

func setup(map_data: Dictionary, spawn: Vector3, heading: float, road_name: String) -> bool:
	for child in get_children():
		child.queue_free()
	checkpoints.clear()
	gates.clear()
	active_index = 0
	elapsed = 0.0
	running = false
	var start := Vector2(spawn.x, spawn.z)
	var forward := Vector2(-sin(heading), -cos(heading))
	for desired in CHECKPOINT_OFFSETS:
		var target := _road_checkpoint(map_data, start, forward, float(desired), road_name)
		if target.distance_to(start) < 15.0:
			return false
		checkpoints.append(Vector3(target.x, 0.10, target.y))
	if checkpoints.size() != CHECKPOINT_OFFSETS.size():
		return false
	for i in range(checkpoints.size()):
		var gate := _make_gate(checkpoints[i], heading)
		gate.name = "Checkpoint" + str(i + 1)
		gate.visible = i == 0
		add_child(gate)
		gates.append(gate)
	running = true
	return true

func _road_checkpoint(data: Dictionary, origin: Vector2, forward: Vector2, desired: float, preferred_road: String) -> Vector2:
	var goal := origin + forward * desired
	var best := goal
	var best_score := INF
	for pass_index in range(2):
		for road in data.get("roads", []):
			if pass_index == 0 and str(road.get("name", "")) != preferred_road:
				continue
			var pts: Array = road.get("points", [])
			for i in range(pts.size() - 1):
				var a := Vector2(float(pts[i][0]), float(pts[i][1]))
				var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
				var p := Geometry2D.get_closest_point_to_segment(goal, a, b)
				var progress := (p - origin).dot(forward)
				if progress < desired - 19.0 or progress > desired + 19.0:
					continue
				var score := goal.distance_to(p) + absf(progress - desired) * 0.7
				if score < best_score:
					best_score = score
					best = p
		if best_score < 12.0:
			break
	return best

func _neon_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _gate_box(parent: Node3D, local_position: Vector3, dimensions: Vector3, mat: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = mat
	parent.add_child(instance)

func _make_gate(at: Vector3, heading: float) -> Node3D:
	var gate := Node3D.new()
	gate.position = at
	gate.rotation.y = heading
	var neon := _neon_material(Color(0.12, 0.98, 0.91))
	var dark := _neon_material(Color(0.035, 0.15, 0.18))
	for side in [-1.0, 1.0]:
		_gate_box(gate, Vector3(side * 3.35, 2.25, 0), Vector3(0.22, 4.5, 0.22), neon)
		_gate_box(gate, Vector3(side * 3.35, 0.16, 0), Vector3(0.70, 0.18, 0.70), dark)
	_gate_box(gate, Vector3(0, 4.53, 0), Vector3(6.9, 0.22, 0.22), neon)
	var spot := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.6
	disc.bottom_radius = 2.6
	disc.height = 0.025
	spot.mesh = disc
	spot.position.y = 0.012
	var glow := _neon_material(Color(0.08, 0.64, 0.55, 0.36))
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spot.material_override = glow
	gate.add_child(spot)
	return gate

func _process(delta: float) -> void:
	if not running or active_index >= gates.size():
		return
	elapsed += delta
	var pulse := 1.0 + 0.04 * sin(elapsed * 4.0)
	gates[active_index].scale = Vector3.ONE * pulse

func update_car_position(pos: Vector3, velocity: float) -> void:
	if not running or active_index >= checkpoints.size():
		return
	var target := checkpoints[active_index]
	var distance_2d := Vector2(pos.x, pos.z).distance_to(Vector2(target.x, target.z))
	if distance_2d > 6.5 or velocity < 0.75:
		return
	gates[active_index].visible = false
	active_index += 1
	checkpoint_reached.emit(75)
	if active_index >= checkpoints.size():
		running = false
		run_completed.emit(250)
	else:
		gates[active_index].visible = true

func guidance(pos: Vector3, heading: float) -> String:
	if checkpoints.is_empty():
		return "FREE DRIVE"
	if not running:
		return "RUN COMPLETE!  |  RESTART TO PLAY AGAIN"
	var target := checkpoints[active_index]
	var delta := Vector2(target.x - pos.x, target.z - pos.z)
	var meters := int(delta.length())
	var right := Vector2(cos(heading), -sin(heading))
	var forward := Vector2(-sin(heading), -cos(heading))
	var lateral := delta.normalized().dot(right)
	var frontal := delta.normalized().dot(forward)
	var bearing := "STRAIGHT"
	if frontal < -0.2:
		bearing = "TURN AROUND"
	elif lateral > 0.35:
		bearing = "RIGHT"
	elif lateral < -0.35:
		bearing = "LEFT"
	return "CHECKPOINT %d/%d  |  %dm  |  %s" % [active_index + 1, checkpoints.size(), meters, bearing]
