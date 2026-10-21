class_name MainMenu
extends Control
## Title screen over a slow aerial flyover of the city.

var _list: VBoxContainer
var _panel_holder: PanelContainer
var _panel_title: Label
var _panel_body: Control
var _settings: SettingsPanel
var _saves: SavesPanel


func _ready() -> void:
	UIKit.full_rect(self)

	# Soft dark gradient on the left so the menu reads over the city.
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.82))
	g.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.anchor_bottom = 1.0
	grad.anchor_right = 0.62
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)

	var col := VBoxContainer.new()
	col.anchor_bottom = 1.0
	col.offset_left = 90
	col.offset_top = 70
	col.offset_right = 760
	col.offset_bottom = -60
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var logo := UIKit.label("LYCHO", 190, UIKit.ACCENT, true)
	logo.add_theme_constant_override("outline_size", 14)
	col.add_child(logo)
	var sub := UIKit.label("A LIFE IN PORT CALDER", 38, UIKit.TEXT, true)
	col.add_child(sub)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(space)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	var has_save := Game.latest_save_slot() >= 0
	var items := []
	if has_save:
		items.append(["CONTINUE", func(): Game.continue_game()])
	items.append(["NEW GAME", func(): Game.start_new_game()])
	items.append(["LOAD GAME", func(): _open_panel("LOAD GAME", _saves_panel())])
	items.append(["SETTINGS", func(): _open_panel("SETTINGS", _settings_panel())])
	items.append(["QUIT", func(): get_tree().quit()])
	for it in items:
		var b := UIKit.menu_button("   " + it[0], 40, 92)
		b.custom_minimum_size.x = 560
		b.pressed.connect(it[1])
		_list.add_child(b)

	var ver := UIKit.label("Milestone 1  ·  build %s" % ProjectSettings.get_setting("application/config/version", "dev"), 22, UIKit.MUTED)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -520
	ver.offset_right = -40
	ver.offset_top = -60
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)

	# Right-hand panel for Load / Settings.
	_panel_holder = PanelContainer.new()
	_panel_holder.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, 8))
	_panel_holder.anchor_left = 0.42
	_panel_holder.anchor_right = 1.0
	_panel_holder.anchor_bottom = 1.0
	_panel_holder.offset_left = 0
	_panel_holder.offset_right = -70
	_panel_holder.offset_top = 70
	_panel_holder.offset_bottom = -100
	_panel_holder.visible = false
	add_child(_panel_holder)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	_panel_holder.add_child(pv)
	var ph := HBoxContainer.new()
	pv.add_child(ph)
	_panel_title = UIKit.label("", 46, UIKit.ACCENT, true)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(_panel_title)
	var back := UIKit.menu_button("  BACK  ", 30, 70)
	back.pressed.connect(func(): _panel_holder.visible = false)
	ph.add_child(back)
	_panel_body = Control.new()
	_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(_panel_body)


func _settings_panel() -> Control:
	if _settings == null:
		_settings = SettingsPanel.new()
		UIKit.full_rect(_settings)
		_panel_body.add_child(_settings)
	return _settings


func _saves_panel() -> Control:
	if _saves == null:
		_saves = SavesPanel.new()
		_saves.save_mode = false
		UIKit.full_rect(_saves)
		_panel_body.add_child(_saves)
	_saves.refresh()
	return _saves


func _open_panel(title: String, panel: Control) -> void:
	_panel_title.text = title
	for c in _panel_body.get_children():
		c.visible = (c == panel)
	_panel_holder.visible = true
