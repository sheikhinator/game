class_name MainMenu
extends Control
## Title screen over a slow aerial flyover of Port Calder.

var _list: VBoxContainer
var _panel: Control
var _panel_title: Label
var _panel_body: Control
var _settings: SettingsPanel
var _saves: SavesPanel
var _logo_block: Control
var _t := 0.0


func _ready() -> void:
	UIKit.full_rect(self)

	# Cinematic grade: left-side shade for legibility plus a soft vignette.
	add_child(_gradient(Vector2(0, 0), Vector2(1, 0), Color(0, 0, 0, 0.78), Color(0, 0, 0, 0), 0.0, 0.0, 0.6, 1.0))
	add_child(_gradient(Vector2(0, 1), Vector2(0, 0), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0), 0.0, 0.62, 1.0, 1.0))

	_logo_block = VBoxContainer.new()
	_logo_block.position = Vector2(110, 120)
	_logo_block.add_theme_constant_override("separation", 0)
	add_child(_logo_block)
	var logo := UIKit.label("LYCHO", 196, UIKit.INK, true, 700, 22)
	logo.add_theme_constant_override("line_spacing", -30)
	_logo_block.add_child(logo)
	var rule := ColorRect.new()
	rule.color = UIKit.ACCENT
	rule.custom_minimum_size = Vector2(96, 6)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_logo_block.add_child(rule)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 18)
	_logo_block.add_child(sp)
	_logo_block.add_child(UIKit.label("PORT CALDER", 26, UIKit.SUB, false, 600, 12))

	_list = VBoxContainer.new()
	_list.anchor_top = 1.0
	_list.anchor_bottom = 1.0
	_list.offset_left = 80
	_list.offset_right = 700
	_list.offset_bottom = -110
	_list.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	var items := []
	if Game.latest_save_slot() >= 0:
		items.append(["CONTINUE", func(): Game.continue_game()])
	items.append(["NEW GAME", func(): Game.start_new_game()])
	items.append(["LOAD GAME", func(): _open_panel("LOAD GAME", _saves_panel())])
	items.append(["SETTINGS", func(): _open_panel("SETTINGS", _settings_panel())])
	items.append(["QUIT", func(): get_tree().quit()])
	for it in items:
		var b := UIKit.menu_button(it[0], 44, 92)
		b.pressed.connect(it[1])
		_list.add_child(b)

	var foot := HBoxContainer.new()
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.anchor_right = 1.0
	foot.offset_left = 110
	foot.offset_right = -70
	foot.offset_top = -72
	foot.offset_bottom = -36
	add_child(foot)
	foot.add_child(UIKit.label("A LIFE SIMULATOR", 20, UIKit.FAINT, false, 600, 6))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(grow)
	foot.add_child(UIKit.label("v%s" % ProjectSettings.get_setting("application/config/version", "dev"), 20, UIKit.FAINT, false, 500, 2))

	_build_panel()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)


func _gradient(from: Vector2, to: Vector2, c0: Color, c1: Color, l: float, t: float, r: float, b: float) -> TextureRect:
	var tr := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	gt.gradient = g
	gt.fill_from = from
	gt.fill_to = to
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.anchor_left = l
	tr.anchor_top = t
	tr.anchor_right = r
	tr.anchor_bottom = b
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _build_panel() -> void:
	_panel = Control.new()
	UIKit.full_rect(_panel)
	_panel.visible = false
	add_child(_panel)
	var bg := UIKit.frosted(Color(0.02, 0.025, 0.035, 0.6))
	UIKit.full_rect(bg)
	_panel.add_child(bg)
	var v := VBoxContainer.new()
	UIKit.full_rect(v)
	v.offset_left = 110
	v.offset_right = -110
	v.offset_top = 80
	v.offset_bottom = -60
	v.add_theme_constant_override("separation", 26)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_panel_title = UIKit.label("", 64, UIKit.INK, true, 600, 8)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_panel_title)
	var back := UIKit.pill_button("BACK")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_panel)
	head.add_child(back)
	_panel_body = Control.new()
	_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_panel_body)


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
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	_list.visible = false
	_logo_block.visible = false


func _close_panel() -> void:
	_panel.visible = false
	_list.visible = true
	_logo_block.visible = true
