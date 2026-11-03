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
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.5
	add_child(sun)

	_make_box(self, Vector3(0, -0.35, -100), Vector3(13, 0.5, 300), Color(0.13, 0.15, 0.19))
	_make_box(self, Vector3(-6.5, 0, -100), Vector3(0.3, 0.7, 300), Color(0.9, 0.2, 0.2))
	_make_box(self, Vector3(6.5, 0, -100), Vector3(0.3, 0.7, 300), Color(0.9, 0.2, 0.2))

	for i in range(50):
		var z := -float(i) * 6.0
		_make_box(self, Vector3(-2.2, -0.07, z), Vector3(0.14, 0.03, 2.8), Color.WHITE)
		_make_box(self, Vector3(2.2, -0.07, z), Vector3(0.14, 0.03, 2.8), Color.WHITE)

func _create_car() -> void:
	car = Node3D.new()
	add_child(car)
	car.position = Vector3(0, 0.65, 4)

	_make_box(car, Vector3.ZERO, Vector3(1.6, 0.55, 3), Color(0.05, 0.4, 1.0))
	_make_box(car, Vector3(0, 0.48, -0.2), Vector3(1.25, 0.55, 1.4), Color(0.07, 0.12, 0.2))

	for x in [-0.9, 0.9]:
		for z in [-0.95, 0.95]:
			_make_box(car, Vector3(x, -0.3, z), Vector3(0.35, 0.65, 0.65), Color(0.03, 0.03, 0.04))

	camera = Camera3D.new()
	camera.position = Vector3(0, 5.5, 12)
	camera.rotation_degrees.x = -18
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
