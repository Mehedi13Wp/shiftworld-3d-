extends Node3D

var car: Node3D
var camera: Camera3D
var speed := 16.0
var steering := 0.0
var distance := 0.0
var crashed := false
var obstacles: Array[Node3D] = []
var score_label: Label
var status_label: Label
var wheels: Array[Node3D] = []
var lane_marks: Array[Node3D] = []
var roadside: Array[Node3D] = []

func _ready() -> void:
	_create_environment()
	_create_car()
	_create_ui()
	_spawn_obstacles()

func _make_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.72, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

	_make_box(self, Vector3(0, -0.52, -110), Vector3(100, 0.15, 320), Color(0.20, 0.31, 0.21))
	_make_box(self, Vector3(0, -0.35, -110), Vector3(13, 0.5, 320), Color(0.095, 0.11, 0.14))
	for side in [-1.0, 1.0]:
		_make_box(self, Vector3(side * 6.45, -0.05, -110), Vector3(0.16, 0.04, 320), Color(0.95, 0.93, 0.83))
		_make_box(self, Vector3(side * 7.0, 0.05, -110), Vector3(0.25, 0.5, 320), Color(0.43, 0.48, 0.49))
	for i in range(45):
		var marker := Node3D.new()
		add_child(marker)
		marker.position.z = -float(i) * 7.0
		for x in [-2.15, 2.15]:
			_make_box(marker, Vector3(x, -0.07, 0), Vector3(0.12, 0.035, 3.3), Color(0.94, 0.94, 0.86))
		lane_marks.append(marker)
	for i in range(36):
		var segment := Node3D.new()
		add_child(segment)
		segment.position.z = -float(i) * 9.0
		for side in [-1.0, 1.0]:
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.16
			trunk_mesh.bottom_radius = 0.22
			trunk_mesh.height = 2.2
			trunk.mesh = trunk_mesh
			trunk.position = Vector3(side * 11.0, 0.75, 0)
			var bark := StandardMaterial3D.new()
			bark.albedo_color = Color(0.29, 0.19, 0.12)
			trunk.material_override = bark
			segment.add_child(trunk)
			var leaves := MeshInstance3D.new()
			var foliage := SphereMesh.new()
			foliage.radius = 1.5
			foliage.height = 3.0
			leaves.mesh = foliage
			leaves.position = Vector3(side * 11.0, 2.6, 0)
			var green := StandardMaterial3D.new()
			green.albedo_color = Color(0.10 + float(i % 3) * 0.035, 0.34, 0.15)
			leaves.material_override = green
			segment.add_child(leaves)
		roadside.append(segment)

func _create_car() -> void:
	car = Node3D.new()
	add_child(car)
	car.position = Vector3(0, 0.65, 4)

	_make_box(car, Vector3(0, -0.04, 0), Vector3(1.72, 0.42, 3.55), Color(0.025, 0.27, 0.88))
	_make_box(car, Vector3(0, 0.24, -0.65), Vector3(1.52, 0.26, 1.4), Color(0.03, 0.33, 0.95))
	_make_box(car, Vector3(0, 0.49, -0.15), Vector3(1.30, 0.48, 1.65), Color(0.065, 0.11, 0.18))
	_make_box(car, Vector3(0, 0.73, -0.18), Vector3(1.18, 0.08, 1.3), Color(0.03, 0.30, 0.86))
	_make_box(car, Vector3(0, 0.11, 1.55), Vector3(1.58, 0.16, 0.28), Color(0.02, 0.14, 0.4))
	for x in [-0.57, 0.57]:
		_make_box(car, Vector3(x, 0.10, -1.76), Vector3(0.35, 0.15, 0.09), Color(1.0, 0.94, 0.70))
		_make_box(car, Vector3(x, 0.10, 1.79), Vector3(0.35, 0.13, 0.08), Color(0.96, 0.08, 0.07))
	for x in [-0.91, 0.91]:
		for z in [-1.12, 1.12]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, -0.26, z)
			car.add_child(pivot)
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.39
			cylinder.bottom_radius = 0.39
			cylinder.height = 0.27
			tire.mesh = cylinder
			tire.rotation_degrees.z = 90
			var rubber := StandardMaterial3D.new()
			rubber.albedo_color = Color(0.035, 0.04, 0.05)
			tire.material_override = rubber
			pivot.add_child(tire)
			wheels.append(pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0, 4.8, 11.5)
	camera.rotation_degrees.x = -16
	camera.current = true
	add_child(camera)

func _spawn_obstacles() -> void:
	for i in range(18):
		var obstacle := Node3D.new()
		add_child(obstacle)
		obstacle.position = Vector3(float(randi_range(-2, 2)) * 2.0, 0.65, -15.0 - float(i) * 13.0)
		_make_box(obstacle, Vector3.ZERO, Vector3(1.7, 1.3, 1.5), Color(1.0, 0.45, 0.05))
		obstacles.append(obstacle)

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)

	score_label = Label.new()
	score_label.position = Vector2(25, 35)
	score_label.add_theme_font_size_override("font_size", 34)
	ui.add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(100, 250)
	status_label.add_theme_font_size_override("font_size", 42)
	ui.add_child(status_label)

	var left := Button.new()
	left.text = "LEFT"
	left.position = Vector2(35, 1080)
	left.size = Vector2(230, 115)
	ui.add_child(left)
	left.button_down.connect(func(): steering = -1.0)
	left.button_up.connect(func(): steering = 0.0)

	var right := Button.new()
	right.text = "RIGHT"
	right.position = Vector2(455, 1080)
	right.size = Vector2(230, 115)
	ui.add_child(right)
	right.button_down.connect(func(): steering = 1.0)
	right.button_up.connect(func(): steering = 0.0)

	var restart := Button.new()
	restart.text = "RESTART"
	restart.position = Vector2(260, 1160)
	restart.size = Vector2(200, 75)
	ui.add_child(restart)
	restart.pressed.connect(func(): get_tree().reload_current_scene())

func _process(delta: float) -> void:
	if crashed:
		return

	distance += speed * delta
	for wheel in wheels:
		wheel.rotate_x(speed * delta * 1.7)
	for marker in lane_marks:
		marker.position.z += speed * delta
		if marker.position.z > 12.0:
			marker.position.z -= 315.0
	for segment in roadside:
		segment.position.z += speed * delta
		if segment.position.z > 12.0:
			segment.position.z -= 324.0
	car.position.x = clamp(car.position.x + steering * 7.0 * delta, -5.0, 5.0)
	car.rotation.z = lerp(car.rotation.z, -steering * 0.12, delta * 6.0)

	camera.position.x = lerp(camera.position.x, car.position.x * 0.65, delta * 4.0)

	for obstacle in obstacles:
		obstacle.position.z += speed * delta

		if obstacle.position.z > 12.0:
			obstacle.position.z -= 230.0
			obstacle.position.x = float(randi_range(-2, 2)) * 2.0

		if abs(obstacle.position.z - car.position.z) < 1.8 and abs(obstacle.position.x - car.position.x) < 1.6:
			crashed = true
			status_label.text = "CRASH!\nTRY AGAIN"

	score_label.text = "DISTANCE: %dm" % int(distance)
