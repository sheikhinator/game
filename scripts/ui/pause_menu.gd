class_name PauseMenu
extends Control
## Pause menu: frosted backdrop, header with player status, text tabs
## (Map, Brief, Stats, Settings, Game) and a footer with the Resume pill.

signal opened
signal closed

var city: CityBuilder
var player: Player

var _tabs := {}
var _pages := {}
var _status_time: Label
var _status_cash: Label
var _saves: SavesPanel
var _game_list: VBoxContainer
var _stats_grid: GridContainer
var _map: MapView
var _body: Control
var _hint: Label


func setup(c: CityBuilder, p: Player) -> void:
	city = c
	player = p
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIKit.full_rect(self)
	visible = false

	add_child(UIKit.full_rect(UIKit.frosted()))

	_body = VBoxContainer.new()
	UIKit.full_rect(_body)
	_body.offset_left = 96
	_body.offset_right = -96
	_body.offset_top = 56
	_body.offset_bottom = -44
	_body.add_theme_constant_override("separation", 22)
	add_child(_body)

	# Header.
	var header := HBoxContainer.new()
	_body.add_child(header)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	header.add_child(brand)
	brand.add_child(UIKit.label("LYCHO", 60, UIKit.INK, true, 700, 12))
	var rule := ColorRect.new()
	rule.color = UIKit.ACCENT
	rule.custom_minimum_size = Vector2(56, 4)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	brand.add_child(rule)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(grow)
	var status := VBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 0)
	header.add_child(status)
	_status_time = UIKit.label("", 26, UIKit.SUB, false, 500, 1)
	_status_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_status_time)
	_status_cash = UIKit.label("", 44, UIKit.MONEY, true, 600, 1)
	_status_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_status_cash)

	# Tabs.
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	_body.add_child(tab_row)
	for t in ["MAP", "BRIEF", "STATS", "SETTINGS", "GAME"]:
		var b := UIKit.tab_button(t)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t))
		tab_row.add_child(b)
		_tabs[t] = b

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(content)

	# Footer.
	var foot := HBoxContainer.new()
	_body.add_child(foot)
	_hint = UIKit.label("", 20, UIKit.FAINT, false, 500, 1)
	var hint := _hint
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(hint)
	var resume := UIKit.pill_button("RESUME")
	resume.pressed.connect(close_menu)
	foot.add_child(resume)

	_pages.MAP = _make_map()
	_pages.BRIEF = _make_brief()
	_pages.STATS = _make_stats()
	_pages.SETTINGS = SettingsPanel.new()
	_pages.GAME = _make_game()
	for k in _pages:
		UIKit.full_rect(_pages[k])
		content.add_child(_pages[k])
	show_tab("MAP")


func open_menu() -> void:
	visible = true
	get_tree().paused = true
	_map.center = Vector2(player.global_position.x, player.global_position.z)
	_refresh()
	modulate.a = 0.0
	_body.offset_top = 74
	_body.offset_bottom = -26
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(_body, "offset_top", 56.0, 0.3)
	tw.tween_property(_body, "offset_bottom", -44.0, 0.3)
	opened.emit()


func close_menu() -> void:
	visible = false
	get_tree().paused = false
	_show_game_list()
	closed.emit()


func show_tab(t: String) -> void:
	for k in _tabs:
		_tabs[k].button_pressed = (k == t)
		_pages[k].visible = (k == t)
	_hint.text = {"MAP": "Drag to pan  ·  pinch to zoom", "SETTINGS": "Changes save automatically", "GAME": "15 save slots"}.get(t, "")
	_refresh()


func _refresh() -> void:
	_status_time.text = "DAY %d  ·  %s" % [Game.state.day, Game.clock_string(Game.state.time_of_day)]
	_status_cash.text = "$" + Game.format_money(Game.state.money)
	for c in _stats_grid.get_children():
		c.queue_free()
	var t: float = Game.state.play_time
	var rows := [
		["Time played", "%dh %02dm" % [int(t / 3600.0), int(fmod(t, 3600.0) / 60.0)]],
		["Days in Port Calder", str(Game.state.day)],
		["Distance on foot", "%.2f km" % (Game.state.distance_walked / 1000.0)],
		["Cash", "$" + Game.format_money(Game.state.money)],
		["Health", "%d%%" % int(Game.state.health)],
		["Story progress", "0%"],
	]
	for r in rows:
		_stats_grid.add_child(_stat_tile(r[0], r[1]))


func _stat_tile(name: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(1, 1, 1, 0.045), 6))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 150)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UIKit.label(name.to_upper(), 20, UIKit.SUB, false, 600, 3))
	v.add_child(UIKit.label(value, 52, UIKit.INK, true, 500, 1))
	return p


func _make_map() -> Control:
	var frame := PanelContainer.new()
	var sb := UIKit.box(Color(0, 0, 0, 0), 8, 1, UIKit.LINE)
	sb.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_map = MapView.new()
	_map.minimap = false
	_map.city = city
	_map.player = player
	_map.pixels_per_meter = 2.2
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(_map)
	return frame


func _make_brief() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 30)
	m.add_child(v)
	v.add_child(UIKit.label("CURRENT OBJECTIVE", 22, UIKit.ACCENT, false, 700, 6))
	var o := UIKit.label("Explore downtown Port Calder and get to know the streets.", 40, UIKit.INK, false, 500)
	o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(o)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	v.add_child(UIKit.label("MESSAGES", 22, UIKit.ACCENT, false, 700, 6))
	v.add_child(_message("Uncle Ray", "Room above the garage is yours, kid. Rent's due Friday."))
	return m


func _message(from: String, body: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(1, 1, 1, 0.045), 6))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UIKit.label(from, 26, UIKit.INK, false, 700))
	var b := UIKit.label(body, 26, UIKit.SUB, false, 450)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return p


func _make_stats() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 30)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 3
	_stats_grid.add_theme_constant_override("h_separation", 16)
	_stats_grid.add_theme_constant_override("v_separation", 16)
	m.add_child(_stats_grid)
	return m


func _make_game() -> Control:
	var stack := Control.new()
	_game_list = VBoxContainer.new()
	_game_list.add_theme_constant_override("separation", 4)
	UIKit.full_rect(_game_list)
	_game_list.offset_top = 20
	stack.add_child(_game_list)
	var items := [
		["SAVE GAME", func(): _show_saves(true)],
		["LOAD GAME", func(): _show_saves(false)],
		["NEW GAME", func(): Game.start_new_game()],
		["QUIT TO TITLE", func(): Game.start_title()],
	]
	for it in items:
		var b := UIKit.menu_button(it[0], 40, 90)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size.x = 640
		b.pressed.connect(it[1])
		_game_list.add_child(b)
	_saves = SavesPanel.new()
	UIKit.full_rect(_saves)
	_saves.offset_top = 20
	_saves.visible = false
	_saves.saved.connect(func(_i): _show_game_list())
	stack.add_child(_saves)
	return stack


func _show_saves(save: bool) -> void:
	_saves.save_mode = save
	_saves.refresh()
	_saves.visible = true
	_game_list.visible = false


func _show_game_list() -> void:
	if _saves:
		_saves.visible = false
		_game_list.visible = true
