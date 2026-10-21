extends SceneTree
# Usage: godot --path . -s tools/shot.gd -- <scene_or_script> <out.png> [frames] [WxH]
var frames := 30
var out := ""
func _init():
	var a := OS.get_cmdline_user_args()
	out = a[1]
	if a.size() > 2: frames = int(a[2])
	var target = a[0]
	if target.ends_with(".tscn"):
		root.add_child.call_deferred(load(target).instantiate())
	else:
		root.add_child.call_deferred(load(target).new())
func _process(_d):
	frames -= 1
	if frames == 0:
		var img = root.get_texture().get_image()
		img.save_png(out); print("SAVED ", out, " ", img.get_size()); quit()
	return false
