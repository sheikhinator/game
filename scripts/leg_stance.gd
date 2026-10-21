class_name LegStance
extends SkeletonModifier3D
## Brings the legs in after retargeting: the source animations were authored
## for a broader, heroic stance than a realistic human uses.

@export var inward_deg := 5.5

var _l := -1
var _r := -1


func _ready() -> void:
	var sk := get_skeleton()
	if sk:
		_l = sk.find_bone("LeftUpperLeg")
		_r = sk.find_bone("RightUpperLeg")


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _l < 0 or _r < 0:
		return
	var a := deg_to_rad(inward_deg)
	for pair in [[_l, -a], [_r, a]]:
		var i: int = pair[0]
		var p := sk.get_bone_global_pose(i)
		p.basis = Basis(Vector3.BACK, pair[1]) * p.basis
		sk.set_bone_global_pose(i, p)
