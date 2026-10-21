class_name CharacterModel
extends Node3D
## A Universal Base Character with hair, painted-on clothing and the
## Universal Animation Library. Same skeleton everywhere, so any animation fits.

const BODIES := {
	"male": {"scene": "res://assets/characters/Superhero_Male_FullBody.gltf", "mesh": "SuperHero_Male",
		"skin": {"light": "res://assets/characters/T_Superhero_Male_Light.png", "dark": "res://assets/characters/T_Superhero_Male_Dark.png"}},
	"female": {"scene": "res://assets/characters/Superhero_Female_FullBody.gltf", "mesh": "SuperHero_Female",
		"skin": {"light": "res://assets/characters/T_Superhero_Female_Light_BaseColor.png", "dark": "res://assets/characters/T_Superhero_Female_Dark_BaseColor.png"}},
}
const ANIM_LIBS := {
	"a": "res://assets/animations/UAL1_Standard.glb",
	"b": "res://assets/animations/UAL2_Standard.glb",
}
const LOOPING := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Driving", "Sitting_Idle", "Swim_Fwd", "Swim_Idle", "Idle_Talking", "Dance"]

static var _anim_libs := {}
static var _mask_cache := {}

var body_root: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var body_mesh: MeshInstance3D
var current := ""
var hair_color := Color(0.17, 0.11, 0.08)


func setup(appearance: Dictionary) -> void:
	var kind: String = appearance.get("body", "male")
	var def: Dictionary = BODIES.get(kind, BODIES.male)
	body_root = load(def.scene).instantiate()
	add_child(body_root)
	skeleton = body_root.find_child("Skeleton3D", true, false)
	body_mesh = body_root.find_child(def.mesh, true, false)
	if body_mesh == null:
		for mi in body_root.find_children("*", "MeshInstance3D", true, false):
			if mi.get_aabb().size.y > 1.0:
				body_mesh = mi
	_dress(def, appearance)
	hair_color = Color(appearance.get("hair_color", "#2b1d14"))
	_attach_hair(appearance.get("hair", ""))
	if kind == "male" and appearance.get("beard", false):
		_attach_hair("Hair_Beard")
	for mi in body_root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_setup_animation()
	play("Idle")


# ---------------------------------------------------------------- clothing

func _dress(def: Dictionary, appearance: Dictionary) -> void:
	var src_mat := body_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	body_mesh.mesh = _masked_mesh(body_mesh.mesh)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/clothed_body.gdshader")
	var skin_path: String = def.skin.get(appearance.get("skin", "light"), "")
	var skin_tex: Texture2D = load(skin_path) if ResourceLoader.exists(skin_path) else (src_mat.albedo_texture if src_mat else null)
	mat.set_shader_parameter("skin_albedo", skin_tex)
	if src_mat:
		mat.set_shader_parameter("skin_normal", src_mat.normal_texture)
		mat.set_shader_parameter("skin_rough", src_mat.roughness_texture)
		var ch := [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0.299, 0.587, 0.114, 0)]
		mat.set_shader_parameter("rough_channel", ch[src_mat.roughness_texture_channel])
	mat.set_shader_parameter("shirt_albedo", load("res://assets/textures/cotton_jersey/cotton_jersey_diff.jpg"))
	mat.set_shader_parameter("shirt_normal", load("res://assets/textures/cotton_jersey/cotton_jersey_nor.jpg"))
	mat.set_shader_parameter("pants_albedo", load("res://assets/textures/denim_fabric/denim_fabric_diff.jpg"))
	mat.set_shader_parameter("pants_normal", load("res://assets/textures/denim_fabric/denim_fabric_nor.jpg"))
	mat.set_shader_parameter("shoe_albedo", load("res://assets/textures/leather_white/leather_white_diff.jpg"))
	mat.set_shader_parameter("shoe_normal", load("res://assets/textures/leather_white/leather_white_nor.jpg"))
	mat.set_shader_parameter("shirt_color", Color(appearance.get("shirt_color", "#2a3344")))
	mat.set_shader_parameter("pants_color", Color(appearance.get("pants_color", "#516180")))
	mat.set_shader_parameter("shoe_color", Color(appearance.get("shoe_color", "#ebebe6")))
	body_mesh.material_override = mat


## Copies the body mesh and writes clothing masks into vertex colours,
## using rest-pose (T-pose) positions so the masks follow the body when animated.
static func _masked_mesh(src: Mesh) -> ArrayMesh:
	if _mask_cache.has(src):
		return _mask_cache[src]
	var out := ArrayMesh.new()
	if src is ArrayMesh and src.get_blend_shape_count() > 0:
		out.blend_shape_mode = src.blend_shape_mode
		for b in src.get_blend_shape_count():
			out.add_blend_shape(src.get_blend_shape_name(b))
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			var v := verts[i]
			var ax := absf(v.x)
			var shoes := 1.0 - smoothstep(0.085, 0.11, v.y)
			# Trousers: legs and hips, up to the waist.
			var pants := smoothstep(0.08, 0.11, v.y) * (1.0 - smoothstep(0.98, 1.01, v.y)) * (1.0 - smoothstep(0.32, 0.36, ax))
			# T-shirt: torso from waist to neckline, short sleeves out to mid upper arm.
			var torso := smoothstep(0.96, 0.99, v.y) * (1.0 - smoothstep(1.48, 1.52, v.y))
			var sleeve := 1.0 - smoothstep(0.36, 0.40, ax)
			var shirt := torso * sleeve
			shirt *= 1.0 - shoes
			pants *= 1.0 - shirt
			colors[i] = Color(shirt, pants, shoes, 1.0)
		arrays[Mesh.ARRAY_COLOR] = colors
		var blend := []
		if src is ArrayMesh and src.get_blend_shape_count() > 0:
			blend = src.surface_get_blend_shape_arrays(s)
		var flags := 0
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if weights != null and verts.size() > 0 and weights.size() == verts.size() * 8:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend, {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
	_mask_cache[src] = out
	return out


func _attach_hair(name: String) -> void:
	if name.is_empty():
		return
	var path := "res://assets/characters/hair/%s.gltf" % name
	if not ResourceLoader.exists(path):
		return
	var hair_root: Node3D = load(path).instantiate()
	for mi in hair_root.find_children("*", "MeshInstance3D", true, false):
		var copy := mi.duplicate() as MeshInstance3D
		skeleton.add_child(copy)
		copy.skeleton = NodePath("..")
		copy.skin = mi.skin
		# Hair textures are greyscale; tint them with the chosen colour.
		var src := copy.mesh.surface_get_material(0) as StandardMaterial3D
		if src:
			var m := src.duplicate() as StandardMaterial3D
			m.albedo_color = hair_color
			m.roughness = 0.75
			copy.material_override = m
	hair_root.free()


# ---------------------------------------------------------------- animation

func _setup_animation() -> void:
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	body_root.add_child(anim)
	anim.root_node = NodePath("..")
	for key in ANIM_LIBS:
		anim.add_animation_library(key, _library(key))
	anim.playback_default_blend_time = 0.2


static func _library(key: String) -> AnimationLibrary:
	if _anim_libs.has(key):
		return _anim_libs[key]
	var src: Node = load(ANIM_LIBS[key]).instantiate()
	var player := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib := AnimationLibrary.new()
	if player:
		for lib_name in player.get_animation_library_list():
			var l := player.get_animation_library(lib_name)
			for a in l.get_animation_list():
				var copy: Animation = l.get_animation(a).duplicate(true)
				if a in LOOPING or a.ends_with("_Loop"):
					copy.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation(a, copy)
	src.free()
	_anim_libs[key] = lib
	return lib


func has_anim(name: String) -> bool:
	return anim != null and (anim.has_animation("a/" + name) or anim.has_animation("b/" + name))


func play(name: String, blend := -1.0, speed := 1.0) -> void:
	if anim == null:
		return
	var full := "a/" + name if anim.has_animation("a/" + name) else "b/" + name
	if not anim.has_animation(full):
		return
	anim.speed_scale = speed
	if current == full and anim.is_playing():
		return
	current = full
	anim.play(full, blend)
