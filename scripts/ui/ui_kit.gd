class_name UIKit
extends RefCounted
## Lycho design system: Oswald display type, Inter text, near-black glass,
## one warm amber accent, GTA-green money. Every menu and HUD element uses this.

const INK := Color(0.957, 0.957, 0.945)
const SUB := Color(0.66, 0.68, 0.72)
const FAINT := Color(1, 1, 1, 0.38)
const ACCENT := Color(0.98, 0.74, 0.24)
const MONEY := Color(0.46, 0.80, 0.40)
const HEALTH := Color(0.38, 0.72, 0.34)
const STAMINA := Color(0.36, 0.62, 0.92)
const GLASS := Color(0.035, 0.04, 0.05, 0.84)
const GLASS_LIGHT := Color(1, 1, 1, 0.06)
const LINE := Color(1, 1, 1, 0.1)

# Kept for older call sites.
const TEXT := INK
const MUTED := SUB
const PANEL := GLASS
const ROW := GLASS_LIGHT

static var _fonts := {}


static func display(weight := 600, tracking := 0) -> Font:
	return _font("res://assets/fonts/Oswald.ttf", weight, tracking)


static func text(weight := 450, tracking := 0) -> Font:
	return _font("res://assets/fonts/Inter.ttf", weight, tracking)


static func _font(path: String, weight: int, tracking: int) -> Font:
	var key := "%s|%d|%d" % [path, weight, tracking]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		fv.spacing_glyph = tracking
		_fonts[key] = fv
	return _fonts[key]


# Back-compat helpers.
static func heading_font() -> Font:
	return display(600, 1)


static func body_font() -> Font:
	return text(450)


static func box(color: Color, radius := 6, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Text label. kind: "display" (Oswald) or "text" (Inter).
static func label(t: String, size := 28, color := INK, heading := false, weight := -1, tracking := -1) -> Label:
	var l := Label.new()
	l.text = t
	var f: Font
	if heading:
		f = display(weight if weight > 0 else 600, tracking if tracking >= 0 else 1)
	else:
		f = text(weight if weight > 0 else 450, tracking if tracking >= 0 else 0)
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 3)
	return l


## Primary menu entry: text only at rest; on hover/press a soft glass row
## with an amber edge bar, like a premium console menu.
static func menu_button(t: String, size := 34, min_h := 84) -> Button:
	var b := Button.new()
	b.text = t.strip_edges()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", display(500, 3))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0)
	rest.content_margin_left = 30
	rest.content_margin_right = 24
	var hot := StyleBoxFlat.new()
	hot.bg_color = Color(1, 1, 1, 0.07)
	hot.border_width_left = 5
	hot.border_color = ACCENT
	hot.content_margin_left = 30
	hot.content_margin_right = 24
	hot.corner_radius_top_right = 4
	hot.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("hover_pressed", hot)
	b.add_theme_stylebox_override("disabled", rest)
	return b


## Pill button for secondary actions (Back, Resume).
static func pill_button(t: String, size := 24) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 64)
	b.add_theme_font_override("font", display(500, 3))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.BLACK)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	var n := box(Color(1, 1, 1, 0.0), 32, 2, Color(1, 1, 1, 0.35))
	var h := box(INK, 32, 2, INK)
	var p := box(ACCENT, 32, 2, ACCENT)
	for s in [n, h, p]:
		s.content_margin_top = 8
		s.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	return b


## Text tab with an amber underline when active.
static func tab_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 70)
	b.add_theme_font_override("font", display(500, 4))
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", SUB)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0)
	rest.border_width_bottom = 2
	rest.border_color = LINE
	var on := StyleBoxFlat.new()
	on.bg_color = Color(1, 1, 1, 0.04)
	on.border_width_bottom = 4
	on.border_color = ACCENT
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", rest)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Frosted-glass backdrop that blurs whatever is behind it.
static func frosted(tint := Color(0.02, 0.025, 0.035, 0.72), blur := 3.5) -> ColorRect:
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/frosted.gdshader")
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("blur", blur)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r
