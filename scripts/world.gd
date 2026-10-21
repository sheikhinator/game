extends Node3D
## Root of the playable world. Builds the city, sky and either the title-screen
## flyover (Game.menu_mode) or the player with HUD, touch controls and pause menu.

var city: CityBuilder
var day_night: DayNight
var player: Player
var hud: HUD
var touch: TouchControls
var pause_menu: PauseMenu
var _menu_cam: Camera3D
var _menu_t := 0.0


func _ready() -> void:
	day_night = DayNight.new()
	add_child(day_night)
	city = CityBuilder.new()
	city.name = "City"
	add_child(city)
	city.build()
	day_night.lamps = city.lamp_lights
	if Game.menu_mode:
		_setup_title()
	else:
		_setup_play()


func _setup_title() -> void:
	day_night.time_scale = 3.0
	if not "--time=" in " ".join(OS.get_cmdline_user_args()):
		Game.state.time_of_day = 17.6
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 55.0
	_menu_cam.far = 1200.0
	add_child(_menu_cam)
	_menu_cam.current = true
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	ui.add_child(MainMenu.new())
	_update_menu_cam(0.0)


func _setup_play() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	if Game.state.player_pos is Array and Game.state.player_pos.size() == 3:
		var p: Array = Game.state.player_pos
		player.set_spawn(Vector3(p[0], p[1], p[2]), float(Game.state.player_yaw))
	else:
		player.set_spawn(city.spawn_point(), PI * 0.5)

	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud = HUD.new()
	ui.add_child(hud)
	hud.setup(city, player)
	touch = TouchControls.new()
	touch.player = player
	ui.add_child(touch)

	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	pause_menu = PauseMenu.new()
	menu_layer.add_child(pause_menu)
	pause_menu.setup(city, player)
	touch.pause_pressed.connect(pause_menu.open_menu)
	pause_menu.opened.connect(func(): ui.visible = false)
	pause_menu.closed.connect(func(): ui.visible = true)


func _unhandled_input(event: InputEvent) -> void:
	if pause_menu and event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.close_menu()
		else:
			pause_menu.open_menu()


func _notification(what: int) -> void:
	# Android back button / app sent to background opens the pause menu.
	if pause_menu and (what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED):
		if not pause_menu.visible:
			pause_menu.open_menu()


func _process(delta: float) -> void:
	if _menu_cam:
		_menu_t += delta
		_update_menu_cam(_menu_t)


func _update_menu_cam(t: float) -> void:
	# Slow orbit around the middle of downtown, low enough to feel the streets.
	var b := city.bounds()
	var c := Vector3(b.get_center().x, 0, b.get_center().y)
	var ang := t * 0.035 + 0.6
	var radius := 120.0
	var pos := c + Vector3(cos(ang) * radius, 46.0, sin(ang) * radius)
	_menu_cam.global_position = pos
	_menu_cam.look_at(c + Vector3(0, 12, 0), Vector3.UP)
