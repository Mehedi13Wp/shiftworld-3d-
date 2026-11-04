extends Node3D
# SHIFTWORLD: offline OpenStreetMap geometry, lightweight Godot GL renderer.
# © OpenStreetMap contributors, ODbL. Geometry is approximate.
const MAP_ROOT := "res://data/cities/"
var city_root: Node3D
var road_material: StandardMaterial3D
var sidewalk_material: StandardMaterial3D
var lane_material: StandardMaterial3D
var wall_materials: Array[StandardMaterial3D] = []
var roof_material: StandardMaterial3D
var ground_material: StandardMaterial3D

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m

func _setup_materials() -> void:
	road_material = _mat(Color(0.15, 0.17, 0.19))
	sidewalk_material = _mat(Color(0.52, 0.53, 0.52))
	lane_material = _mat(Color(0.92, 0.89, 0.72))
	roof_material = _mat(Color(0.38, 0.40, 0.43))
	ground_material = _mat(Color(0.25, 0.34, 0.27))
	wall_materials.clear()
	for c in [Color(0.65,0.67,0.68), Color(0.72,0.67,0.60), Color(0.59,0.62,0.65), Color(0.69,0.64,0.59)]:
		wall_materials.append(_mat(c))

func load_city(city_id: String) -> bool:
	var path := MAP_ROOT + city_id + ".json"
	if not FileAccess.file_exists(path):
		push_error("City map missing: " + path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not data.has("roads"):
		return false
	if city_root != null:
		city_root.queue_free()
	city_root = Node3D.new()
	city_root.name = "OfflineCity"
	add_child(city_root)
	_setup_materials()
	_add_ground()
	var road_st := SurfaceTool.new()
	var sidewalk_st := SurfaceTool.new()
	var lane_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	sidewalk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	lane_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road in data["roads"]:
		var pts: Array = road.get("points", [])
		var road_type := str(road.get("type", "residential"))
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			_add_road(road_st, sidewalk_st, lane_st, a, b, road_type)
	_commit(road_st, road_material, "Roads")
	_commit(sidewalk_st, sidewalk_material, "Sidewalks")
	_commit(lane_st, lane_material, "LaneMarks")
	# Batch buildings by facade color to avoid thousands of individual draw calls.
	var walls: Array[SurfaceTool] = []
	for i in range(wall_materials.size()):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		walls.append(st)
	var roofs := SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for building in data.get("buildings", []):
		if _add_building(walls, roofs, building):
			count += 1
			if count >= 650:
				break
	for i in range(walls.size()):
		_commit(walls[i], wall_materials[i], "BuildingWalls" + str(i))
	_commit(roofs, roof_material, "Roofs")
	return true

func _commit(st: SurfaceTool, material: StandardMaterial3D, node_name: String) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	city_root.add_child(instance)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)
	# Double sided geometry for mobile GL compatibility.
	_tri(st, c, b, a)
	_tri(st, d, c, a)

func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1800)
	ground.mesh = plane
	ground.position.y = -0.12
	ground.material_override = ground_material
	city_root.add_child(ground)

func _add_road(roads: SurfaceTool, sidewalks: SurfaceTool, lanes: SurfaceTool, a: Vector2, b: Vector2, kind: String) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.8:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var width := 9.0 if kind in ["primary","secondary","trunk"] else 6.0
	if kind == "service":
		width = 4.0
	_strip(roads, a, b, normal, width * 0.5, 0.03)
	# Sidewalk strips stay outside the road so they do not hide the asphalt.
	if kind != "service":
		for side in [-1.0, 1.0]:
			var offset: Vector2 = normal * float(side) * (width * 0.5 + 0.85)
			_strip(sidewalks, a + offset, b + offset, normal, 0.85, 0.085)
		var dash_count := int(length / 9.0)
		for i in range(dash_count):
			var start := a + direction * (float(i) * 9.0 + 2.0)
			var finish := start + direction * minf(3.0, length - float(i) * 9.0 - 2.0)
			_strip(lanes, start, finish, normal, 0.085, 0.065)

func _strip(st: SurfaceTool, a: Vector2, b: Vector2, normal: Vector2, half_width: float, y: float) -> void:
	var off := normal * half_width
	_quad(st, Vector3(a.x-off.x,y,a.y-off.y), Vector3(b.x-off.x,y,b.y-off.y), Vector3(b.x+off.x,y,b.y+off.y), Vector3(a.x+off.x,y,a.y+off.y))

func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5

func _add_building(walls: Array[SurfaceTool], roofs: SurfaceTool, building: Dictionary) -> bool:
	var raw: Array = building.get("points", [])
	if raw.size() < 4:
		return false
	var outline := PackedVector2Array()
	for p in raw:
		var point := Vector2(float(p[0]),float(p[1]))
		if outline.is_empty() or outline[outline.size()-1].distance_to(point) > 0.15:
			outline.append(point)
	if outline.size() > 2 and outline[0].distance_to(outline[outline.size()-1]) < 0.15:
		outline.remove_at(outline.size()-1)
	if outline.size() < 3 or outline.size() > 120:
		return false
	if absf(_polygon_area(outline)) < 8.0:
		return false
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in outline:
		min_x = minf(min_x,p.x)
		max_x = maxf(max_x,p.x)
		min_z = minf(min_z,p.y)
		max_z = maxf(max_z,p.y)
	if max_x-min_x > 110.0 or max_z-min_z > 110.0:
		return false
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		return false
	var height := clampf(float(building.get("height", 11.0)), 4.0, 90.0)
	var facade: SurfaceTool = walls[int(building.get("id",0)) % walls.size()]
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1) % outline.size()]
		_quad(facade, Vector3(a.x,0,a.y), Vector3(b.x,0,b.y), Vector3(b.x,height,b.y), Vector3(a.x,height,a.y))
	for i in range(0,indices.size(),3):
		var a := outline[indices[i]]
		var b := outline[indices[i+1]]
		var c := outline[indices[i+2]]
		_tri(roofs, Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(c.x,height,c.y))
		_tri(roofs, Vector3(c.x,height,c.y),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y))
	return true
