extends SceneTree
# Offline renderer smoke test. No Android build or GLB assets required.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_script: Script = load("res://scripts/game.gd") as Script
	if game_script == null:
		_fail("Main driving game script did not parse")
		return
	var script: Script = load("res://scripts/city_world.gd") as Script
	if script == null:
		_fail("City script did not load")
		return
	var city: Node3D = script.new() as Node3D
	if city == null:
		_fail("City script did not instantiate")
		return
	root.add_child(city)
	if not bool(city.call("load_city", "manhattan")):
		_fail("Manhattan JSON could not be rendered")
		return
	var world: Node3D = city.get_node_or_null("OfflineCity") as Node3D
	if world == null:
		_fail("OfflineCity node is missing")
		return
	for node_name in ["Roads", "Sidewalks", "LaneMarks", "BuildingWalls0", "Roofs", "FacadeWindows"]:
		var node: MeshInstance3D = world.get_node_or_null(node_name) as MeshInstance3D
		if node == null or node.mesh == null or node.mesh.get_surface_count() == 0:
			_fail("Missing mesh: " + node_name)
			return
	var windows: int = int(city.get("window_count"))
	if windows < 100:
		_fail("Expected at least 100 generated facade windows, got " + str(windows))
		return
	# Exercise the actual main scene and the button's city-mode startup,
	# not only an isolated renderer.
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Main scene not available")
		return
	var game: Node3D = scene.instantiate() as Node3D
	root.add_child(game)
	game.call("_start_city_mode")
	if not bool(game.get("city_mode")):
		_fail("Main menu could not enter Manhattan city mode")
		return
	var player: CharacterBody3D = game.get("car") as CharacterBody3D
	if player == null:
		_fail("Player car must have a CharacterBody3D collider")
		return
	var challenge: Node3D = game.get("city_challenge") as Node3D
	if challenge == null:
		_fail("Manhattan challenge did not initialize")
		return
	var goals: Array = challenge.get("checkpoints")
	if goals.size() != 3:
		_fail("Expected 3 OSM-road challenge checkpoints, got " + str(goals.size()))
		return
	var driving_label: Label = game.get("mission_label") as Label
	if driving_label == null or not driving_label.visible:
		_fail("Challenge HUD did not appear")
		return
	var new_city: Node3D = game.get("city_world") as Node3D
	if new_city.get_node_or_null("OfflineCity/NearbyBuildingCollision") == null:
		_fail("Building physics mesh missing")
		return
	print("MANHATTAN_RENDER_TEST: PASS | windows: ", windows, " | batched meshes: ", world.get_child_count())
	print("SHIFTWORLD_DRIVE_V2_TEST: PASS | checkpoints: ", goals.size(), " | physics car + city collision + landscape HUD")
	quit(0)

func _fail(message: String) -> void:
	push_error("MANHATTAN_RENDER_TEST: FAIL | " + message)
	quit(1)
