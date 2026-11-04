extends SceneTree
# Offline renderer smoke test. No Android build or GLB assets required.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	print("MANHATTAN_RENDER_TEST: PASS | windows: ", windows, " | batched meshes: ", world.get_child_count())
	quit(0)

func _fail(message: String) -> void:
	push_error("MANHATTAN_RENDER_TEST: FAIL | " + message)
	quit(1)
