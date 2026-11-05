extends Node3D
# SHIFTWORLD: stylized decorative wetlands only in vacant terrain.
# All foliage, lotus flowers and water are procedural; no external assets.
# Water never intentionally covers mapped road segments or building bounding boxes.
const GRID_STEP := 112.0
const GRID_LIMIT := 1456.0
const MIN_RADIUS := 23.0
const MAX_RADIUS := 76.0
const WATER_HEIGHT := 0.025

var ponds: Array[Vector3] = [] # x, z, radius (world metres)
var flower_count := 0
var plant_count := 0

func _mat(c: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _v(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, p.y)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)

func _commit(st: SurfaceTool, name: String, mat: StandardMaterial3D) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = mat
	add_child(node)

func _surface_disk(st: SurfaceTool, center: Vector2, radius: float, height: float, sides: int, phase: float) -> void:
	for i in range(sides):
		var a := TAU * float(i) / float(sides) + phase
		var b := TAU * float(i + 1) / float(sides) + phase
		var edge_a := center + Vector2(cos(a), sin(a)) * radius
		var edge_b := center + Vector2(cos(b), sin(b)) * radius
		_tri(st, _v(center, height), _v(edge_a, height), _v(edge_b, height))

func _lotus(pink: SurfaceTool, yellow: SurfaceTool, where: Vector2, scale: float) -> void:
	# Eight curved pink petals stand above a yellow heart.
	var y := WATER_HEIGHT + 0.14
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var direction := Vector2(cos(a), sin(a))
		var sideways := Vector2(-direction.y, direction.x)
		_tri(pink,
			_v(where + sideways * 0.20 * scale, y),
			_v(where - sideways * 0.20 * scale, y),
			_v(where + direction * 0.88 * scale, y + 0.47 * scale))
	_surface_disk(yellow, where, 0.18 * scale, y + 0.09, 8, 0.0)
	flower_count += 1

func _leaf(st: SurfaceTool, p: Vector2, direction: Vector2, scale: float, h: float) -> void:
	var side := Vector2(-direction.y, direction.x)
	_tri(st,
		_v(p - direction * 0.35 * scale, h),
		_v(p + direction * 0.24 * scale + side * 0.33 * scale, h),
		_v(p + direction * 0.75 * scale, h + 0.13 * scale))
	_tri(st,
		_v(p - direction * 0.35 * scale, h),
		_v(p + direction * 0.75 * scale, h + 0.13 * scale),
		_v(p + direction * 0.24 * scale - side * 0.33 * scale, h))

func _distance_to_road(p: Vector2, segments: Array) -> float:
	var clearance := MAX_RADIUS + 12.0
	for segment in segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		# Reject distant segments before running projection maths.
		if p.x < minf(a.x,b.x)-90.0 or p.x > maxf(a.x,b.x)+90.0:
			continue
		if p.y < minf(a.y,b.y)-90.0 or p.y > maxf(a.y,b.y)+90.0:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		clearance = minf(clearance, p.distance_to(closest) - 11.0)
		if clearance < MIN_RADIUS:
			return clearance
	return clearance

func _distance_to_building(p: Vector2, bounds: Array) -> float:
	var clearance := MAX_RADIUS + 12.0
	for rect in bounds:
		var box: Rect2 = rect
		if p.x < box.position.x - 90.0 or p.x > box.end.x + 90.0:
			continue
		if p.y < box.position.y - 90.0 or p.y > box.end.y + 90.0:
			continue
		var nearest := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))
		clearance = minf(clearance, p.distance_to(nearest) - 8.0)
		if clearance < MIN_RADIUS:
			return clearance
	return clearance

func build(data: Dictionary) -> void:
	ponds.clear()
	flower_count = 0
	plant_count = 0
	var segments: Array = []
	var bounds: Array = []
	for road in data.get("roads", []):
		var pts: Array = road.get("points", [])
		for k in range(pts.size() - 1):
			var a := Vector2(float(pts[k][0]), float(pts[k][1]))
			var b := Vector2(float(pts[k+1][0]), float(pts[k+1][1]))
			if a.distance_squared_to(b) > 1.0:
				segments.append([a, b])
	for building in data.get("buildings", []):
		var outline: Array = building.get("points", [])
		if outline.size() < 3:
			continue
		var min_x := INF
		var max_x := -INF
		var min_y := INF
		var max_y := -INF
		for raw in outline:
			var x := float(raw[0])
			var y := float(raw[1])
			min_x = minf(min_x, x)
			max_x = maxf(max_x, x)
			min_y = minf(min_y, y)
			max_y = maxf(max_y, y)
		bounds.append(Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y)))

	var water := SurfaceTool.new()
	var banks := SurfaceTool.new()
	var lilypads := SurfaceTool.new()
	var vines := SurfaceTool.new()
	var lotuses := SurfaceTool.new()
	var lotus_centers := SurfaceTool.new()
	var shore_reeds := SurfaceTool.new()
	for st in [water, banks, lilypads, vines, lotuses, lotus_centers, shore_reeds]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Seeded randomness keeps the same plants at the same map coordinates.
	var rng := RandomNumberGenerator.new()
	rng.seed = 841592
	var row_count := int(GRID_LIMIT * 2.0 / GRID_STEP)
	for ix in range(row_count + 1):
		for iz in range(row_count + 1):
			var p := Vector2(-GRID_LIMIT + float(ix) * GRID_STEP, -GRID_LIMIT + float(iz) * GRID_STEP)
			p += Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
			# The spawn and city streets must always remain dry.
			if p.length_squared() < 110.0 * 110.0:
				continue
			var radius := minf(_distance_to_road(p, segments), _distance_to_building(p, bounds))
			radius = minf(radius, MAX_RADIUS)
			if radius < MIN_RADIUS:
				continue
			ponds.append(Vector3(p.x, p.y, radius))
			var sides := 14
			_surface_disk(water, p, radius, WATER_HEIGHT, sides, 0.0)
			# Narrow vegetated shoreline around the water.
			for i in range(sides):
				var a := TAU * float(i) / float(sides)
				var b := TAU * float(i+1) / float(sides)
				var inner_a := p + Vector2(cos(a), sin(a)) * (radius - 1.1)
				var inner_b := p + Vector2(cos(b), sin(b)) * (radius - 1.1)
				var outer_a := p + Vector2(cos(a), sin(a)) * radius
				var outer_b := p + Vector2(cos(b), sin(b)) * radius
				_quad(banks, _v(inner_a, WATER_HEIGHT + 0.015), _v(inner_b, WATER_HEIGHT + 0.015), _v(outer_b, WATER_HEIGHT + 0.095), _v(outer_a, WATER_HEIGHT + 0.095))
			# Upright wetland grasses make the bank visible from a driving camera.
			if (ix + iz) % 4 == 1:
				for blade in range(4):
					var angle := rng.randf() * TAU
					var stalk := p + Vector2(cos(angle), sin(angle)) * (radius - 2.8)
					var height := rng.randf_range(0.9, 2.5)
					var stalk_left := stalk + Vector2(-0.11, 0)
					var stalk_right := stalk + Vector2(0.11, 0)
					_quad(shore_reeds, _v(stalk_left, WATER_HEIGHT + 0.08), _v(stalk_right, WATER_HEIGHT + 0.08), _v(stalk_right, height), _v(stalk_left, height))
			# Put decorative plants in a controlled fraction of patches for mobile FPS.
			if (ix + iz) % 3 != 0:
				continue
			for n in range(5):
				var theta := rng.randf() * TAU
				var distance := sqrt(rng.randf()) * maxf(1.0, radius - 8.0)
				var where := p + Vector2(cos(theta), sin(theta)) * distance
				var size := rng.randf_range(0.9, 1.9)
				_surface_disk(lilypads, where, size, WATER_HEIGHT + 0.07, 9, theta)
				plant_count += 1
				if n < 2 and (ix + iz) % 2 == 0:
					_lotus(lotuses, lotus_centers, where + Vector2(1.5, 0.3), rng.randf_range(0.9, 1.4))
				# Kolmi-lata / water-spinach-style floating creeping leaves.
				if n >= 2:
					var crawl := Vector2(cos(theta + 1.0), sin(theta + 1.0))
					for leaf in range(3):
						_leaf(vines, where + crawl * float(leaf) * 1.3, crawl, size * 0.75, WATER_HEIGHT + 0.10)

	_commit(water, "WetlandWater", _mat(Color(0.10, 0.38, 0.49), 0.23))
	_commit(banks, "WetlandShore", _mat(Color(0.24, 0.43, 0.28)))
	_commit(lilypads, "LilyPads", _mat(Color(0.12, 0.43, 0.20)))
	_commit(vines, "WaterSpinachVines", _mat(Color(0.20, 0.55, 0.21)))
	_commit(lotuses, "PinkLotusFlowers", _mat(Color(0.96, 0.39, 0.62)))
	_commit(lotus_centers, "LotusCenters", _mat(Color(0.99, 0.84, 0.18)))
	_commit(shore_reeds, "WetlandReeds", _mat(Color(0.31, 0.51, 0.22)))

func is_in_water(world: Vector3) -> bool:
	var p := Vector2(world.x, world.z)
	for disk in ponds:
		var dx := p.x - disk.x
		var dz := p.y - disk.y
		# Use a small visual margin to avoid fines when only grazing the shore.
		var safe_radius := disk.z - 2.0
		if dx*dx + dz*dz <= safe_radius * safe_radius:
			return true
	return false
