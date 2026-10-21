class_name CharacterModel
extends Node3D
## A realistic MakeHuman character (assets/humans/*.glb), retargeted on import to
## Godot's humanoid skeleton so every Universal Animation Library clip plays on it.

const DEFAULT_MODEL := "male_a"
const ANIM_LIBS := {
	"a": "res://assets/animations/UAL1_Standard.glb",
	"b": "res://assets/animations/UAL2_Standard.glb",
}
const LOOPING := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Driving", "Sitting_Idle", "Swim_Fwd", "Swim_Idle", "Idle_Talking", "Dance", "Walk_Formal"]

static var _anim_libs := {}

var body_root: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var current := ""


func setup(appearance: Dictionary) -> void:
	var model: String = appearance.get("model", DEFAULT_MODEL)
	var path := "res://assets/humans/%s.glb" % model
	if not ResourceLoader.exists(path):
		path = "res://assets/humans/%s.glb" % DEFAULT_MODEL
	body_root = load(path).instantiate()
	add_child(body_root)
	skeleton = body_root.find_child("GeneralSkeleton", true, false)
	for mi: MeshInstance3D in body_root.find_children("*", "MeshInstance3D", true, false):
		_tune_materials(mi)
	_setup_animation()
	play("Idle")


## Game-ready material fixes: soft skin, alpha-hashed hair and lashes.
func _tune_materials(mi: MeshInstance3D) -> void:
	var n := mi.name.to_lower()
	var is_strands := n.contains("eyebrow") or n.contains("eyelash") or n.contains("hair") or n.contains("short") or n.contains("long") or n.contains("bob") or n.contains("ponytail") or n.contains("afro") or n.contains("braid")
	var is_skin := mi.name == "Human_export" or n.ends_with("human_export")
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if is_strands:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			m.alpha_hash_scale = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.8
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		elif is_skin:
			m.roughness = 0.58
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.35
			m.subsurf_scatter_skin_mode = true
		else:
			m.roughness = maxf(m.roughness, 0.75)
		mi.set_surface_override_material(i, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


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
