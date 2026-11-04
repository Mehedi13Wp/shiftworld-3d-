extends Node3D
# Optional OSM-based city renderer. Does not replace the working highway scene.
# Road geometry is based on real OSM coordinates, not Google Maps imagery.
const MAP_ROOT := "res://data/cities/"
const ROAD_COLORS := {"primary":Color(0.22,0.23,0.24),"secondary":Color(0.25,0.26,0.27),"residential":Color(0.28,0.29,0.30)}
var city_root: Node3D

func load_city(city_id: String) -> bool:
	var path := MAP_ROOT + city_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("City map not installed: " + path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not data.has("roads"):
		push_error("Invalid city map")
		return false
	if city_root != null:
		city_root.queue_free()
	city_root = Node3D.new()
	add_child(city_root)
	_add_ground()
	for road in data["roads"]:
		var pts: Array = road.get("points", [])
		for i in range(pts.size()-1):
			var a := Vector3(float(pts[i][0]),0.02,float(pts[i][1]))
			var b := Vector3(float(pts[i+1][0]),0.02,float(pts[i+1][1]))
			_add_road_segment(a,b,str(road.get("type","residential")))
	# Limit visible geometry for entry-level Android GPUs; nearest buildings first.
	var buildings: Array = data.get("buildings", [])
	buildings.sort_custom(func(a, b):
		var pa: Array = a.get("points", [])
		var pb: Array = b.get("points", [])
		if pa.is_empty() or pb.is_empty():
			return false
		var da: float = float(pa[0][0]) * float(pa[0][0]) + float(pa[0][1]) * float(pa[0][1])
		var db: float = float(pb[0][0]) * float(pb[0][0]) + float(pb[0][1]) * float(pb[0][1])
		return da < db
	)
	for i in range(mini(buildings.size(), 550)):
		_add_building(buildings[i])
	return true

func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1600.0,1600.0)
	ground.mesh = mesh
	ground.position.y = -0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30,0.36,0.29)
	material.roughness = 1.0
	ground.material_override = material
	city_root.add_child(ground)

func _add_road_segment(a: Vector3,b: Vector3,road_type: String) -> void:
	var length := a.distance_to(b)
	if length < 0.1:
		return
	var width := 8.0 if road_type in ["primary","secondary","trunk"] else 5.5
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,0.12,length)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = (a+b)*0.5
	instance.rotation.y = atan2(b.x-a.x,b.z-a.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROAD_COLORS.get(road_type,Color(0.28,0.29,0.30))
	mat.roughness = 0.94
	instance.material_override = mat
	city_root.add_child(instance)

func _add_building(building: Dictionary) -> void:
	var points: Array = building.get("points",[])
	if points.size() < 4:
		return
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for point in points:
		min_x = minf(min_x,float(point[0]))
		max_x = maxf(max_x,float(point[0]))
		min_z = minf(min_z,float(point[1]))
		max_z = maxf(max_z,float(point[1]))
	var height := float(building.get("height",11.0))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(1.0,max_x-min_x),height,maxf(1.0,max_z-min_z))
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3((min_x+max_x)*0.5,height*0.5,(min_z+max_z)*0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62,0.64,0.66)
	mat.roughness = 0.88
	instance.material_override = mat
	city_root.add_child(instance)
