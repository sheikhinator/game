class_name CarLook
extends RefCounted
## Loads a generated car (assets/vehicles/<name>.glb + .json) and applies the
## per-pixel car body shader using the car's own profile data.

static var _materials := {}
static var _specs := {}


static func spec(name: String) -> Dictionary:
	if not _specs.has(name):
		var path := "res://assets/vehicles/%s.json" % name
		var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_specs[name] = data if data is Dictionary else {}
	return _specs[name]


static func instantiate(name: String) -> Node3D:
	var scene: Node3D = load("res://assets/vehicles/%s.glb" % name).instantiate()
	var body := scene.find_child("Body", true, false) as MeshInstance3D
	if body:
		body.material_override = body_material(name)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return scene


static func body_material(name: String) -> ShaderMaterial:
	if _materials.has(name):
		return _materials[name]
	var s := spec(name)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/car_body.gdshader")
	if not s.is_empty():
		var img := Image.create(64, 1, false, Image.FORMAT_RGF)
		for i in 64:
			img.set_pixel(i, 0, Color(s.belt[i], s.roof[i], 0))
		m.set_shader_parameter("profile", ImageTexture.create_from_image(img))
		m.set_shader_parameter("car_length", s.length)
		m.set_shader_parameter("car_width", s.width)
		m.set_shader_parameter("clearance", s.clearance)
		m.set_shader_parameter("wheel_r", s.wheel_r)
		m.set_shader_parameter("axle_front", s.axle_front)
		m.set_shader_parameter("axle_rear", s.axle_rear)
		m.set_shader_parameter("cabin_start", s.cabin_start)
		m.set_shader_parameter("cabin_end", s.cabin_end)
		var rm := 0.0
		for v in s.roof:
			rm = maxf(rm, v)
		m.set_shader_parameter("roof_max", rm)
		var p: Array = s.paint
		m.set_shader_parameter("paint", Color(p[0], p[1], p[2]).linear_to_srgb())
		m.set_shader_parameter("paint_metallic", 0.65 if s.metallic else 0.0)
		m.set_shader_parameter("paint_rough", 0.24 if s.metallic else 0.32)
	_materials[name] = m
	return m
