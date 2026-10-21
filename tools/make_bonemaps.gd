extends SceneTree
# Builds Godot BoneMaps (UE-style names -> SkeletonProfileHumanoid) for the
# Universal Animation Library skeleton and MakeHuman's game_engine rig.
const MAP := {
	"Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03",
	"Neck": "neck_01", "Head": "head",
	"LeftShoulder": "clavicle_l", "LeftUpperArm": "upperarm_l", "LeftLowerArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightUpperArm": "upperarm_r", "RightLowerArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "calf_l", "LeftFoot": "foot_l", "LeftToes": "ball_l",
	"RightUpperLeg": "thigh_r", "RightLowerLeg": "calf_r", "RightFoot": "foot_r", "RightToes": "ball_r",
}
const FINGERS := {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Little": "pinky"}
func build(root_name: String) -> BoneMap:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	bm.set_skeleton_bone_name("Root", root_name)
	for k in MAP:
		bm.set_skeleton_bone_name(k, MAP[k])
	for side in [["Left", "l"], ["Right", "r"]]:
		for f in FINGERS:
			var segs := ["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"]
			for i in 3:
				bm.set_skeleton_bone_name("%s%s%s" % [side[0], f, segs[i]], "%s_0%d_%s" % [FINGERS[f], i + 1, side[1]])
	return bm
func _init():
	ResourceSaver.save(build("root"), "res://assets/retarget/ual_bonemap.tres")
	ResourceSaver.save(build("Root"), "res://assets/retarget/mh_bonemap.tres")
	print("bonemaps ok"); quit()
