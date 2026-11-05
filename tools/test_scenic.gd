extends SceneTree
# Offline smoketest for the selected scenic water-garden driving scene.
# Does not alter the user's actual garage / wallet save.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenic_script := load("res://scripts/scenic_world.gd") as Script
	if scenic_script == null:
		_fail("Scenic garden script failed to parse")
		return
	var scenery := Node3D.new()
	scenery.set_script(scenic_script)
	root.add_child(scenery)
	scenery.call("build")
	for mesh_name in ["ScenicRoad", "ScenicLakes", "FloatingLilyPads", "LotusPetals",
			"LeafyTreeCanopies", "PinkFlowerTrees", "FlowerGardenBushes",
			"TieredWaterfall", "RoadsideMarkerPosts"]:
		var model := scenery.get_node_or_null(mesh_name) as MeshInstance3D
		if model == null or model.mesh == null or model.mesh.get_surface_count() == 0:
			_fail("Scenic garden missing geometry: " + mesh_name)
			return
	if bool(scenery.call("is_in_water", Vector3(0.0,0.67,-50.0))):
		_fail("Scenic driving lane must stay dry")
		return
	if not bool(scenery.call("is_in_water", Vector3(40.0,0.67,-50.0))):
		_fail("Scenic lake needs working fine detection")
		return
	var flower_count := int(scenery.get("flower_count"))
	var tree_count := int(scenery.get("tree_count"))
	if flower_count < 100 or tree_count < 50:
		_fail("Scenic foliage is too sparse")
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main driving scene is unavailable")
		return
	var game := packed.instantiate() as Node3D
	game.set("test_no_save",true)
	root.add_child(game)
	game.call("_start_scenic_mode")
	if not bool(game.get("city_mode")) or not bool(game.get("scenic_mode")):
		_fail("Garden driving mode failed to start")
		return
	var car := game.get("car") as CharacterBody3D
	if car == null or car.position.z < 10.0:
		_fail("Garden car did not spawn on the road")
		return
	var mini := game.get("city_minimap") as Control
	if mini == null or not mini.visible:
		_fail("Garden minimap not visible")
		return
	var garden := game.get("wetland_world") as Node3D
	if garden == null:
		_fail("Garden water not connected to driving fines")
		return
	game.set("coins", 160)
	car.position = Vector3(40.0,0.67,-50.0)
	game.call("_check_water_fine")
	if int(game.get("coins")) != 110:
		_fail("Lake entry must cost exactly 50 coins")
		return
	game.call("_check_water_fine")
	if int(game.get("coins")) != 110:
		_fail("Water charge must not repeat while parked in water")
		return
	game.call("_recover_to_road")
	if absf(car.position.x) > 5.0:
		_fail("Back to Road must return to scenic roadway")
		return
	if bool(garden.call("is_in_water",car.position)):
		_fail("Recovered scenic car remains in water")
		return
	print("SHIFTWORLD_SCENIC_TEST: PASS | lotus: ",flower_count," trees: ",tree_count," | free-drive route, lakes, waterfall, fines and recovery")
	quit(0)

func _fail(message: String) -> void:
	push_error("SHIFTWORLD_SCENIC_TEST: FAIL | "+message)
	quit(1)
