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
var glass_material: StandardMaterial3D
var window_count := 0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m

func _setup_materials() -> void:
	road_material = _mat(Color(0.82, 0.84, 0.87))
	var asphalt_noise := FastNoiseLite.new()
	asphalt_noise.seed = 53109
	asphalt_noise.frequency = 0.09
	asphalt_noise.fractal_octaves = 3
	var asphalt_texture := NoiseTexture2D.new()
	asphalt_texture.width = 256
	asphalt_texture.height = 256
	asphalt_texture.seamless = true
	asphalt_texture.noise = asphalt_noise
	var tones := Gradient.new()
	tones.set_color(0, Color(0.095, 0.105, 0.115))
	tones.set_color(1, Color(0.235, 0.245, 0.255))
	asphalt_texture.color_ramp = tones
	road_material.albedo_texture = asphalt_texture
	# Real XY-on-ground UVs use one texture sample, faster than triplanar on Android.
	road_material.uv1_triplanar = false
	road_material.uv1_scale = Vector3.ONE
	road_material.roughness = 0.97
	sidewalk_material = _mat(Color(0.52, 0.53, 0.52))
	lane_material = _mat(Color(0.92, 0.89, 0.72))
	roof_material = _mat(Color(0.38, 0.40, 0.43))
	# Times Square is urban, not a giant grassy field between road meshes.
	ground_material = _mat(Color(0.33, 0.34, 0.33))
	glass_material = _mat(Color(0.12, 0.21, 0.29))
	glass_material.metallic = 0.18
	glass_material.roughness = 0.30
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
	var curb_st := SurfaceTool.new()
	curb_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crossings := SurfaceTool.new()
	crossings.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	sidewalk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	lane_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road in data["roads"]:
		var pts: Array = road.get("points", [])
		var road_type := str(road.get("type", "residential"))
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			_add_road(road_st, sidewalk_st, lane_st, curb_st, a, b, road_type)
			if i == 0 and str(road.get("name", "")) != "":
				_add_crosswalk(crossings, a, b, road_type)
	_commit(road_st, road_material, "Roads")
	_commit(sidewalk_st, sidewalk_material, "Sidewalks")
	_commit(lane_st, lane_material, "LaneMarks")
	_commit(curb_st, _mat(Color(0.72, 0.73, 0.71)), "RoadCurbs")
	_commit(crossings, _mat(Color(0.90, 0.93, 0.91)), "ZebraCrosswalks")
	# Batch buildings by facade color to avoid thousands of individual draw calls.
	var walls: Array[SurfaceTool] = []
	for i in range(wall_materials.size()):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		walls.append(st)
	var roofs := SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var storefront := SurfaceTool.new()
	storefront.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shop_signs := SurfaceTool.new()
	shop_signs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_walls := SurfaceTool.new()
	collision_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	window_count = 0
	# OSM ordering is arbitrary. Prioritize buildings around Times Square/spawn.
	var buildings: Array = data.get("buildings", [])
	buildings.sort_custom(func(a, b):
		var pa: Array = a.get("points", [])
		var pb: Array = b.get("points", [])
		if pa.is_empty():
			return false
		if pb.is_empty():
			return true
		var ax: float = float(pa[0][0])
		var az: float = float(pa[0][1])
		var bx: float = float(pb[0][0])
		var bz: float = float(pb[0][1])
		return ax * ax + az * az < bx * bx + bz * bz
	)
	var count := 0
	for building in buildings:
		if _add_building(walls, roofs, glass, storefront, shop_signs, collision_walls, building):
			count += 1
			if count >= 650:
				break
	for i in range(walls.size()):
		_commit(walls[i], wall_materials[i], "BuildingWalls" + str(i))
	_commit(roofs, roof_material, "Roofs")
	_commit(glass, glass_material, "FacadeWindows")
	_commit(storefront, _mat(Color(0.075, 0.16, 0.20)), "GroundFloorShopWindows")
	_commit(shop_signs, _mat(Color(0.23, 0.36, 0.43)), "StorefrontSignBands")
	var details_script := load("res://scripts/city_decor.gd") as Script
	if details_script != null:
		var details := Node3D.new()
		details.name = "StreetDetails"
		details.set_script(details_script)
		city_root.add_child(details)
		details.call("build", data)
	# Fill off-road vacant terrain with stylized water gardens, without
	# flooding the OSM street network or building footprint areas.
	var wetlands_script := load("res://scripts/city_wetlands.gd") as Script
	if wetlands_script != null:
		var wetlands := Node3D.new()
		wetlands.name = "Wetlands"
		wetlands.set_script(wetlands_script)
		city_root.add_child(wetlands)
		wetlands.call("build", data)
	# Static building collision near the playable challenge area.
	# One combined concave mesh is substantially cheaper than hundreds of bodies.
	var collision_mesh := collision_walls.commit()
	if collision_mesh != null and collision_mesh.get_surface_count() > 0:
		var static_body := StaticBody3D.new()
		static_body.name = "NearbyBuildingCollision"
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = collision_mesh.create_trimesh_shape()
		static_body.add_child(collision_shape)
		city_root.add_child(static_body)
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
	plane.size = Vector2(3200, 3200)
	ground.mesh = plane
	ground.position.y = -0.12
	ground.material_override = ground_material
	city_root.add_child(ground)

func _add_road(roads: SurfaceTool, sidewalks: SurfaceTool, lanes: SurfaceTool, curbs: SurfaceTool, a: Vector2, b: Vector2, kind: String) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.8:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var width := 9.0 if kind in ["primary","secondary","trunk"] else 6.0
	if kind == "service":
		width = 4.0
	_road_surface(roads, a, b, normal, width * 0.5, 0.03)
	# Sidewalk strips stay outside the road so they do not hide the asphalt.
	if kind != "service":
		for side in [-1.0, 1.0]:
			var offset: Vector2 = normal * float(side) * (width * 0.5 + 0.85)
			_strip(sidewalks, a + offset, b + offset, normal, 0.85, 0.085)
			var curb_offset: Vector2 = normal * float(side) * (width * 0.5 + 0.08)
			_strip(curbs, a + curb_offset, b + curb_offset, normal, 0.065, 0.095)
		var dash_count := int(length / 9.0)
		for i in range(dash_count):
			var start := a + direction * (float(i) * 9.0 + 2.0)
			var finish := start + direction * minf(3.0, length - float(i) * 9.0 - 2.0)
			_strip(lanes, start, finish, normal, 0.085, 0.065)

func _add_crosswalk(st: SurfaceTool, a: Vector2, b: Vector2, road_type: String) -> void:
	if a.length_squared() > 380.0 * 380.0 or road_type == "service":
		return
	var delta := b - a
	var length := delta.length()
	if length < 13.0:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var width := 9.0 if road_type in ["primary", "secondary", "trunk"] else 6.0
	for i in range(6):
		var center := a + direction * (2.7 + float(i) * 0.86)
		_strip(st, center - direction * 0.25, center + direction * 0.25, normal, width * 0.43, 0.073)

func _road_surface(st: SurfaceTool, a: Vector2, b: Vector2, normal: Vector2, half_width: float, y: float) -> void:
	var off := normal * half_width
	var corners: Array[Vector3] = [
		Vector3(a.x-off.x, y, a.y-off.y),
		Vector3(b.x-off.x, y, b.y-off.y),
		Vector3(b.x+off.x, y, b.y+off.y),
		Vector3(a.x+off.x, y, a.y+off.y)
	]
	for index in [0, 1, 2, 0, 2, 3, 2, 1, 0, 3, 2, 0]:
		var point: Vector3 = corners[index]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(point.x, point.z) * 0.22)
		st.add_vertex(point)

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

func _add_facade_windows(glass: SurfaceTool, a: Vector2, b: Vector2, height: float, signed_area: float, window_quota: int) -> void:
	if window_count >= 20000 or height < 7.0 or window_quota <= 0:
		return
	var edge := b - a
	var length := edge.length()
	if length < 5.0:
		return
	var forward := edge / length
	var outward := Vector2(forward.y, -forward.x) * (1.0 if signed_area > 0.0 else -1.0)
	var floors := mini(int(height / 3.8), 23)
	var max_columns := maxi(1, int(length / 3.0))
	if floors <= 1:
		return
	# Spread a limited number of windows across the entire facade instead
	# of exhausting the mobile GPU vertex budget on the first tall building.
	var rows := mini(floors - 1, maxi(1, int(sqrt(float(window_quota)))))
	var columns := mini(max_columns, maxi(1, int(ceil(float(window_quota) / float(rows)))))
	for row_index in range(rows):
		var floor_index := 1 + int(float(row_index) * float(floors - 1) / float(rows))
		var bottom := float(floor_index) * 3.8 + 0.15
		var top := minf(bottom + 1.85, height - 0.25)
		if top <= bottom:
			continue
		for i in range(columns):
			if window_count >= 20000:
				return
			var t := float(i + 1) * length / float(columns + 1)
			var half_width := minf(0.80, length / float(columns + 1) * 0.30)
			var left := a + forward * (t - half_width) + outward * 0.07
			var right := a + forward * (t + half_width) + outward * 0.07
			_quad(glass, Vector3(left.x,bottom,left.y), Vector3(right.x,bottom,right.y), Vector3(right.x,top,right.y), Vector3(left.x,top,left.y))
			window_count += 1

func _add_building(walls: Array[SurfaceTool], roofs: SurfaceTool, glass: SurfaceTool, storefront: SurfaceTool, shop_signs: SurfaceTool, collision_walls: SurfaceTool, building: Dictionary) -> bool:
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
	var facade_area := _polygon_area(outline)
	var building_center := Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
	var show_windows := building_center.length_squared() < 550.0 * 550.0
	var needs_collision := building_center.length_squared() < 320.0 * 320.0
	var needs_stores := building_center.length_squared() < 260.0 * 260.0
	var distance_to_center := building_center.length()
	var window_budget := 60 if distance_to_center < 200.0 else (40 if distance_to_center < 350.0 else 20)
	var per_wall_budget := maxi(1, int(ceil(float(window_budget) / float(outline.size()))))
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1) % outline.size()]
		_quad(facade, Vector3(a.x,0,a.y), Vector3(b.x,0,b.y), Vector3(b.x,height,b.y), Vector3(a.x,height,a.y))
		if needs_collision:
			_quad(collision_walls, Vector3(a.x,0,a.y), Vector3(b.x,0,b.y), Vector3(b.x,height,b.y), Vector3(a.x,height,a.y))
		if show_windows:
			_add_facade_windows(glass, a, b, height, facade_area, per_wall_budget)
		if needs_stores and height >= 6.0:
			var edge := b - a
			var edge_length := edge.length()
			if edge_length > 7.5:
				var direction := edge / edge_length
				var facing := Vector2(direction.y, -direction.x) * (1.0 if facade_area > 0.0 else -1.0)
				var center := (a + b) * 0.5 + facing * 0.09
				var span := minf(edge_length - 1.5, 17.0)
				var left := center - direction * span * 0.5
				var right := center + direction * span * 0.5
				_quad(storefront, Vector3(left.x, 0.55, left.y), Vector3(right.x, 0.55, right.y), Vector3(right.x, 2.9, right.y), Vector3(left.x, 2.9, left.y))
				_quad(shop_signs, Vector3(left.x, 3.0, left.y), Vector3(right.x, 3.0, right.y), Vector3(right.x, 3.55, right.y), Vector3(left.x, 3.55, left.y))
	for i in range(0,indices.size(),3):
		var a := outline[indices[i]]
		var b := outline[indices[i+1]]
		var c := outline[indices[i+2]]
		_tri(roofs, Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(c.x,height,c.y))
		_tri(roofs, Vector3(c.x,height,c.y),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y))
	return true
