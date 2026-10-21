class_name HUD
extends Control
## In-game HUD: rounded minimap with health and stamina strips (bottom left),
## clock and cash (top right), contextual help card (top left).

var minimap: MapView
var clock_label: Label
var money_label: Label
var help_box: PanelContainer
var help_label: Label
var _map_frame: PanelContainer
var _bars: Control
var _top_right: VBoxContainer
var _help_timer := 0.0
var _shown_money := -1.0

const MAP_SIZE := Vector2(400, 250)


func setup(city: CityBuilder, player: Player) -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_map_frame = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 1)
	sb.set_corner_radius_all(14)
	sb.anti_aliasing = true
	_map_frame.add_theme_stylebox_override("panel", sb)
	_map_frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_map_frame.anchor_top = 1.0
	_map_frame.anchor_bottom = 1.0
	_map_frame.offset_left = 48
	_map_frame.offset_right = 48 + MAP_SIZE.x
	_map_frame.offset_top = -64 - MAP_SIZE.y
	_map_frame.offset_bottom = -64
	_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_frame)
	minimap = MapView.new()
	minimap.city = city
	minimap.player = player
	minimap.minimap = true
	minimap.pixels_per_meter = 1.45
	_map_frame.add_child(minimap)

	_bars = Control.new()
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.anchor_top = 1.0
	_bars.anchor_bottom = 1.0
	_bars.offset_left = 48
	_bars.offset_right = 48 + MAP_SIZE.x
	_bars.offset_top = -50
	_bars.offset_bottom = -42
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	_top_right = VBoxContainer.new()
	_top_right.anchor_left = 1.0
	_top_right.anchor_right = 1.0
	_top_right.offset_left = -560
	_top_right.offset_right = -170
	_top_right.offset_top = 34
	_top_right.add_theme_constant_override("separation", -6)
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_right)
	clock_label = UIKit.label("08:30", 34, UIKit.INK, true, 400, 3)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_right.add_child(clock_label)
	money_label = UIKit.label("$500", 56, UIKit.MONEY, true, 600, 1)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_right.add_child(money_label)

	help_box = PanelContainer.new()
	var hb := UIKit.box(Color(0.03, 0.035, 0.045, 0.78), 10)
	hb.border_width_left = 4
	hb.border_color = UIKit.ACCENT
	hb.content_margin_left = 26
	hb.content_margin_right = 26
	hb.content_margin_top = 18
	hb.content_margin_bottom = 18
	help_box.add_theme_stylebox_override("panel", hb)
	help_box.position = Vector2(48, 40)
	help_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_box)
	help_label = UIKit.label("", 26, UIKit.INK, false, 450)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size = Vector2(500, 0)
	help_box.add_child(help_label)
	show_help("Move with your left thumb. Drag anywhere on the right to look around.", 8.0)

	Game.settings_changed.connect(_apply_visibility)
	_apply_visibility()


func show_help(t: String, seconds := 6.0) -> void:
	help_label.text = t
	help_box.reset_size()
	help_box.visible = true
	help_box.modulate.a = 0.0
	create_tween().tween_property(help_box, "modulate:a", 1.0, 0.3)
	_help_timer = seconds


func _apply_visibility() -> void:
	var show: bool = Game.settings.show_hud
	_map_frame.visible = show
	_bars.visible = show
	_top_right.visible = show


func _process(delta: float) -> void:
	clock_label.text = Game.clock_string(Game.state.time_of_day)
	# Cash counts up/down smoothly like a till.
	var target := float(Game.state.money)
	if _shown_money < 0.0:
		_shown_money = target
	_shown_money = move_toward(_shown_money, target, maxf(absf(target - _shown_money) * 6.0 * delta, 1.0))
	money_label.text = "$" + Game.format_money(int(round(_shown_money)))
	_bars.queue_redraw()
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer < 0.5:
			help_box.modulate.a = maxf(_help_timer / 0.5, 0.0)
		if _help_timer <= 0.0:
			help_box.visible = false


func _draw_bars() -> void:
	var w := _bars.size.x
	var gap := 8.0
	var half := (w - gap) * 0.5
	var h := _bars.size.y
	var health: float = clampf(Game.state.health / 100.0, 0, 1)
	var stamina: float = clampf(Game.state.stamina / 100.0, 0, 1)
	_bars.draw_rect(Rect2(0, 0, half, h), Color(0, 0, 0, 0.55))
	_bars.draw_rect(Rect2(0, 0, half * health, h), UIKit.HEALTH)
	_bars.draw_rect(Rect2(half + gap, 0, half, h), Color(0, 0, 0, 0.55))
	_bars.draw_rect(Rect2(half + gap, 0, half * stamina, h), UIKit.STAMINA)
