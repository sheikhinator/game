class_name SettingsPanel
extends ScrollContainer
## Settings grouped into sections. Each row: label left, "‹ value ›" right; tap either side to cycle.

const SECTIONS := [
	["DISPLAY", [
		{"key": "graphics", "label": "Graphics quality", "hint": "Higher looks better and uses more battery", "options": ["Low", "Medium", "High", "Ultra"]},
		{"key": "fps", "label": "Frame rate limit", "hint": "", "options": [30, 60, 90, 120]},
		{"key": "show_hud", "label": "Show HUD", "hint": "", "options": [true, false]},
	]],
	["CONTROLS", [
		{"key": "cam_sensitivity", "label": "Camera sensitivity", "hint": "", "options": [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]},
		{"key": "invert_y", "label": "Invert look", "hint": "", "options": [false, true]},
		{"key": "button_scale", "label": "Touch button size", "hint": "", "options": [0.8, 1.0, 1.2, 1.4]},
	]],
	["GAMEPLAY", [
		{"key": "day_minutes", "label": "Length of a day", "hint": "Real minutes per in-game day", "options": [24.0, 48.0, 72.0, 96.0]},
	]],
	["AUDIO", [
		{"key": "master_volume", "label": "Master volume", "hint": "", "options": [0.0, 0.25, 0.5, 0.75, 1.0]},
	]],
]

var _list: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 24)
	add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	margin.add_child(_list)
	for sec in SECTIONS:
		var h := UIKit.label(sec[0], 22, UIKit.ACCENT, false, 700, 6)
		h.custom_minimum_size = Vector2(0, 64)
		h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_list.add_child(h)
		var sep := ColorRect.new()
		sep.color = UIKit.LINE
		sep.custom_minimum_size = Vector2(0, 1)
		_list.add_child(sep)
		for row in sec[1]:
			_list.add_child(_make_row(row))


static func display(key: String, v) -> String:
	match key:
		"fps":
			return "%d FPS" % int(v)
		"invert_y", "show_hud":
			return "ON" if v else "OFF"
		"cam_sensitivity", "button_scale", "master_volume":
			return "%d%%" % int(round(float(v) * 100.0))
		"day_minutes":
			return "%d MIN" % int(v)
	return str(v).to_upper()


func _make_row(row: Dictionary) -> Control:
	var bg := PanelContainer.new()
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(1, 1, 1, 0.0)
	rest.border_width_bottom = 1
	rest.border_color = Color(1, 1, 1, 0.05)
	rest.content_margin_left = 8
	rest.content_margin_right = 8
	bg.add_theme_stylebox_override("panel", rest)
	bg.custom_minimum_size = Vector2(0, 96)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	bg.add_child(h)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)
	texts.add_child(UIKit.label(row.label, 30, UIKit.INK, false, 500))
	if row.hint != "":
		texts.add_child(UIKit.label(row.hint, 20, UIKit.SUB, false, 400))
	var left := _chevron("‹")
	var value := UIKit.label(display(row.key, Game.settings[row.key]), 32, UIKit.INK, true, 500, 3)
	value.custom_minimum_size = Vector2(200, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var right := _chevron("›")
	h.add_child(left)
	h.add_child(value)
	h.add_child(right)
	var step := func(dir: int):
		var opts: Array = row.options
		var idx := -1
		for i in opts.size():
			if _same(opts[i], Game.settings[row.key]):
				idx = i
		idx = wrapi(maxi(idx, 0) + dir, 0, opts.size())
		Game.set_setting(row.key, opts[idx])
		value.text = display(row.key, opts[idx])
		var tw := value.create_tween()
		value.modulate = UIKit.ACCENT
		tw.tween_property(value, "modulate", Color.WHITE, 0.35)
	left.pressed.connect(step.bind(-1))
	right.pressed.connect(step.bind(1))
	return bg


func _chevron(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(80, 80)
	b.add_theme_font_override("font", UIKit.text(300))
	b.add_theme_font_size_override("font_size", 56)
	b.add_theme_color_override("font_color", UIKit.SUB)
	b.add_theme_color_override("font_hover_color", UIKit.INK)
	b.add_theme_color_override("font_pressed_color", UIKit.ACCENT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	var p := StyleBoxFlat.new()
	p.bg_color = Color(1, 1, 1, 0.08)
	p.set_corner_radius_all(40)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", p)
	return b


static func _same(a, b) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in num and typeof(b) in num:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b
