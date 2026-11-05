extends Node3D
# SHIFTWORLD 3D — Scenic Water Garden
# Original, offline, low-poly interpretation of the user's selected concept image.
# A dedicated route keeps the actual Manhattan OSM road network unchanged.
const START_Z := 75.0
const END_Z := -960.0
const ROAD_HALF_WIDTH := 7.2
const INNER_WATER := 18.0
const OUTER_WATER := 82.0
const WATER_Y := 0.037

var flower_count := 0
var tree_count := 0

func _mat(color: Color, roughness: float = 0.86, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)

func _strip(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, y: float) -> void:
	_quad(st, Vector3(x1,y,z1), Vector3(x2,y,z1), Vector3(x2,y,z2), Vector3(x1,y,z2))

func _disk(st: SurfaceTool, center: Vector2, radius: float, y: float, sides: int) -> void:
	for k in range(sides):
		var a := TAU * float(k) / float(sides)
		var z := TAU * float(k+1) / float(sides)
		_tri(st, Vector3(center.x,y,center.y),
			Vector3(center.x+cos(a)*radius,y,center.y+sin(a)*radius),
			Vector3(center.x+cos(z)*radius,y,center.y+sin(z)*radius))

func _cross(st: SurfaceTool, center: Vector3, height: float, width: float) -> void:
	_quad(st, center+Vector3(-width,0,0), center+Vector3(width,0,0),
		center+Vector3(width,height,0), center+Vector3(-width,height,0))
	_quad(st, center+Vector3(0,0,-width), center+Vector3(0,0,width),
		center+Vector3(0,height,width), center+Vector3(0,height,-width))

func _petals(st: SurfaceTool, center: Vector2, scale: float) -> void:
	var y := WATER_Y + 0.23
	for j in range(8):
		var angle := TAU*float(j)/8.0
		var axis := Vector2(cos(angle),sin(angle))
		var side := Vector2(-axis.y,axis.x)
		var left := center + side*0.22*scale
		var right := center-side*0.22*scale
		var tip := center+axis*0.86*scale
		_tri(st,Vector3(left.x,y,left.y),Vector3(right.x,y,right.y),Vector3(tip.x,y+0.55*scale,tip.y))
	flower_count += 1

func _rock(st: SurfaceTool, point: Vector3, width: float, tall: float) -> void:
	var x := point.x
	var z := point.z
	var h := point.y
	var a := Vector3(x-width,h,z-width*0.7)
	var b := Vector3(x+width,h,z-width*0.6)
	var c := Vector3(x+width*0.75,h,z+width*0.7)
	var d := Vector3(x-width*0.85,h,z+width*0.6)
	var top := Vector3(x,h+tall,z)
	_tri(st,a,b,top)
	_tri(st,b,c,top)
	_tri(st,c,d,top)
	_tri(st,d,a,top)

func _commit(st: SurfaceTool, name: String, material: Material) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _make_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "MeadowGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400.0,2400.0)
	ground.mesh = plane
	ground.position = Vector3(0,-0.12,-400)
	ground.material_override = _mat(Color(0.20,0.39,0.22))
	add_child(ground)

func build() -> void:
	_make_ground()
	var asphalt := _begin()
	var paint := _begin()
	var edge := _begin()
	var water := _begin()
	var bank := _begin()
	var stone := _begin()
	var lily := _begin()
	var pink := _begin()
	var yellow := _begin()
	var grass := _begin()
	var trunks := _begin()
	var crown := _begin()
	var blossoms := _begin()
	var shrubs := _begin()
	var waterfalls := _begin()
	var foam := _begin()
	var guard_posts := _begin()

	_strip(asphalt,-ROAD_HALF_WIDTH,ROAD_HALF_WIDTH,START_Z,END_Z,0.02)
	_strip(edge,-ROAD_HALF_WIDTH-0.55,-ROAD_HALF_WIDTH,START_Z,END_Z,0.053)
	_strip(edge,ROAD_HALF_WIDTH,ROAD_HALF_WIDTH+0.55,START_Z,END_Z,0.053)
	_strip(paint,-ROAD_HALF_WIDTH+0.45,-ROAD_HALF_WIDTH+0.60,START_Z,END_Z,0.061)
	_strip(paint,ROAD_HALF_WIDTH-0.60,ROAD_HALF_WIDTH-0.45,START_Z,END_Z,0.061)
	for i in range(95):
		var z := 45.0 - float(i)*10.0
		_strip(paint,-0.11,0.11,z,z-4.0,0.062)
	# Long parallel lily-pad lakes: visibly adjacent to both sides of the road.
	for side in [-1.0,1.0]:
		var a := side*INNER_WATER
		var c := side*OUTER_WATER
		_strip(water,minf(a,c),maxf(a,c),START_Z,END_Z,WATER_Y)
		_strip(bank,minf(a,side*(INNER_WATER-3.0)),maxf(a,side*(INNER_WATER-3.0)),START_Z,END_Z,0.061)
		_strip(bank,minf(c,side*(OUTER_WATER+4.0)),maxf(c,side*(OUTER_WATER+4.0)),START_Z,END_Z,0.055)
		# Raised stone edging between the public road and the planted lake.
		_strip(stone,minf(side*8.3,side*9.0),maxf(side*8.3,side*9.0),START_Z,END_Z,0.082)

	var rng := RandomNumberGenerator.new()
	rng.seed = 771204
	for i in range(90):
		var z := 28.0-float(i)*11.0
		for side in [-1.0,1.0]:
			var side_float := float(side)
			var water_x := side_float*rng.randf_range(24.0,74.0)
			var flower_point := Vector2(water_x,z+rng.randf_range(-5.5,5.5))
			var radius := rng.randf_range(0.85,2.2)
			_disk(lily,flower_point,radius,WATER_Y+0.05,9)
			if i%3==0:
				_petals(pink,flower_point,rng.randf_range(0.9,1.7))
				_disk(yellow,flower_point,0.18,WATER_Y+0.31,8)
			if i%7==0:
				_petals(pink,flower_point+Vector2(3.0*side_float,-3.8),1.1)
				_disk(yellow,flower_point+Vector2(3.0*side_float,-3.8),0.17,WATER_Y+0.31,8)

	for i in range(49):
		var z := 25.0-float(i)*20.5
		for side in [-1.0,1.0]:
			var sx := float(side)
			# Crossed tree silhouettes and additional pink flowering canopies.
			var point := Vector3(sx*11.9,0.10,z)
			_cross(trunks,point,4.4,0.21)
			_cross(crown,point+Vector3(0,2.7,0),3.6,2.4)
			tree_count += 1
			if i%4==0:
				_cross(blossoms,point+Vector3(0,3.5,0),2.8,1.65)
			var flowers_at := Vector3(sx*15.0,0.08,z+4.0)
			_cross(shrubs,flowers_at,0.82,1.1)
			_cross(grass,Vector3(sx*16.1,0.05,z-4.0),1.35,0.4)
			if i%3==0:
				_rock(stone,Vector3(sx*15.1,0.06,z-2.0),rng.randf_range(0.65,1.2),rng.randf_range(0.4,0.75))
			# Roadside bollards, painted white/red.
			if i%2==0:
				_cross(guard_posts,Vector3(sx*8.95,0.08,z+6.0),0.95,0.13)

	# A recognizable little three-tier waterfall on the left side, set within
	# the lake. This is decorative, not expensive simulated fluid.
	for tier in range(3):
		var z := -242.0-float(tier)*6.0
		for j in range(7):
			_rock(stone,Vector3(-47.0+float(j)*4.4, WATER_Y, z),
				rng.randf_range(1.9,2.9),1.15+float(tier)*0.28)
		var drop := 1.55+float(tier)*0.30
		_quad(waterfalls,
			Vector3(-48.0,WATER_Y+drop,z-1.5),
			Vector3(-20.0,WATER_Y+drop,z-1.5),
			Vector3(-20.0,WATER_Y+0.18,z+0.7),
			Vector3(-48.0,WATER_Y+0.18,z+0.7))
		_strip(foam,-48.0,-20.0,z+0.4,z+2.3,WATER_Y+0.105)

	_commit(asphalt,"ScenicRoad",_mat(Color(0.19,0.21,0.24)))
	_commit(paint,"LanePaint",_mat(Color(0.95,0.94,0.85),0.88,true))
	_commit(edge,"RoadShoulders",_mat(Color(0.65,0.64,0.61)))
	_commit(water,"ScenicLakes",_mat(Color(0.065,0.43,0.56),0.15))
	_commit(bank,"GreenLakeBanks",_mat(Color(0.20,0.42,0.22)))
	_commit(stone,"BouldersAndKerbs",_mat(Color(0.52,0.54,0.48)))
	_commit(lily,"FloatingLilyPads",_mat(Color(0.11,0.53,0.21)))
	_commit(pink,"LotusPetals",_mat(Color(1.0,0.43,0.66),0.65,true))
	_commit(yellow,"LotusStamens",_mat(Color(0.99,0.83,0.15),0.7,true))
	_commit(grass,"WatersideReeds",_mat(Color(0.51,0.65,0.28)))
	_commit(trunks,"TreeTrunks",_mat(Color(0.28,0.22,0.14)))
	_commit(crown,"LeafyTreeCanopies",_mat(Color(0.17,0.43,0.22)))
	_commit(blossoms,"PinkFlowerTrees",_mat(Color(0.96,0.37,0.58)))
	_commit(shrubs,"FlowerGardenBushes",_mat(Color(0.18,0.57,0.31)))
	_commit(waterfalls,"TieredWaterfall",_mat(Color(0.64,0.87,0.97),0.2,true))
	_commit(foam,"WaterfallFoam",_mat(Color(0.88,0.96,0.98),0.2,true))
	_commit(guard_posts,"RoadsideMarkerPosts",_mat(Color(0.94,0.93,0.90)))

func get_map_data() -> Dictionary:
	return {"roads":[{"name":"Lotus Lake Road","type":"secondary","points":[[0.0,START_Z],[0.0,END_Z]]}]}

func get_ponds() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in range(18):
		var z := 10.0-float(i)*54.0
		result.append(Vector3(-45.0,z,30.0))
		result.append(Vector3(45.0,z,30.0))
	return result

func is_in_water(world: Vector3) -> bool:
	var x := absf(world.x)
	return x > INNER_WATER+1.2 and x < OUTER_WATER-1.2 and world.z < START_Z-4.0 and world.z > END_Z+4.0
