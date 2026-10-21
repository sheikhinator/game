class_name CityBuilder
extends Node3D
## Builds the Port Calder downtown grid from the modular city kit:
## streets, intersections, buildings, street furniture, colliders and occluders.

const SEG := 6.0          # length of one straight street piece
const INTER := 18.0       # intersection core size (road + sidewalks)
const SEGS := 8           # street pieces between two intersections
const BLOCK := SEG * SEGS # 48 m city block
const PITCH := INTER + BLOCK
const ROAD_HALF := 6.0    # half width of the driving surface
const WALK_HALF := 9.0    # half width including sidewalks

const BUILDINGS := ["Building_Large_2", "Building_Medium_2_001", "Building_Small_1"]
const LAYER_WORLD := 1

@export var grid_x := 3
@export var grid_z := 3
@export var city_seed := 1337

var rng := RandomNumberGenerator.new()
## For maps: road centre lines and building footprints in world XZ.
var road_segments: Array = []   # [Vector2 a, Vector2 b]
var footprints: Array = []      # Rect2
var lamp_lights: Array[OmniLight3D] = []

var _scene_cache := {}
var _footprint_cache := {}
var _fixed_materials := {}


func build() -> void:
	rng.seed = city_seed
	_build_ground()
	_build_streets()
	for bx in range(-1, grid_x + 1):
		for bz in range(-1, grid_z + 1):
			_build_block(bx, bz)


func bounds() -> Rect2:
	return Rect2(-PITCH, -PITCH, PITCH * (grid_x + 2), PITCH * (grid_z + 2))


func spawn_point() -> Vector3:
	# On the sidewalk just south-east of the first inner intersection.
	return Vector3(PITCH + INTER * 0.5 + 6.0, 0.05, PITCH + ROAD_HALF + 1.6)


# ---------------------------------------------------------------- pieces

func _scene(name: String) -> PackedScene:
	if not _scene_cache.has(name):
		var path := "res://assets/city/%s.gltf" % name
		if not ResourceLoader.exists(path):
			path = name
		_scene_cache[name] = load(path)
	return _scene_cache[name]


func _put(name: String, pos: Vector3, rot_y_deg: float = 0.0, parent: Node = self) -> Node3D:
	var inst: Node3D = _scene(name).instantiate()
	parent.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = rot_y_deg
	_fix_materials(inst)
	return inst


func _fix_materials(root: Node) -> void:
	# The kit stores wear masks in vertex colours; Godot would tint surfaces red with them.
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null or _fixed_materials.has(mesh):
			continue
		_fixed_materials[mesh] = true
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			if mat.resource_name == "MI_Asphalt":
				mesh.surface_set_material(i, _asphalt())
				continue
			mat.vertex_color_use_as_albedo = false
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


var _asphalt_mat: StandardMaterial3D

## Photo-scanned asphalt mapped in world space so every road piece lines up seamlessly.
func _asphalt() -> StandardMaterial3D:
	if _asphalt_mat == null:
		var m := StandardMaterial3D.new()
		m.resource_name = "Lycho_Asphalt"
		m.albedo_texture = load("res://assets/textures/asphalt_02/asphalt_02_diff.jpg")
		m.albedo_color = Color(0.62, 0.62, 0.64)
		m.normal_enabled = true
		m.normal_texture = load("res://assets/textures/asphalt_02/asphalt_02_nor.jpg")
		m.normal_scale = 1.2
		m.roughness_texture = load("res://assets/textures/asphalt_02/asphalt_02_rough.jpg")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.22, 0.22, 0.22)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_asphalt_mat = m
	return _asphalt_mat


func _footprint(name: String) -> AABB:
	if not _footprint_cache.has(name):
		var inst: Node3D = _scene(name).instantiate()
		var box := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		inst.free()
		_footprint_cache[name] = box
	return _footprint_cache[name]


# ---------------------------------------------------------------- ground and streets

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = LAYER_WORLD
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child(body)

	# A wide concrete apron under the blocks so nothing floats in the void.
	var b := bounds().grow(400.0)
	var mesh := PlaneMesh.new()
	mesh.size = b.size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/concrete_pavement/concrete_pavement_diff.jpg")
	mat.albedo_color = Color(0.8, 0.8, 0.8)
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/concrete_pavement/concrete_pavement_nor.jpg")
	mat.roughness_texture = load("res://assets/textures/concrete_pavement/concrete_pavement_rough.jpg")
	mat.uv1_scale = Vector3(b.size.x / 3.0, b.size.y / 3.0, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(b.get_center().x, -0.02, b.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_streets() -> void:
	var streets := Node3D.new()
	streets.name = "Streets"
	add_child(streets)
	for i in grid_x + 1:
		for j in grid_z + 1:
			_put("Street_4WayIntersection", Vector3(i * PITCH, 0, j * PITCH), 0, streets)
	for j in grid_z + 1:
		var z := j * PITCH
		road_segments.append([Vector2(-PITCH * 0.6, z), Vector2(grid_x * PITCH + PITCH * 0.6, z)])
		for i in grid_x:
			for k in SEGS:
				var x := i * PITCH + INTER * 0.5 + SEG * 0.5 + k * SEG
				_put("Street_4Lane", Vector3(x, 0, z), 0, streets)
				if k % 3 == 1:
					_street_furniture(Vector3(x, 0, z), false, streets)
	for i in grid_x + 1:
		var x := i * PITCH
		road_segments.append([Vector2(x, -PITCH * 0.6), Vector2(x, grid_z * PITCH + PITCH * 0.6)])
		for j in grid_z:
			for k in SEGS:
				var z := j * PITCH + INTER * 0.5 + SEG * 0.5 + k * SEG
				_put("Street_4Lane", Vector3(x, 0, z), 90, streets)
				if k % 3 == 1:
					_street_furniture(Vector3(x, 0, z), true, streets)
	# Short stubs leading off the edge of the map so outer roads don't end abruptly.
	for j in grid_z + 1:
		for k in 4:
			_put("Street_4Lane", Vector3(-INTER * 0.5 - SEG * 0.5 - k * SEG, 0, j * PITCH), 0, streets)
			_put("Street_4Lane", Vector3(grid_x * PITCH + INTER * 0.5 + SEG * 0.5 + k * SEG, 0, j * PITCH), 0, streets)
	for i in grid_x + 1:
		for k in 4:
			_put("Street_4Lane", Vector3(i * PITCH, 0, -INTER * 0.5 - SEG * 0.5 - k * SEG), 90, streets)
			_put("Street_4Lane", Vector3(i * PITCH, 0, grid_z * PITCH + INTER * 0.5 + SEG * 0.5 + k * SEG), 90, streets)


func _street_furniture(center: Vector3, along_z: bool, parent: Node) -> void:
	# A lamp on each kerb, facing the road, plus the odd hydrant.
	for side in [-1.0, 1.0]:
		var off: float = (ROAD_HALF + 0.6) * side
		var pos := center + (Vector3(off, 0, 0) if along_z else Vector3(0, 0, off))
		var face: float = (-90.0 if side > 0 else 90.0) if along_z else (180.0 if side > 0 else 0.0)
		var lamp := _put("res://assets/props/street_lamp_01/street_lamp_01.gltf", pos, face, parent)
		_add_pole_collider(lamp, 0.15, 6.0)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.82, 0.6)
		light.omni_range = 18.0
		light.omni_attenuation = 1.4
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.light_bake_mode = Light3D.BAKE_DISABLED
		light.position = Vector3(0, 5.6, 0)
		light.visible = false
		lamp.add_child(light)
		lamp_lights.append(light)
		if rng.randf() < 0.18:
			var hp := pos + (Vector3(0, 0, 2.5) if along_z else Vector3(2.5, 0, 0))
			var hyd := _put("res://assets/props/fire_hydrant/fire_hydrant.gltf", hp, rng.randf_range(0, 360), parent)
			_add_pole_collider(hyd, 0.25, 0.9)


func _add_pole_collider(node: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	cs.position.y = height * 0.5
	body.add_child(cs)
	node.add_child(body)


# ---------------------------------------------------------------- blocks

func _build_block(bx: int, bz: int) -> void:
	var block := Node3D.new()
	block.name = "Block_%d_%d" % [bx, bz]
	add_child(block)
	var x0 := bx * PITCH + INTER * 0.5
	var z0 := bz * PITCH + INTER * 0.5
	var x1 := x0 + BLOCK
	var z1 := z0 + BLOCK
	# Long rows on the north and south sides, then short fill-ins east and west.
	var depth_n := _fill_row(block, Vector2(x0, z0), Vector2(1, 0), Vector2(0, -1), BLOCK)
	var depth_s := _fill_row(block, Vector2(x1, z1), Vector2(-1, 0), Vector2(0, 1), BLOCK)
	var gap_start := z0 + depth_n
	var gap_len := (z1 - depth_s) - gap_start
	if gap_len > 11.0:
		_fill_row(block, Vector2(x0, z1 - depth_s), Vector2(0, -1), Vector2(-1, 0), gap_len)
		_fill_row(block, Vector2(x1, gap_start), Vector2(0, 1), Vector2(1, 0), gap_len)


## Places buildings along one block edge. `start` is the corner, `along` the run
## direction, `out` the street-facing direction. Returns the deepest building used.
func _fill_row(block: Node3D, start: Vector2, along: Vector2, out: Vector2, length: float) -> float:
	var used := 0.0
	var max_depth := 0.0
	var guard := 0
	while used < length - 11.0 and guard < 8:
		guard += 1
		var options := []
		for n in BUILDINGS:
			if _footprint(n).size.x <= length - used + 0.5:
				options.append(n)
		if options.is_empty():
			break
		var name: String = options[rng.randi() % options.size()]
		var fp := _footprint(name)
		var width := fp.size.x
		# Model faces +Z with its front at local z = fp.end.z; width runs along +X.
		var yaw := atan2(out.x, out.y)
		var basis := Basis(Vector3.UP, yaw)
		var local_left := Vector3(fp.position.x, 0, fp.end.z)
		var world_left := Vector3(start.x, 0, start.y) + Vector3(along.x, 0, along.y) * used
		# Local +X maps to `along` only when that matches the rotation; otherwise anchor the other end.
		var axis_x := basis * Vector3.RIGHT
		# When local +X runs along the row, the building's min-X front corner sits at the
		# row cursor; when it runs against it, the max-X front corner does.
		var origin: Vector3
		if axis_x.dot(Vector3(along.x, 0, along.y)) > 0.0:
			origin = world_left - basis * local_left
		else:
			origin = world_left - basis * Vector3(fp.end.x, 0, fp.end.z)
		var b := _put(name, origin, rad_to_deg(yaw), block)
		_add_building_collision(b, fp)
		used += width + 0.05
		max_depth = maxf(max_depth, fp.size.z)
		var world_box: AABB = b.transform * fp
		footprints.append(Rect2(world_box.position.x, world_box.position.z, world_box.size.x, world_box.size.z))
	return max_depth


func _add_building_collision(b: Node3D, fp: AABB) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = fp.size
	cs.shape = box
	cs.position = fp.get_center()
	body.add_child(cs)
	b.add_child(body)
	# Box occluder lets the renderer skip everything hidden behind the building.
	var occ := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = fp.size * Vector3(0.92, 0.95, 0.92)
	occ.occluder = bo
	occ.position = fp.get_center()
	b.add_child(occ)
