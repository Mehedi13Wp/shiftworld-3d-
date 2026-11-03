extends Node3D

# SHIFTWORLD 3D — Phase 1: four-lane road, nature and mobile driving.
# Lightweight primitive meshes keep this prototype usable on budget Android phones.
const ROAD_LENGTH := 340.0
const ROAD_HALF_WIDTH := 8.0
const CRUISE_SPEED := 16.0
const MAX_SPEED := 27.0
const MIN_SPEED := 0.0

var car: Node3D
var camera: Camera3D
var speed := 0.0
var steering := 0.0
var accelerating := false
var braking := false
var distance := 0.0
var crashed := false
var obstacles: Array[Node3D] = []
var wheels: Array[Node3D] = []
var lane_marks: Array[Node3D] = []
var roadside: Array[Node3D] = []
var landmarks: Array[Node3D] = []
var score_label: Label
var status_label: Label
var difficulty := 0
var game_started := false
var music_enabled := true
var sound_enabled := true
var music_player: AudioStreamPlayer
var music_test_label: Label
var effect_player: AudioStreamPlayer
var music_button: Button
var sound_button: Button
var menu_panel: PanelContainer
var car_paint := Color(0.82, 0.025, 0.035)
const SUPERCAR_MODEL_PATH := "res://assets/vehicles/red_supercar.glb"
var traffic_colors := [Color(0.64, 0.07, 0.08), Color(0.12, 0.23, 0.35), Color(0.83, 0.84, 0.85), Color(0.14, 0.16, 0.19)]

func _ready() -> void:
	_create_environment()
	_roadside_details()
	_create_car()
	_create_ui()
	_create_audio()
	_spawn_obstacles()
	_create_service_area()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.42
	mat.metallic = 0.12
	return mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _cylinder(parent: Node3D, pos: Vector3, height: float, radius: float, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _foliage(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color)
	parent.add_child(item)

func _tree(parent: Node3D, x: float, big: bool, kind: int) -> void:
	var trunk_height := 3.2 if big else 1.5
	var crown_radius := 2.4 if big else 0.85
	_cylinder(parent, Vector3(x, trunk_height * 0.5 - 0.2, 0), trunk_height, 0.35 if big else 0.13, Color(0.33, 0.21, 0.12))
	var crown_color := Color(0.12, 0.37, 0.16)
	if kind == 1:
		crown_color = Color(0.08, 0.27, 0.20)
	elif kind == 2:
		crown_color = Color(0.24, 0.45, 0.14)
	elif kind == 3:
		crown_color = Color(0.65, 0.24, 0.45)
	_foliage(parent, Vector3(x, trunk_height + crown_radius * 0.38 - 0.2, 0), crown_radius, crown_color)
	if big:
		_foliage(parent, Vector3(x - 0.9, trunk_height + 0.35, 0.4), crown_radius * 0.67, crown_color.lightened(0.08))
		_foliage(parent, Vector3(x + 0.9, trunk_height + 0.35, -0.3), crown_radius * 0.65, crown_color.darkened(0.06))

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	# Keep shadows off for a stable frame rate on lower-end Android GPUs.
	sun.shadow_enabled = false
	add_child(sun)

	_box(self, Vector3(0, -0.58, -145), Vector3(100, 0.14, ROAD_LENGTH), Color(0.21, 0.34, 0.19))
	_box(self, Vector3(0, -0.37, -145), Vector3(16, 0.48, ROAD_LENGTH), Color(0.11, 0.13, 0.16))
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 7.85, -0.08, -145), Vector3(0.18, 0.04, ROAD_LENGTH), Color(0.95, 0.94, 0.83))
		_box(self, Vector3(side * 8.4, -0.02, -145), Vector3(0.28, 0.35, ROAD_LENGTH), Color(0.45, 0.48, 0.49))
	# Center divider separates two lanes in each direction.
	_box(self, Vector3(0, -0.01, -145), Vector3(0.30, 0.34, ROAD_LENGTH), Color(0.74, 0.76, 0.70))

	for i in range(44):
		var marker := Node3D.new()
		add_child(marker)
		marker.position.z = -float(i) * 7.5
		for x in [-4.0, 4.0]:
			_box(marker, Vector3(x, -0.10, 0), Vector3(0.15, 0.04, 3.5), Color(0.98, 0.97, 0.88))
		lane_marks.append(marker)

	# One larger tree after every three smaller trees, alternating species.
	for i in range(40):
		var segment := Node3D.new()
		add_child(segment)
		segment.position.z = -float(i) * 8.0
		var big := i % 4 == 3
		for side in [-1.0, 1.0]:
			var offset := 1.5 if big else 0.0
			_tree(segment, side * (11.2 + offset), big, int(i / 4 + (0 if side < 0.0 else 2)) % 4)
		roadside.append(segment)

func _roadside_details() -> void:
	# Repeating crash barriers, reflectors and a distant layered mountain skyline.
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 9.0, 0.23, -145.0), Vector3(0.11, 0.16, ROAD_LENGTH), Color(0.68, 0.73, 0.76))
		for i in range(55):
			var z := 12.0 - float(i) * 6.0
			_box(self, Vector3(side * 9.0, -0.10, z), Vector3(0.12, 0.78, 0.13), Color(0.45, 0.49, 0.51))
			if i % 3 == 0:
				_box(self, Vector3(side * 8.95, 0.32, z), Vector3(0.16, 0.12, 0.22), Color(0.97, 0.69, 0.18))
		for i in range(18):
			var z := -float(i) * 19.0
			var hill := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 12.0 + float(i % 4) * 3.0
			mesh.height = 14.0 + float(i % 5) * 2.0
			mesh.radial_segments = 12
			mesh.rings = 6
			hill.mesh = mesh
			hill.position = Vector3(side * (38.0 + float(i % 3) * 12.0), -4.0, z)
			hill.material_override = _material(Color(0.18, 0.32, 0.25) if i % 2 == 0 else Color(0.22, 0.37, 0.27))
			add_child(hill)

func _traffic_vehicle(parent: Node3D, paint: Color) -> void:
	# Replaces arcade orange cubes with traffic silhouettes.
	_box(parent, Vector3(0, -0.10, 0), Vector3(1.68, 0.46, 3.65), paint)
	_box(parent, Vector3(0, 0.28, -0.15), Vector3(1.43, 0.56, 1.85), Color(0.10, 0.16, 0.20))
	_box(parent, Vector3(0, 0.58, -0.15), Vector3(1.32, 0.08, 1.48), paint.lightened(0.12))
	for x in [-0.60, 0.60]:
		_box(parent, Vector3(x, 0.02, 1.85), Vector3(0.34, 0.13, 0.07), Color(0.92, 0.09, 0.06))
		_box(parent, Vector3(x, 0.02, -1.86), Vector3(0.34, 0.13, 0.07), Color(0.94, 0.91, 0.76))
	for x in [-0.90, 0.90]:
		for z in [-1.15, 1.15]:
			var tire := _cylinder(parent, Vector3(x, -0.37, z), 0.22, 0.35, Color(0.04, 0.04, 0.05))
			tire.rotation_degrees.z = 90

func _sign(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	_box(parent, pos, size, color)

func _building(parent: Node3D, x: float, z: float, width: float, depth: float, height: float, wall: Color, roof: Color) -> void:
	_box(parent, Vector3(x, height * 0.5 - 0.38, z), Vector3(width, height, depth), wall)
	_box(parent, Vector3(x, height - 0.30, z), Vector3(width + 0.5, 0.32, depth + 0.5), roof)
	# Windows and entrance face the road.
	var front := z + depth * 0.5 + 0.025
	_box(parent, Vector3(x, 0.85, front), Vector3(1.15, 1.7, 0.07), Color(0.08, 0.15, 0.23))
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(x + side * width * 0.30, height * 0.58, front), Vector3(0.85, 0.8, 0.07), Color(0.25, 0.65, 0.76))

func _create_service_area() -> void:
	# A roadside town/rest-stop vignette. It scrolls past the camera for now.
	# In the next milestone it becomes a fixed, drivable destination.
	var stop := Node3D.new()
	add_child(stop)
	stop.position.z = -85.0
	landmarks.append(stop)

	# Right-side parking plaza and marked parking bays.
	_box(stop, Vector3(19.5, -0.27, 0), Vector3(21.0, 0.16, 45.0), Color(0.27, 0.29, 0.30))
	for i in range(5):
		var bay_z := -15.0 + float(i) * 7.0
		_box(stop, Vector3(11.0, -0.16, bay_z), Vector3(5.0, 0.025, 0.12), Color(0.95, 0.93, 0.79))
		_box(stop, Vector3(15.5, -0.16, bay_z), Vector3(0.12, 0.025, 6.7), Color(0.95, 0.93, 0.79))
	# Low-cost town architecture and storefronts.
	_building(stop, 24.0, -12.0, 8.0, 7.0, 4.8, Color(0.88, 0.78, 0.58), Color(0.55, 0.22, 0.15))
	_building(stop, 24.0, 1.0, 9.0, 8.0, 6.5, Color(0.85, 0.90, 0.91), Color(0.16, 0.48, 0.61))
	_building(stop, 24.0, 15.0, 8.0, 7.0, 4.4, Color(0.83, 0.61, 0.49), Color(0.38, 0.28, 0.49))
	# Hospital cross: white sign with a red cross.
	_sign(stop, Vector3(24.0, 5.6, 5.13), Vector3(2.1, 1.6, 0.12), Color.WHITE)
	_sign(stop, Vector3(24.0, 5.6, 5.21), Vector3(0.38, 1.28, 0.06), Color(0.92, 0.12, 0.13))
	_sign(stop, Vector3(24.0, 5.6, 5.25), Vector3(1.22, 0.34, 0.06), Color(0.92, 0.12, 0.13))
	# Service station canopy and columns.
	_box(stop, Vector3(12.5, 3.1, 12.0), Vector3(7.0, 0.4, 6.0), Color(0.18, 0.51, 0.68))
	for x in [9.7, 15.3]:
		_cylinder(stop, Vector3(x, 1.35, 12.0), 2.8, 0.16, Color(0.88, 0.90, 0.91))
	# Rest-area sign visible from the road.
	_cylinder(stop, Vector3(9.0, 2.1, -17.0), 4.2, 0.14, Color(0.76, 0.78, 0.80))
	_sign(stop, Vector3(9.0, 4.2, -17.0), Vector3(3.4, 1.3, 0.22), Color(0.06, 0.47, 0.33))
	# Roadside decorative flowering trees.
	for i in range(4):
		var planter := Node3D.new()
		stop.add_child(planter)
		planter.position.z = -18.0 + float(i) * 11.0
		_tree(planter, 34.0, i % 2 == 0, 3 if i % 2 == 0 else 2)

func _create_car() -> void:
	car = Node3D.new()
	add_child(car)
	car.position = Vector3(2.0, 0.67, 4.0)
	# A licensed GLB can replace the procedural preview without changing driving controls.
	if ResourceLoader.exists(SUPERCAR_MODEL_PATH):
		var scene := load(SUPERCAR_MODEL_PATH) as PackedScene
		if scene != null:
			var model := scene.instantiate()
			car.add_child(model)
		else:
			_create_supercar_preview()
	else:
		_create_supercar_preview()
	camera = Camera3D.new()
	camera.position = Vector3(2.0, 3.7, 12.0)
	camera.rotation_degrees.x = -10.0
	camera.current = true
	add_child(camera)

func _create_supercar_preview() -> void:
	# Temporary low-poly preview; NOT the final licensed photorealistic GLB.
	_box(car, Vector3(0, -0.17, 0), Vector3(1.96, 0.30, 4.25), car_paint)
	_box(car, Vector3(0, -0.05, -1.38), Vector3(1.89, 0.13, 1.43), car_paint.lightened(0.06))
	_box(car, Vector3(0, 0.19, 0.12), Vector3(1.61, 0.40, 1.85), Color(0.065, 0.085, 0.11))
	_box(car, Vector3(0, 0.41, 0.14), Vector3(1.48, 0.09, 1.48), car_paint)
	_box(car, Vector3(0, -0.20, -2.14), Vector3(1.67, 0.12, 0.10), Color(0.055, 0.06, 0.07))
	_box(car, Vector3(0, -0.17, 2.14), Vector3(1.76, 0.15, 0.12), Color(0.055, 0.06, 0.07))
	_box(car, Vector3(0, 0.13, 1.89), Vector3(1.78, 0.07, 0.32), Color(0.055, 0.06, 0.07))
	for x in [-0.75, 0.75]:
		_box(car, Vector3(x, -0.07, -2.15), Vector3(0.37, 0.10, 0.06), Color(0.95, 0.95, 0.83))
		_box(car, Vector3(x, -0.07, 2.16), Vector3(0.40, 0.11, 0.06), Color(0.95, 0.05, 0.06))
		_box(car, Vector3(x * 1.16, 0.11, -0.40), Vector3(0.12, 0.11, 0.26), car_paint)
	for x in [-0.97, 0.97]:
		for z in [-1.40, 1.40]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, -0.31, z)
			car.add_child(pivot)
			var tire := _cylinder(pivot, Vector3.ZERO, 0.30, 0.43, Color(0.028, 0.03, 0.035))
			tire.rotation_degrees.z = 90
			var rim := _cylinder(pivot, Vector3(0.02 if x > 0 else -0.02, 0, 0), 0.04, 0.27, Color(0.25, 0.27, 0.29))
			rim.rotation_degrees.z = 90
			wheels.append(pivot)

func _spawn_obstacles() -> void:
	for i in range(8):
		var obstacle := Node3D.new()
		add_child(obstacle)
		obstacle.position = Vector3(2.0 if i % 2 == 0 else 6.0, 0.75, -85.0 - float(i) * 34.0)
		_traffic_vehicle(obstacle, traffic_colors[i % traffic_colors.size()])
		obstacles.append(obstacle)

func _button(parent: Control, title: String, pos: Vector2, dimensions: Vector2) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.position = pos
	btn.size = dimensions
	btn.add_theme_font_size_override("font_size", 23)
	parent.add_child(btn)
	return btn

func _tone_stream(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(duration * float(rate))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var time := float(i) / float(rate)
		var fade: float = minf(1.0, minf(float(i) / 300.0, float(frames - i) / 450.0))
		var pulse := sin(TAU * frequency * time)
		var sample := int(clampf(pulse * fade * volume, -1.0, 1.0) * 32767.0)
		if sample < 0:
			sample += 65536
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _create_audio() -> void:
	# Original lightweight rhythmic synthesizer loop; no copyrighted recordings.
	var rate := 22050
	var duration := 2.0
	var frames := int(duration * float(rate))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var melody := [220.0, 261.63, 329.63, 293.66, 220.0, 329.63, 392.0, 293.66]
	for i in range(frames):
		var t := float(i) / float(rate)
		var beat := int(t * 4.0)
		var local_beat := fmod(t * 4.0, 1.0)
		var note: float = melody[beat % melody.size()]
		var lead := (sin(TAU * note * t) + 0.25 * sin(TAU * note * 2.0 * t)) * exp(-local_beat * 3.0) * 0.24
		var bass := sin(TAU * (110.0 if beat % 4 == 0 else 164.82) * t) * exp(-local_beat * 7.0) * 0.24
		var sample := int(clampf(lead + bass, -1.0, 1.0) * 32767.0)
		if sample < 0:
			sample += 65536
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var loop := AudioStreamWAV.new()
	loop.format = AudioStreamWAV.FORMAT_16_BITS
	loop.mix_rate = rate
	loop.stereo = false
	loop.data = data
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = frames
	loop.loop_begin = 0
	music_player = AudioStreamPlayer.new()
	music_player.stream = loop
	music_player.volume_db = 0.0
	music_player.bus = "Master"
	add_child(music_player)
	music_player.finished.connect(func():
		if music_enabled and game_started and not crashed:
			music_player.play()
	)
	effect_player = AudioStreamPlayer.new()
	effect_player.stream = _tone_stream(110.0, 0.48, 0.32)
	add_child(effect_player)

func _choose_mode(mode: int) -> void:
	difficulty = mode
	game_started = true
	menu_panel.visible = false
	speed = 0.0
	if music_enabled and is_instance_valid(music_player):
		music_player.play()
		if is_instance_valid(music_test_label):
			music_test_label.text = "MUSIC: PLAYING" if music_player.playing else "MUSIC: FAILED"

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	score_label = Label.new()
	score_label.position = Vector2(22, 32)
	score_label.add_theme_font_size_override("font_size", 28)
	ui.add_child(score_label)
	status_label = Label.new()
	status_label.position = Vector2(115, 310)
	status_label.add_theme_font_size_override("font_size", 38)
	ui.add_child(status_label)

	music_test_label = Label.new()
	music_test_label.position = Vector2(22, 208)
	music_test_label.add_theme_font_size_override("font_size", 20)
	music_test_label.text = "MUSIC: READY"
	ui.add_child(music_test_label)
	music_button = _button(ui, "MUSIC ON", Vector2(20, 135), Vector2(170, 65))
	music_button.pressed.connect(func():
		music_enabled = not music_enabled
		music_button.text = "MUSIC ON" if music_enabled else "MUSIC OFF"
		if music_enabled and game_started and not crashed:
			music_player.play()
		else:
			music_player.stop()
		music_test_label.text = "MUSIC: PLAYING" if music_player.playing else "MUSIC: OFF"
	)
	sound_button = _button(ui, "SOUND ON", Vector2(195, 135), Vector2(175, 65))
	sound_button.pressed.connect(func():
		sound_enabled = not sound_enabled
		sound_button.text = "SOUND ON" if sound_enabled else "SOUND OFF"
	)
	menu_panel = PanelContainer.new()
	menu_panel.position = Vector2(125, 335)
	menu_panel.custom_minimum_size = Vector2(470, 390)
	ui.add_child(menu_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 15)
	menu_panel.add_child(menu)
	var heading := Label.new()
	heading.text = "SHIFTWORLD 3D\nCHOOSE DIFFICULTY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 29)
	menu.add_child(heading)
	for i in range(3):
		var mode_button := Button.new()
		mode_button.text = ["NORMAL", "MEDIUM", "HARD"][i]
		mode_button.custom_minimum_size = Vector2(430, 80)
		mode_button.add_theme_font_size_override("font_size", 27)
		menu.add_child(mode_button)
		mode_button.pressed.connect(_choose_mode.bind(i))

	var left := _button(ui, "LEFT", Vector2(22, 1060), Vector2(150, 100))
	left.button_down.connect(func(): steering = -1.0)
	left.button_up.connect(func(): steering = 0.0)
	var right := _button(ui, "RIGHT", Vector2(182, 1060), Vector2(150, 100))
	right.button_down.connect(func(): steering = 1.0)
	right.button_up.connect(func(): steering = 0.0)
	var brake := _button(ui, "BRAKE", Vector2(390, 1060), Vector2(145, 100))
	brake.button_down.connect(func(): braking = true)
	brake.button_up.connect(func(): braking = false)
	var gas := _button(ui, "GAS", Vector2(545, 1060), Vector2(145, 100))
	gas.button_down.connect(func(): accelerating = true)
	gas.button_up.connect(func(): accelerating = false)
	var restart := _button(ui, "RESTART", Vector2(255, 1180), Vector2(210, 75))
	restart.pressed.connect(func(): get_tree().reload_current_scene())

func _process(delta: float) -> void:
	if crashed or not game_started:
		return
	var target_speed: float = [0.0, 0.0, 0.0][difficulty]
	if accelerating:
		target_speed = [5.5, 9.0, 14.0][difficulty]
	if braking:
		target_speed = MIN_SPEED
	speed = move_toward(speed, target_speed, (24.0 if braking else 9.0) * delta)
	distance += speed * delta
	# This milestone still uses scrolling scenery; full world-space driving comes next.
	car.position.x = clamp(car.position.x + steering * (1.65 + speed * 0.08) * delta, 1.1, 6.9)
	car.rotation.z = lerp(car.rotation.z, -steering * 0.045, min(delta * 6.0, 1.0))
	camera.position.x = lerp(camera.position.x, car.position.x, min(delta * 3.0, 1.0))
	for wheel in wheels:
		wheel.rotate_x(speed * delta * 1.7)
	for marker in lane_marks:
		marker.position.z += speed * delta
		if marker.position.z > 14.0:
			marker.position.z -= 330.0
	for segment in roadside:
		segment.position.z += speed * delta
		if segment.position.z > 14.0:
			segment.position.z -= 320.0
	for landmark in landmarks:
		landmark.position.z += speed * delta
		if landmark.position.z > 75.0:
			landmark.position.z -= 320.0
	for obstacle in obstacles:
		obstacle.position.z += speed * delta
		if obstacle.position.z > 14.0:
			obstacle.position.z -= 300.0
			obstacle.position.x = 2.0 if randi() % 2 == 0 else 6.0
		if abs(obstacle.position.z - car.position.z) < 3.3 and abs(obstacle.position.x - car.position.x) < 1.65:
			crashed = true
			status_label.text = "CRASH!\nTRY AGAIN"
	score_label.text = "DISTANCE: %dm  |  SPEED: %d km/h" % [int(distance), int(speed * 3.6)]
