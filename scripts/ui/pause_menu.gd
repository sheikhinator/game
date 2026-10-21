class_name PauseMenu
extends Control
## Full-screen pause menu with GTA V style tabs: Map, Brief, Stats, Settings, Game.

signal opened
signal closed

var city: CityBuilder
var player: Player

var _tabs := {}
var _pages := {}
var _header_info: Label
var _content: Control
var _saves: SavesPanel
var _game_list: VBoxContainer
var _stats_label: Label
var _map: MapView


func setup(c: CityBuilder, p: Player) -> void:
	city = c
	player = p
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIKit.full_rect(self)
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.88)
	UIKit.full_rect(shade)
	add_child(shade)

	var root := VBoxContainer.new()
	UIKit.full_rect(root)
	root.offset_left = 70
	root.offset_right = -70
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# Header: title left, status right, close button.
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UIKit.label("LYCHO", 76, UIKit.ACCENT, true)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_header_info = UIKit.label("", 32, UIKit.TEXT, true)
	header.add_child(_header_info)
	var close := UIKit.menu_button("  RESUME  ", 32, 76)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(close_menu)
	header.add_child(close)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	root.add_child(tab_row)
	for t in ["MAP", "BRIEF", "STATS", "SETTINGS", "GAME"]:
		var b := UIKit.tab_button(t)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t))
		tab_row.add_child(b)
		_tabs[t] = b

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, 0))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(frame)
	_content = Control.new()
	frame.add_child(_content)

	_pages.MAP = _make_map()
	_pages.BRIEF = _make_brief()
	_pages.STATS = _make_stats()
	var settings := SettingsPanel.new()
	_pages.SETTINGS = settings
	_pages.GAME = _make_game()
	for k in _pages:
		UIKit.full_rect(_pages[k])
		_content.add_child(_pages[k])
	show_tab("MAP")


func open_menu() -> void:
	visible = true
	get_tree().paused = true
	opened.emit()
	_map.center = Vector2(player.global_position.x, player.global_position.z)
	_refresh()


func close_menu() -> void:
	visible = false
	get_tree().paused = false
	_show_game_list()
	closed.emit()


func show_tab(t: String) -> void:
	for k in _tabs:
		_tabs[k].button_pressed = (k == t)
		_pages[k].visible = (k == t)
	_refresh()


func _refresh() -> void:
	_header_info.text = "DAY %d   %s   $%s     " % [Game.state.day, Game.clock_string(Game.state.time_of_day), Game.format_money(Game.state.money)]
	var t: float = Game.state.play_time
	_stats_label.text = "\n".join([
		"Time played:            %dh %02dm" % [int(t / 3600.0), int(fmod(t, 3600.0) / 60.0)],
		"Days survived:          %d" % Game.state.day,
		"Distance on foot:       %.2f km" % (Game.state.distance_walked / 1000.0),
		"Cash:                   $%s" % Game.format_money(Game.state.money),
		"Health:                 %d%%" % int(Game.state.health),
		"Story progress:         0%",
	])


func _make_map() -> Control:
	_map = MapView.new()
	_map.minimap = false
	_map.city = city
	_map.player = player
	_map.pixels_per_meter = 2.2
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	return _map


func _make_brief() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	m.add_child(v)
	v.add_child(UIKit.label("CURRENT OBJECTIVE", 36, UIKit.ACCENT, true))
	var o := UIKit.label("Explore downtown Port Calder and get to know the streets. Your story begins soon.", 32)
	o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(o)
	v.add_child(UIKit.label("RECENT", 36, UIKit.ACCENT, true))
	var r := UIKit.label("Uncle Ray: Kid, the room above the garage is yours. Rent's due Friday.", 30, UIKit.MUTED)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(r)
	return m


func _make_stats() -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	_stats_label = UIKit.label("", 34)
	m.add_child(_stats_label)
	return m


func _make_game() -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 30)
	var stack := Control.new()
	m.add_child(stack)
	_game_list = VBoxContainer.new()
	_game_list.add_theme_constant_override("separation", 10)
	UIKit.full_rect(_game_list)
	stack.add_child(_game_list)
	var items := [
		["SAVE GAME", func(): _show_saves(true)],
		["LOAD GAME", func(): _show_saves(false)],
		["NEW GAME", func(): Game.start_new_game()],
		["QUIT TO TITLE", func(): Game.start_title()],
	]
	for it in items:
		var b := UIKit.menu_button("   " + it[0])
		b.pressed.connect(it[1])
		_game_list.add_child(b)
	_saves = SavesPanel.new()
	UIKit.full_rect(_saves)
	_saves.visible = false
	_saves.saved.connect(func(_i): _show_game_list())
	stack.add_child(_saves)
	return m


func _show_saves(save: bool) -> void:
	_saves.save_mode = save
	_saves.refresh()
	_saves.visible = true
	_game_list.visible = false


func _show_game_list() -> void:
	if _saves:
		_saves.visible = false
		_game_list.visible = true
