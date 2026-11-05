extends Node3D
# Mobile-friendly Manhattan street furniture. Original procedural geometry;
# material/draw-call batches instead of individual scene instances.
const MAX_LAMPS := 92
const MAX_TREES := 48

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	if emissive:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)
	_tri(st, c, b, a)
	_tri(st, d, c, a)

func _post(st: SurfaceTool, pos: Vector3, h: float, w: float) -> void:
	var a := pos + Vector3(-w, 0, 0)
	var b := pos + Vector3(w, 0, 0)
	_quad(st, a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0))
	a = pos + Vector3(0, 0, -w)
	b = pos + Vector3(0, 0, w)
	_quad(st, a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0))

func _face(st: SurfaceTool, left: Vector3, right: Vector3, top_height: float) -> void:
	_quad(st, left, right, right + Vector3.UP * top_height, left + Vector3.UP * top_height)

func _commit(st: SurfaceTool, mat: Material, label: String) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	add_child(node)

func build(map_data: Dictionary) -> void:
	var poles := SurfaceTool.new()
	var lights := SurfaceTool.new()
	var trunks := SurfaceTool.new()
	var foliage := SurfaceTool.new()
	var planter := SurfaceTool.new()
	for st in [poles, lights, trunks, foliage, planter]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lamps := 0
	var trees := 0
	for road in map_data.get("roads", []):
		if lamps >= MAX_LAMPS and trees >= MAX_TREES:
			break
		var kind := str(road.get("type", "residential"))
		if kind in ["service", "living_street"]:
			continue
		var width := 9.0 if kind in ["primary", "secondary", "trunk"] else 6.0
		var pts: Array = road.get("points", [])
		for j in range(pts.size() - 1):
			var start := Vector2(float(pts[j][0]), float(pts[j][1]))
			var finish := Vector2(float(pts[j + 1][0]), float(pts[j + 1][1]))
			var diff := finish - start
			var length := diff.length()
			if length < 23.0:
				continue
			var d := diff / length
			var normal := Vector2(-d.y, d.x)
			var count := mini(6, int(length / 31.0))
			for k in range(count):
				var center := start + d * (14.0 + float(k) * 31.0)
				if center.length_squared() > 320.0 * 320.0:
					continue
				var side := 1.0 if (k + j) % 2 == 0 else -1.0
				var sidewalk := center + normal * side * (width * 0.5 + 1.72)
				if lamps < MAX_LAMPS:
					var base := Vector3(sidewalk.x, 0.12, sidewalk.y)
					_post(poles, base, 7.25, 0.10)
					# Horizontal street-light arm extends over the road.
					var arm_out := Vector3(normal.x * side, 0, normal.y * side)
					var tip := base + Vector3.UP * 7.15 - arm_out * 1.7
					_face(poles, base + Vector3.UP * 7.08, tip, 0.13)
					var lamp_end := tip - arm_out * 0.28
					_face(lights, lamp_end - Vector3(d.x,0,d.y) * 0.55, lamp_end + Vector3(d.x,0,d.y) * 0.55, 0.18)
					lamps += 1
				if trees < MAX_TREES and kind in ["residential", "tertiary"] and (k + j) % 3 == 0:
					var tree_base := Vector3(sidewalk.x, 0.12, sidewalk.y)
					_post(trunks, tree_base, 3.2, 0.18)
					_post(foliage, tree_base + Vector3.UP * 2.8, 4.0, 1.25)
					_face(planter, tree_base + Vector3(-0.64, 0.20, -0.64), tree_base + Vector3(0.64, 0.20, -0.64), 0.35)
					trees += 1
				if lamps >= MAX_LAMPS and trees >= MAX_TREES:
					break
	_commit(poles, _material(Color(0.24, 0.28, 0.33)), "StreetlampPoles")
	_commit(lights, _material(Color(1.0, 0.92, 0.62), true), "StreetlampLenses")
	_commit(trunks, _material(Color(0.29, 0.24, 0.18)), "StreetTreeTrunks")
	_commit(foliage, _material(Color(0.19, 0.40, 0.29)), "StreetTreeCrowns")
	_commit(planter, _material(Color(0.42, 0.44, 0.43)), "StreetTreePlanters")
