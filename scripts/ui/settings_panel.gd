class_name SettingsPanel
extends ScrollContainer
## GTA-style settings list: each row shows "< value >" and cycles on tap.

const ROWS := [
	{"key": "graphics", "label": "Graphics Quality", "options": ["Low", "Medium", "High", "Ultra"]},
	{"key": "fps", "label": "Frame Rate Limit", "options": [30, 60, 90, 120]},
	{"key": "cam_sensitivity", "label": "Camera Sensitivity", "options": [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]},
	{"key": "invert_y", "label": "Invert Look", "options": [false, true]},
	{"key": "show_hud", "label": "Show HUD", "options": [true, false]},
	{"key": "button_scale", "label": "Touch Button Size", "options": [0.8, 1.0, 1.2, 1.4]},
	{"key": "day_minutes", "label": "Length of a Day", "options": [24.0, 48.0, 72.0, 96.0]},
	{"key": "master_volume", "label": "Master Volume", "options": [0.0, 0.25, 0.5, 0.75, 1.0]},
]

var _list: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for row in ROWS:
		_list.add_child(_make_row(row))


func _display(key: String, v) -> String:
	match key:
		"fps":
			return "%d FPS" % v
		"invert_y", "show_hud":
			return "On" if v else "Off"
		"cam_sensitivity", "button_scale":
			return "%d%%" % int(round(float(v) * 100.0))
		"day_minutes":
			return "%d min" % int(v)
		"master_volume":
			return "%d%%" % int(round(float(v) * 100.0))
	return str(v)


func _make_row(row: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 86)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UIKit.box(UIKit.ROW, 4))
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := HBoxContainer.new()
	bg.add_child(inner)
	var name := UIKit.label(row.label, 32)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(name)
	var left := _arrow("<")
	var value := UIKit.label(_display(row.key, Game.settings[row.key]), 32, UIKit.ACCENT, true)
	value.custom_minimum_size = Vector2(220, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right := _arrow(">")
	inner.add_child(left)
	inner.add_child(value)
	inner.add_child(right)
	h.add_child(bg)
	var step := func(dir: int):
		var opts: Array = row.options
		var idx := opts.find(Game.settings[row.key])
		if idx < 0:
			idx = 0
		idx = wrapi(idx + dir, 0, opts.size())
		Game.set_setting(row.key, opts[idx])
		value.text = _display(row.key, opts[idx])
	left.pressed.connect(step.bind(-1))
	right.pressed.connect(step.bind(1))
	return h


func _arrow(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 70)
	b.add_theme_font_override("font", UIKit.heading_font())
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0.0), 4))
	b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.12), 4))
	b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.ACCENT, 4))
	return b
