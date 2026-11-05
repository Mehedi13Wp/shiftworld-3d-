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
var city_challenge: Node3D
var city_minimap: Control
var road_reset_button: Button
var city_map_data: Dictionary = {}
var challenge_enabled := false
var steering_smoothed := 0.0
var minimap_refresh_time := 0.0
var recovery_message_time := 0.0
var mission_label: Label
var coins_label: Label
var attribution_label: Label
var gear_button: Button
var garage_button: Button
var garage_panel: PanelContainer
var garage_title: Label
var garage_buttons: Array[Button] = []
var car_visual: Node3D
var selected_car := 0
var owned_cars: Array[int] = [0]
var total_distance := 0.0
var last_distance_milestone := 0
var coins := 0
var city_velocity := 0.0
var reverse_gear := false
var collision_flash := 0.0
var driving_buttons: Array[Button] = []
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
var city_mode := false
var city_world: Node3D
var city_data_ready := false
var city_heading := 0.0
var city_spawn := Vector3.ZERO
var car_paint := Color(0.82, 0.025, 0.035)
const CAR_MODELS := [
	"res://assets/vehicles/sedan_sports.glb",
	"res://assets/vehicles/sedan_city.glb",
	"res://assets/vehicles/suv_city.glb"
]
const CAR_NAMES := ["SPORT SEDAN", "CITY SEDAN", "URBAN SUV"]
const CAR_PRICES := [0, 350, 800]
const TREE_MODEL_PATH := "res://assets/nature/tree_detailed.glb"
const OAK_MODEL_PATH := "res://assets/nature/tree_oak.glb"
const ROAD_TEXTURE_PATH := "res://assets/roads/asphalt.jpg"
var traffic_colors := [Color(0.64, 0.07, 0.08), Color(0.12, 0.23, 0.35), Color(0.83, 0.84, 0.85), Color(0.14, 0.16, 0.19)]

func _ready() -> void:
	_load_progress()
	_create_environment()
	_create_car()
	_create_ui()
	_create_audio()

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
	var path := OAK_MODEL_PATH if kind % 3 == 0 else TREE_MODEL_PATH
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var model := packed.instantiate() as Node3D
			if model != null:
				parent.add_child(model)
				model.position = Vector3(x, -0.38, 0)
				model.scale = Vector3.ONE * (1.9 if big else 1.25)
				model.rotation.y = float(kind) * 0.71
				return
	# Fallback only if nature assets have not yet been downloaded.
	var trunk_height := 3.2 if big else 1.5
	_cylinder(parent, Vector3(x, trunk_height * 0.5 - 0.2, 0), trunk_height, 0.28, Color(0.33, 0.21, 0.12))
	_foliage(parent, Vector3(x, trunk_height + 0.5, 0), 1.8 if big else 0.9, Color(0.12, 0.37, 0.16))

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.79, 0.94)
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
	# The legacy endless highway is no longer initialized at startup.

func _create_legacy_highway_geometry() -> void:
	_box(self, Vector3(0, -0.58, -145), Vector3(100, 0.14, ROAD_LENGTH), Color(0.21, 0.34, 0.19))
	var asphalt := _box(self, Vector3(0, -0.37, -145), Vector3(16, 0.48, ROAD_LENGTH), Color(0.11, 0.13, 0.16))
	var road_mat := StandardMaterial3D.new()
	var road_noise := FastNoiseLite.new()
	road_noise.seed = 47119
	road_noise.frequency = 0.11
	road_noise.fractal_octaves = 3
	var asphalt_texture := NoiseTexture2D.new()
	asphalt_texture.width = 512
	asphalt_texture.height = 512
	asphalt_texture.seamless = true
	asphalt_texture.noise = road_noise
	var road_gradient := Gradient.new()
	road_gradient.set_color(0, Color(0.085, 0.091, 0.102))
	road_gradient.set_color(1, Color(0.19, 0.20, 0.21))
	asphalt_texture.color_ramp = road_gradient
	road_mat.albedo_texture = asphalt_texture
	if ResourceLoader.exists(ROAD_TEXTURE_PATH):
		var external_tex := load(ROAD_TEXTURE_PATH) as Texture2D
		if external_tex != null:
			road_mat.albedo_texture = external_tex
	road_mat.uv1_scale = Vector3(3.0, 65.0, 1.0)
	road_mat.roughness = 0.95
	asphalt.material_override = road_mat
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
	var body := CharacterBody3D.new()
	body.name = "DriverCar"
	body.collision_layer = 2
	body.collision_mask = 1
	car = body
	add_child(car)
	car.position = Vector3(2.0, 0.67, 4.0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.75, 1.05, 3.95)
	collider.shape = shape
	car.add_child(collider)
	_apply_car_visual()
	camera = Camera3D.new()
	camera.position = Vector3(2.0, 3.7, 12.0)
	camera.rotation_degrees.x = -10.0
	camera.current = true
	add_child(camera)

func _apply_car_visual() -> void:
	if car == null:
		return
	if car_visual != null and is_instance_valid(car_visual):
		car.remove_child(car_visual)
		car_visual.queue_free()
	car_visual = Node3D.new()
	car_visual.name = "VehicleVisual"
	car.add_child(car_visual)
	wheels.clear()
	var model_path := str(CAR_MODELS[clampi(selected_car, 0, CAR_MODELS.size() - 1)])
	var scene: PackedScene = null
	if ResourceLoader.exists(model_path):
		scene = load(model_path) as PackedScene
	if scene != null:
		var model := scene.instantiate() as Node3D
		if model != null:
			car_visual.add_child(model)
			model.rotation.y = 0.0
			_fit_imported_car(model)
			return
	# Real assets may be absent during headless tests; do not crash the game.
	car_paint = [Color(0.78,0.06,0.06), Color(0.10,0.25,0.65), Color(0.19,0.22,0.25)][clampi(selected_car, 0, 2)]
	_create_supercar_preview()

func _fit_imported_car(model: Node3D) -> void:
	# Measure the actual imported geometry, including nested GLB transforms.
	# Fit its longest horizontal dimension to a 4.4 m vehicle.
	var bounds := AABB()
	var found := false
	var pending: Array[Node] = [model]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				var mesh_bounds := mesh_node.mesh.get_aabb()
				var relative := model.global_transform.affine_inverse() * mesh_node.global_transform
				for xi in range(2):
					for yi in range(2):
						for zi in range(2):
							var corner := mesh_bounds.position + Vector3(mesh_bounds.size.x * float(xi), mesh_bounds.size.y * float(yi), mesh_bounds.size.z * float(zi))
							var p := relative * corner
							if not found:
								bounds = AABB(p, Vector3.ZERO)
								found = true
							else:
								bounds = bounds.expand(p)
		for child in node.get_children():
			pending.append(child)
	if not found:
		return
	var longest := maxf(bounds.size.x, bounds.size.z)
	if longest < 0.01:
		return
	var factor := 4.4 / longest
	model.scale = Vector3.ONE * factor
	var center := bounds.position + bounds.size * 0.5
	# Account for the 90-degree Y rotation: model's local X becomes world Z.
	var offset := Vector3(-center.x, -bounds.position.y, -center.z) * factor
	model.position = model.basis * offset
	# Car root is at y=0.67, place wheels near ground instead of floating.
	model.position.y -= 0.62

func _repaint_supercar(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh != null:
				for surface in range(mesh_node.mesh.get_surface_count()):
					var original := mesh_node.mesh.surface_get_material(surface) as StandardMaterial3D
					if original == null:
						continue
					var c := original.albedo_color
					# Keep transparent windows and dark tires untouched.
					if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						continue
					if c.v < 0.22 or c.s < 0.12:
						continue
					var paint := original.duplicate() as StandardMaterial3D
					paint.albedo_texture = null
					paint.albedo_color = Color(0.82, 0.018, 0.028, c.a)
					paint.metallic = 0.48
					paint.roughness = 0.24
					mesh_node.set_surface_override_material(surface, paint)
		_repaint_supercar(child)

func _create_supercar_preview() -> void:
	# Temporary low-poly preview; NOT the final licensed photorealistic GLB.
	_box(car_visual, Vector3(0, -0.17, 0), Vector3(1.96, 0.30, 4.25), car_paint)
	_box(car_visual, Vector3(0, -0.05, -1.38), Vector3(1.89, 0.13, 1.43), car_paint.lightened(0.06))
	_box(car_visual, Vector3(0, 0.19, 0.12), Vector3(1.61, 0.40, 1.85), Color(0.065, 0.085, 0.11))
	_box(car_visual, Vector3(0, 0.41, 0.14), Vector3(1.48, 0.09, 1.48), car_paint)
	_box(car_visual, Vector3(0, -0.20, -2.14), Vector3(1.67, 0.12, 0.10), Color(0.055, 0.06, 0.07))
	_box(car_visual, Vector3(0, -0.17, 2.14), Vector3(1.76, 0.15, 0.12), Color(0.055, 0.06, 0.07))
	_box(car_visual, Vector3(0, 0.13, 1.89), Vector3(1.78, 0.07, 0.32), Color(0.055, 0.06, 0.07))
	for x in [-0.75, 0.75]:
		_box(car_visual, Vector3(x, -0.07, -2.15), Vector3(0.37, 0.10, 0.06), Color(0.95, 0.95, 0.83))
		_box(car_visual, Vector3(x, -0.07, 2.16), Vector3(0.40, 0.11, 0.06), Color(0.95, 0.05, 0.06))
		_box(car_visual, Vector3(x * 1.16, 0.11, -0.40), Vector3(0.12, 0.11, 0.26), car_paint)
	for x in [-0.97, 0.97]:
		for z in [-1.40, 1.40]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, -0.31, z)
			car_visual.add_child(pivot)
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

func _start_city_mode(with_challenge: bool = true) -> void:
	var path := "res://data/cities/manhattan.json"
	if not FileAccess.file_exists(path):
		status_label.text = "MANHATTAN MAP NOT INSTALLED"
		return
	# Hide the scrolling highway and load the OSM-derived city world.
	# The existing driving UI, audio, collision and highway mode remain intact.
	city_world = Node3D.new()
	var city_script := load("res://scripts/city_world.gd") as Script
	if city_script == null:
		status_label.text = "CITY RENDERER MISSING"
		return
	city_world.set_script(city_script)
	add_child(city_world)
	if not city_world.call("load_city", "manhattan"):
		city_world.queue_free()
		status_label.text = "CITY MAP FAILED"
		return
	city_data_ready = true
	city_mode = true
	var file := FileAccess.open(path, FileAccess.READ)
	var map_data = JSON.parse_string(file.get_as_text())
	if not (map_data is Dictionary):
		status_label.text = "CITY DATA INVALID"
		return
	city_map_data = map_data
	challenge_enabled = with_challenge
	var nearest := INF
	var chosen_a := Vector3.ZERO
	var chosen_b := Vector3(0,0,-1)
	var chosen_road_name := ""
	for road in map_data.get("roads", []):
		var pts: Array = road.get("points", [])
		for i in range(pts.size()-1):
			var a := Vector3(float(pts[i][0]), 0.0, float(pts[i][1]))
			var b := Vector3(float(pts[i+1][0]), 0.0, float(pts[i+1][1]))
			var d := (a+b).length_squared()
			if d < nearest and a.distance_to(b) > 5.0:
				nearest = d
				chosen_a = a
				chosen_b = b
				chosen_road_name = str(road.get("name", ""))
	city_spawn = (chosen_a + chosen_b)*0.5
	var direction := (chosen_b-chosen_a).normalized()
	city_heading = atan2(-direction.x,-direction.z)
	car.position = city_spawn + Vector3(0,0.67,0)
	car.rotation.y = city_heading
	city_velocity = 0.0
	steering_smoothed = 0.0
	reverse_gear = false
	camera.position = car.position + Vector3(sin(city_heading)*11.5,4.7,cos(city_heading)*11.5)
	camera.look_at(car.position+Vector3.UP*1.1,Vector3.UP)
	# City center map coordinates start at zero; the player stays at a local origin.
	# Hide legacy highway meshes, but keep player, camera, UI and audio.
	for child in get_children():
		if child is MeshInstance3D and child != car:
			child.visible = false
	for marker in lane_marks:
		marker.visible = false
	for segment in roadside:
		segment.visible = false
	for landmark in landmarks:
		landmark.visible = false
	for obstacle in obstacles:
		obstacle.visible = false
	var challenge_script := load("res://scripts/city_challenge.gd") as Script
	if with_challenge and challenge_script != null:
		city_challenge = Node3D.new()
		city_challenge.set_script(challenge_script)
		add_child(city_challenge)
		if bool(city_challenge.call("setup", map_data, city_spawn, city_heading, chosen_road_name)):
			city_challenge.connect("checkpoint_reached", Callable(self, "_on_checkpoint_reached"))
			city_challenge.connect("run_completed", Callable(self, "_on_run_completed"))
		else:
			city_challenge.queue_free()
			city_challenge = null
	mission_label.visible = true
	coins_label.visible = true
	attribution_label.visible = true
	gear_button.visible = true
	gear_button.text = "GEAR: D"
	road_reset_button.visible = true
	if city_minimap != null:
		city_minimap.call("configure", city_map_data)
		city_minimap.visible = true
		minimap_refresh_time = 0.0
	_choose_mode(0)

func _choose_mode(mode: int) -> void:
	difficulty = mode
	game_started = true
	menu_panel.visible = false
	for btn in driving_buttons:
		btn.visible = true
	speed = 0.0
	if music_enabled and is_instance_valid(music_player):
		music_player.play()
		if is_instance_valid(music_test_label):
			music_test_label.text = "MUSIC: PLAYING" if music_player.playing else "MUSIC: FAILED"

func _load_progress() -> void:
	if not FileAccess.file_exists("user://shiftworld_progress.json"):
		return
	var file := FileAccess.open("user://shiftworld_progress.json", FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		coins = maxi(0, int(data.get("coins", 0)))
		total_distance = maxf(0.0, float(data.get("total_distance", 0.0)))
		last_distance_milestone = int(floor(total_distance / 250.0))
		selected_car = clampi(int(data.get("selected_car", 0)), 0, CAR_MODELS.size() - 1)
		owned_cars = [0]
		var saved_owned: Array = data.get("owned_cars", [0])
		for entry in saved_owned:
			var id := int(entry)
			if id > 0 and id < CAR_MODELS.size() and not owned_cars.has(id):
				owned_cars.append(id)
		if not owned_cars.has(selected_car):
			selected_car = 0

func _save_progress() -> void:
	var file := FileAccess.open("user://shiftworld_progress.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"coins": coins, "total_distance": total_distance, "owned_cars": owned_cars, "selected_car": selected_car}))

func _distance_reward(travelled: float) -> void:
	if travelled <= 0.0 or travelled > 5.0:
		return
	total_distance += travelled
	var new_milestone := int(floor(total_distance / 250.0))
	if new_milestone <= last_distance_milestone:
		return
	var steps := new_milestone - last_distance_milestone
	last_distance_milestone = new_milestone
	var earned := steps * 50
	coins += earned
	coins_label.text = "COINS  %d" % coins
	status_label.text = "+%d COINS  |  DISTANCE BONUS" % earned
	recovery_message_time = 2.6
	_save_progress()

func _open_garage() -> void:
	if garage_panel == null:
		return
	if city_mode and absf(city_velocity) > 0.6:
		status_label.text = "STOP THE CAR TO OPEN GARAGE"
		recovery_message_time = 2.0
		return
	_refresh_garage()
	accelerating = false
	braking = false
	garage_panel.visible = true
	if menu_panel != null:
		menu_panel.visible = false

func _close_garage() -> void:
	garage_panel.visible = false
	if not game_started:
		menu_panel.visible = true

func _refresh_garage() -> void:
	if garage_title == null:
		return
	garage_title.text = "SHIFTWORLD GARAGE  |  %d COINS" % coins
	for i in range(garage_buttons.size()):
		var choice := garage_buttons[i]
		if selected_car == i:
			choice.text = "%s  |  SELECTED" % CAR_NAMES[i]
		elif owned_cars.has(i):
			choice.text = "%s  |  SELECT" % CAR_NAMES[i]
		else:
			choice.text = "%s  |  UNLOCK %d COINS" % [CAR_NAMES[i], CAR_PRICES[i]]

func _choose_garage_car(index: int) -> void:
	if index < 0 or index >= CAR_NAMES.size():
		return
	if not owned_cars.has(index):
		var price := int(CAR_PRICES[index])
		if coins < price:
			garage_title.text = "NEED %d MORE COINS FOR %s" % [price - coins, CAR_NAMES[index]]
			return
		coins -= price
		owned_cars.append(index)
	selected_car = index
	_apply_car_visual()
	coins_label.text = "COINS  %d" % coins
	_save_progress()
	_refresh_garage()

func _on_checkpoint_reached(reward: int) -> void:
	coins += reward
	coins_label.text = "COINS  %d" % coins
	status_label.text = "+%d  CHECKPOINT!" % reward
	_save_progress()

func _on_run_completed(reward: int) -> void:
	coins += reward
	coins_label.text = "COINS  %d" % coins
	status_label.text = "RUN COMPLETE! +%d COINS" % reward
	_save_progress()

func _recover_to_road() -> void:
	if not city_mode or city_map_data.is_empty():
		return
	var current := Vector2(car.position.x, car.position.z)
	var nearest_squared := INF
	var nearest_point := Vector2.ZERO
	var nearest_direction := Vector2(0.0, -1.0)
	for road in city_map_data.get("roads", []):
		if str(road.get("type", "")) == "service":
			continue
		var pts: Array = road.get("points", [])
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var delta := b - a
			if delta.length_squared() < 4.0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(current, a, b)
			var distance_squared := current.distance_squared_to(closest)
			if distance_squared < nearest_squared:
				nearest_squared = distance_squared
				nearest_point = closest
				nearest_direction = delta.normalized()
	if nearest_squared == INF:
		return
	var facing := Vector2(-sin(city_heading), -cos(city_heading))
	if facing.dot(nearest_direction) < 0.0:
		nearest_direction = -nearest_direction
	city_heading = atan2(-nearest_direction.x, -nearest_direction.y)
	car.position = Vector3(nearest_point.x, 0.67, nearest_point.y)
	car.rotation.y = city_heading
	city_velocity = 0.0
	speed = 0.0
	steering = 0.0
	steering_smoothed = 0.0
	accelerating = false
	braking = false
	reverse_gear = false
	gear_button.text = "GEAR: D"
	recovery_message_time = 2.0
	status_label.text = "BACK ON ROAD"

func _toggle_gear() -> void:
	if city_mode and absf(city_velocity) < 0.7:
		reverse_gear = not reverse_gear
		gear_button.text = "GEAR: R" if reverse_gear else "GEAR: D"

func _hud_button(parent: Control, title: String, anchor: Vector2, offset: Vector2, dimensions: Vector2) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.anchor_left = anchor.x
	btn.anchor_right = anchor.x
	btn.anchor_top = anchor.y
	btn.anchor_bottom = anchor.y
	btn.offset_left = offset.x
	btn.offset_top = offset.y
	btn.offset_right = offset.x + dimensions.x
	btn.offset_bottom = offset.y + dimensions.y
	btn.add_theme_font_size_override("font_size", 25)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.17, 0.85)
	style.border_color = Color(0.12, 0.72, 0.74, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	btn.add_theme_stylebox_override("normal", style)
	var active := style.duplicate() as StyleBoxFlat
	active.bg_color = Color(0.02, 0.50, 0.55, 0.95)
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("hover", active)
	parent.add_child(btn)
	return btn

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	score_label = Label.new()
	score_label.anchor_left = 0.0
	score_label.anchor_right = 0.0
	score_label.offset_left = 24
	score_label.offset_top = 18
	score_label.offset_right = 495
	score_label.offset_bottom = 104
	score_label.add_theme_font_size_override("font_size", 27)
	score_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	ui.add_child(score_label)

	mission_label = Label.new()
	mission_label.anchor_left = 0.5
	mission_label.anchor_right = 0.5
	mission_label.offset_left = -325
	mission_label.offset_top = 108
	mission_label.offset_right = 325
	mission_label.offset_bottom = 156
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.add_theme_font_size_override("font_size", 25)
	mission_label.add_theme_color_override("font_color", Color(0.23, 1.0, 0.87))
	mission_label.visible = false
	ui.add_child(mission_label)

	coins_label = Label.new()
	coins_label.anchor_left = 1.0
	coins_label.anchor_right = 1.0
	coins_label.offset_left = -235
	coins_label.offset_top = 85
	coins_label.offset_right = -22
	coins_label.offset_bottom = 129
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 26)
	coins_label.text = "COINS  %d" % coins
	coins_label.visible = false
	ui.add_child(coins_label)

	attribution_label = Label.new()
	attribution_label.anchor_left = 0.5
	attribution_label.anchor_right = 0.5
	attribution_label.anchor_top = 1.0
	attribution_label.anchor_bottom = 1.0
	attribution_label.offset_left = -260
	attribution_label.offset_right = 260
	attribution_label.offset_top = -25
	attribution_label.offset_bottom = -3
	attribution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attribution_label.text = "Map: © OpenStreetMap contributors (ODbL)"
	attribution_label.add_theme_font_size_override("font_size", 16)
	attribution_label.visible = false
	ui.add_child(attribution_label)

	status_label = Label.new()
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 0.5
	status_label.anchor_bottom = 0.5
	status_label.offset_left = -400
	status_label.offset_right = 400
	status_label.offset_top = -70
	status_label.offset_bottom = 10
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 31)
	status_label.add_theme_color_override("font_color", Color(0.12, 1.0, 0.83))
	ui.add_child(status_label)

	garage_button = _hud_button(ui, "GARAGE", Vector2(1, 0), Vector2(-574, 15), Vector2(146, 58))
	garage_button.add_theme_font_size_override("font_size", 22)
	garage_button.pressed.connect(_open_garage)
	music_button = _hud_button(ui, "MUSIC ON", Vector2(1, 0), Vector2(-420, 15), Vector2(132, 58))
	music_button.add_theme_font_size_override("font_size", 19)
	music_button.pressed.connect(func():
		music_enabled = not music_enabled
		music_button.text = "MUSIC ON" if music_enabled else "MUSIC OFF"
		if music_enabled and game_started and not crashed:
			music_player.play()
		else:
			music_player.stop()
	)
	sound_button = _hud_button(ui, "SOUND ON", Vector2(1, 0), Vector2(-280, 15), Vector2(130, 58))
	sound_button.add_theme_font_size_override("font_size", 19)
	sound_button.pressed.connect(func():
		sound_enabled = not sound_enabled
		sound_button.text = "SOUND ON" if sound_enabled else "SOUND OFF"
	)
	var restart := _hud_button(ui, "RESTART", Vector2(1, 0), Vector2(-142, 15), Vector2(130, 58))
	restart.add_theme_font_size_override("font_size", 20)
	restart.pressed.connect(func(): get_tree().reload_current_scene())

	var left := _hud_button(ui, "LEFT", Vector2(0, 1), Vector2(22, -135), Vector2(138, 105))
	left.button_down.connect(func(): steering = -1.0)
	left.button_up.connect(func(): steering = 0.0)
	var right := _hud_button(ui, "RIGHT", Vector2(0, 1), Vector2(170, -135), Vector2(138, 105))
	right.button_down.connect(func(): steering = 1.0)
	right.button_up.connect(func(): steering = 0.0)
	var brake := _hud_button(ui, "BRAKE", Vector2(1, 1), Vector2(-320, -135), Vector2(138, 105))
	brake.button_down.connect(func(): braking = true)
	brake.button_up.connect(func(): braking = false)
	var gas := _hud_button(ui, "GAS", Vector2(1, 1), Vector2(-170, -135), Vector2(148, 105))
	gas.button_down.connect(func(): accelerating = true)
	gas.button_up.connect(func(): accelerating = false)
	driving_buttons = [left, right, brake, gas]
	for btn in driving_buttons:
		btn.visible = false
	gear_button = _hud_button(ui, "GEAR: D", Vector2(1, 1), Vector2(-170, -210), Vector2(148, 62))
	gear_button.add_theme_font_size_override("font_size", 22)
	gear_button.visible = false
	gear_button.pressed.connect(_toggle_gear)
	road_reset_button = _hud_button(ui, "BACK TO ROAD", Vector2(1, 1), Vector2(-355, -210), Vector2(177, 62))
	road_reset_button.add_theme_font_size_override("font_size", 17)
	road_reset_button.visible = false
	road_reset_button.pressed.connect(_recover_to_road)
	var minimap_script := load("res://scripts/city_minimap.gd") as Script
	if minimap_script != null:
		city_minimap = Control.new()
		city_minimap.set_script(minimap_script)
		city_minimap.anchor_left = 1.0
		city_minimap.anchor_right = 1.0
		city_minimap.offset_left = -228.0
		city_minimap.offset_right = -24.0
		city_minimap.offset_top = 152.0
		city_minimap.offset_bottom = 352.0
		city_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		city_minimap.clip_contents = true
		city_minimap.visible = false
		ui.add_child(city_minimap)

	menu_panel = PanelContainer.new()
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -272
	menu_panel.offset_right = 272
	menu_panel.offset_top = -194
	menu_panel.offset_bottom = 194
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.04, 0.075, 0.12, 0.96)
	menu_style.border_color = Color(0.13, 0.84, 0.82, 0.9)
	menu_style.set_border_width_all(2)
	menu_style.set_corner_radius_all(20)
	menu_style.content_margin_left = 24
	menu_style.content_margin_right = 24
	menu_style.content_margin_top = 20
	menu_style.content_margin_bottom = 20
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	ui.add_child(menu_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 15)
	menu_panel.add_child(menu)
	var heading := Label.new()
	heading.text = "SHIFTWORLD 3D\nDRIVE THE WORLD"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.18, 0.98, 0.86))
	menu.add_child(heading)
	var city_available := FileAccess.file_exists("res://data/cities/manhattan.json")
	var city_button := Button.new()
	city_button.text = "MANHATTAN  -  FREE DRIVE"
	city_button.disabled = not city_available
	city_button.custom_minimum_size = Vector2(480, 90)
	city_button.add_theme_font_size_override("font_size", 24)
	menu.add_child(city_button)
	city_button.pressed.connect(_start_city_mode.bind(false))
	var mission_button := Button.new()
	mission_button.text = "MANHATTAN  -  CHECKPOINTS"
	mission_button.disabled = not city_available
	mission_button.custom_minimum_size = Vector2(480, 90)
	mission_button.add_theme_font_size_override("font_size", 24)
	menu.add_child(mission_button)
	mission_button.pressed.connect(_start_city_mode.bind(true))
	var caption := Label.new()
	caption.text = "SAME OPEN WORLD  |  DRIVE OR PLAY MISSIONS"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 17)
	menu.add_child(caption)

	garage_panel = PanelContainer.new()
	garage_panel.anchor_left = 0.5
	garage_panel.anchor_right = 0.5
	garage_panel.anchor_top = 0.5
	garage_panel.anchor_bottom = 0.5
	garage_panel.offset_left = -300
	garage_panel.offset_right = 300
	garage_panel.offset_top = -215
	garage_panel.offset_bottom = 215
	var garage_style := menu_style.duplicate() as StyleBoxFlat
	garage_panel.add_theme_stylebox_override("panel", garage_style)
	ui.add_child(garage_panel)
	var garage_layout := VBoxContainer.new()
	garage_layout.add_theme_constant_override("separation", 16)
	garage_panel.add_child(garage_layout)
	garage_title = Label.new()
	garage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	garage_title.add_theme_font_size_override("font_size", 28)
	garage_title.add_theme_color_override("font_color", Color(0.20, 0.95, 0.83))
	garage_layout.add_child(garage_title)
	var garage_hint := Label.new()
	garage_hint.text = "DRIVE 250m = +50 COINS  |  UNLOCK NEW CARS"
	garage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	garage_hint.add_theme_font_size_override("font_size", 18)
	garage_layout.add_child(garage_hint)
	for i in range(CAR_NAMES.size()):
		var option := Button.new()
		option.custom_minimum_size = Vector2(520, 62)
		option.add_theme_font_size_override("font_size", 22)
		option.pressed.connect(_choose_garage_car.bind(i))
		garage_layout.add_child(option)
		garage_buttons.append(option)
	var close_button := Button.new()
	close_button.text = "BACK  /  DRIVE"
	close_button.custom_minimum_size = Vector2(520, 64)
	close_button.add_theme_font_size_override("font_size", 23)
	garage_layout.add_child(close_button)
	close_button.pressed.connect(_close_garage)
	_refresh_garage()
	garage_panel.visible = false

func _physics_process(delta: float) -> void:
	if not city_mode or not game_started or crashed:
		return
	if garage_panel != null and garage_panel.visible:
		city_velocity = 0.0
		return
	var desired := 0.0
	if accelerating and not braking:
		desired = -5.5 if reverse_gear else 17.0
	var friction := 2.5 + absf(city_velocity) * 0.18
	var response := 23.0 if braking else (8.0 if accelerating else friction)
	city_velocity = move_toward(city_velocity, desired, response * delta)
	var velocity_magnitude := absf(city_velocity)
	steering_smoothed = move_toward(steering_smoothed, steering, delta * 4.0)
	var steering_ratio := minf(velocity_magnitude / 3.5, 1.0)
	var turn_rate := lerpf(0.92, 0.32, clampf(velocity_magnitude / 20.0, 0.0, 1.0))
	if velocity_magnitude > 0.1:
		city_heading -= steering_smoothed * signf(city_velocity) * steering_ratio * turn_rate * delta
	car.rotation.y = city_heading
	var forward := Vector3(-sin(city_heading), 0, -cos(city_heading))
	var from := car.position
	var hit := (car as CharacterBody3D).move_and_collide(forward * city_velocity * delta)
	if hit != null:
		city_velocity = 0.0
		collision_flash = 1.5
	var travelled := from.distance_to(car.position)
	distance += travelled
	_distance_reward(travelled)
	speed = absf(city_velocity)
	if collision_flash > 0.0:
		collision_flash -= delta
		status_label.text = "BUILDING COLLISION - CHANGE DIRECTION"
	elif status_label.text.begins_with("BUILDING COLLISION"):
		status_label.text = ""
	for wheel in wheels:
		wheel.rotate_x(city_velocity * delta * 1.7)

func _process(delta: float) -> void:
	if crashed or not game_started:
		return
	if city_mode:
		if recovery_message_time > 0.0:
			recovery_message_time -= delta
			if recovery_message_time <= 0.0:
				if status_label.text == "BACK ON ROAD" or status_label.text.contains("DISTANCE BONUS") or status_label.text.contains("STOP THE CAR"):
					status_label.text = ""
		var behind := car.position + Vector3(sin(city_heading) * 11.5, 4.7, cos(city_heading) * 11.5)
		camera.position = camera.position.lerp(behind, minf(delta * 4.5, 1.0))
		camera.look_at(car.position + Vector3(0, 1.1, 0), Vector3.UP)
		var map_target := Vector3.ZERO
		var map_target_visible := false
		if city_challenge != null:
			city_challenge.call("update_car_position", car.position, speed)
			mission_label.text = str(city_challenge.call("guidance", car.position, city_heading))
			var index: int = int(city_challenge.get("active_index"))
			var targets: Array = city_challenge.get("checkpoints")
			if bool(city_challenge.get("running")) and index >= 0 and index < targets.size():
				map_target = targets[index]
				map_target_visible = true
		else:
			mission_label.text = "FREE DRIVE  |  EXPLORE MANHATTAN"
		minimap_refresh_time -= delta
		if city_minimap != null and minimap_refresh_time <= 0.0:
			city_minimap.call("follow", car.position, city_heading, map_target, map_target_visible)
			minimap_refresh_time = 0.12
		var remaining := maxi(1, int(ceil(float(last_distance_milestone + 1) * 250.0 - total_distance)))
		score_label.text = "MANHATTAN  |  %d km/h\nTRIP %dm  |  +50 COINS IN %dm" % [int(speed * 3.6), int(distance), remaining]
		return
	var target_speed: float = [0.0, 0.0, 0.0][difficulty]
	if accelerating:
		target_speed = [5.5, 9.0, 14.0][difficulty]
	if braking:
		target_speed = MIN_SPEED
	speed = move_toward(speed, target_speed, (24.0 if braking else 9.0) * delta)
	distance += speed * delta
	# This milestone still uses scrolling scenery; full world-space driving comes next.
	if not city_mode:
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
