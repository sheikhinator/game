extends Node
## Global game state, settings and save/load. Autoloaded as `Game`.

signal settings_changed
signal money_changed(amount: int)

const SAVE_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.json"
const SAVE_SLOTS := 15
const WORLD_SCENE := "res://scenes/world.tscn"

const GRAPHICS_PRESETS := ["Low", "Medium", "High", "Ultra"]
const FPS_OPTIONS := [30, 60, 90, 120]

var settings := {
	"graphics": "High",
	"fps": 60,
	"cam_sensitivity": 1.0,
	"invert_y": false,
	"show_hud": true,
	"day_minutes": 48.0,
	"button_scale": 1.0,
	"master_volume": 1.0,
}

var state := {}
## True while the title screen is showing over the live city.
var menu_mode := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_settings()
	new_state()
	# Developer switches for automated previews: -- --play --time=20 --graphics=Ultra
	for arg in OS.get_cmdline_user_args():
		if arg == "--play":
			menu_mode = false
		elif arg.begins_with("--time="):
			state.time_of_day = float(arg.get_slice("=", 1))
		elif arg.begins_with("--graphics="):
			settings.graphics = arg.get_slice("=", 1)
		elif arg.begins_with("--shot="):
			_shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--frames="):
			_shot_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--pause-menu="):
			_shot_menu_tab = arg.get_slice("=", 1)


var _shot_path := ""
var _shot_frames := 120
var _shot_menu_tab := ""


func _physics_process(_d: float) -> void:
	if _shot_path.is_empty():
		return
	_shot_frames -= 1
	if _shot_frames == 20 and not _shot_menu_tab.is_empty():
		var pm = get_tree().current_scene.get("pause_menu")
		if pm:
			pm.open_menu()
			pm.show_tab(_shot_menu_tab)
	if _shot_frames == 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("SAVED ", _shot_path)
		get_tree().quit()


func new_state() -> void:
	state = {
		"money": 500,
		"health": 100.0,
		"stamina": 100.0,
		"time_of_day": 8.5,
		"day": 1,
		"player_pos": null,
		"player_yaw": 0.0,
		"play_time": 0.0,
		"distance_walked": 0.0,
		"appearance": {
			"body": "male",
			"skin": "light",
			"hair": "Hair_SimpleParted",
			"beard": true,
			"hair_color": Color(0.17, 0.11, 0.08).to_html(),
			"shirt_color": Color(0.16, 0.2, 0.28).to_html(),
			"pants_color": Color(0.32, 0.38, 0.5).to_html(),
			"shoe_color": Color(0.92, 0.92, 0.9).to_html(),
		},
	}


func _process(delta: float) -> void:
	if menu_mode or get_tree().paused:
		return
	state.play_time += delta


# ---------------------------------------------------------------- flow

func start_title() -> void:
	menu_mode = true
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


func start_new_game() -> void:
	new_state()
	menu_mode = false
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


func continue_game() -> void:
	var latest := latest_save_slot()
	if latest >= 0:
		load_game(latest)
	else:
		start_new_game()


func add_money(amount: int) -> void:
	state.money += amount
	money_changed.emit(state.money)


# ---------------------------------------------------------------- saves

func _slot_path(slot: int) -> String:
	return "%s/slot_%02d.json" % [SAVE_DIR, slot]


func save_game(slot: int) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		state.player_pos = [player.global_position.x, player.global_position.y, player.global_position.z]
		state.player_yaw = player.get("yaw")
	var data := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"state": state,
	}
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


func load_game(slot: int) -> bool:
	var info := read_save(slot)
	if info.is_empty():
		return false
	new_state()
	var loaded: Dictionary = info.state
	for k in loaded:
		state[k] = loaded[k]
	menu_mode = false
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)
	return true


func read_save(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_slot_path(slot)):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	return parsed if parsed is Dictionary else {}


func delete_save(slot: int) -> void:
	DirAccess.remove_absolute(_slot_path(slot))


func latest_save_slot() -> int:
	var best := -1
	var best_time := ""
	for i in SAVE_SLOTS:
		var info := read_save(i)
		if info.is_empty():
			continue
		if info.saved_at > best_time:
			best_time = info.saved_at
			best = i
	return best


func describe_save(slot: int) -> String:
	var info := read_save(slot)
	if info.is_empty():
		return "Empty slot"
	var s: Dictionary = info.state
	return "Day %d  %s   $%s   %s" % [s.day, clock_string(s.time_of_day), format_money(s.money), str(info.saved_at).replace("T", " ").left(16)]


# ---------------------------------------------------------------- settings

func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
	if key == "fps":
		apply_fps()
	if key == "master_volume":
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))
	settings_changed.emit()


func apply_fps() -> void:
	Engine.max_fps = int(settings.fps)


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			for k in parsed:
				if settings.has(k):
					settings[k] = parsed[k]
	apply_fps()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))


# ---------------------------------------------------------------- formatting

static func clock_string(t: float) -> String:
	var h := int(t) % 24
	var m := int((t - floorf(t)) * 60.0)
	return "%02d:%02d" % [h, m]


static func format_money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out
