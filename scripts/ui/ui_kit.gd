class_name UIKit
extends RefCounted
## Shared look for Lycho's menus: dark glass panels, white type, gold accent.

const ACCENT := Color(0.95, 0.71, 0.2)
const MONEY := Color(0.45, 0.82, 0.38)
const TEXT := Color(0.96, 0.96, 0.96)
const MUTED := Color(0.72, 0.74, 0.78)
const PANEL := Color(0.03, 0.035, 0.05, 0.86)
const ROW := Color(1, 1, 1, 0.06)
const ROW_HOVER := Color(1, 1, 1, 0.16)

static var _heading_font: Font
static var _body_font: Font


static func heading_font() -> Font:
	if _heading_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Oswald", "Bebas Neue", "Roboto Condensed", "Arial Narrow", "sans-serif-condensed", "sans-serif"])
		f.font_weight = 800
		f.font_stretch = 75
		_heading_font = f
	return _heading_font


static func body_font() -> Font:
	if _body_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Roboto", "Inter", "Helvetica", "sans-serif"])
		f.font_weight = 500
		_body_font = f
	return _body_font


static func box(color: Color, radius := 6, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func label(text: String, size := 30, color := TEXT, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", heading_font() if heading else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6 if heading else 0)
	return l


## A big, touch-friendly menu row (GTA list style: left aligned, highlight on press).
static func menu_button(text: String, size := 34, min_h := 84) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", heading_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.BLACK)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.add_theme_stylebox_override("normal", box(ROW, 4))
	b.add_theme_stylebox_override("hover", box(TEXT, 4))
	b.add_theme_stylebox_override("pressed", box(ACCENT, 4))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.03), 4))
	return b


static func tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 76)
	b.add_theme_font_override("font", heading_font())
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
	var normal := box(Color(0, 0, 0, 0.55), 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", box(Color(0.15, 0.15, 0.18, 0.8), 0))
	b.add_theme_stylebox_override("pressed", box(TEXT, 0))
	b.add_theme_stylebox_override("hover_pressed", box(TEXT, 0))
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
