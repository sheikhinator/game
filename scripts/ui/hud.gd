class_name HUD
extends Control
## GTA-style heads-up display: minimap with health and stamina bars,
## clock and money top right, help box top left.

var minimap: MapView
var clock_label: Label
var money_label: Label
var help_box: PanelContainer
var help_label: Label
var _bars: Control
var _help_timer := 0.0


func setup(city: CityBuilder, player: Player) -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	minimap = MapView.new()
	minimap.city = city
	minimap.player = player
	minimap.minimap = true
	minimap.pixels_per_meter = 1.5
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.position = Vector2(40, -330)
	minimap.size = Vector2(380, 240)
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_top = -330
	minimap.offset_bottom = -90
	minimap.offset_left = 40
	minimap.offset_right = 420
	add_child(minimap)

	_bars = Control.new()
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.anchor_top = 1.0
	_bars.anchor_bottom = 1.0
	_bars.offset_left = 40
	_bars.offset_right = 420
	_bars.offset_top = -82
	_bars.offset_bottom = -64
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	var top_right := VBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -520
	top_right.offset_right = -150
	top_right.offset_top = 26
	top_right.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_right)
	clock_label = UIKit.label("08:30", 44, UIKit.TEXT, true)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(clock_label)
	money_label = UIKit.label("$500", 52, UIKit.MONEY, true)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(money_label)

	help_box = PanelContainer.new()
	help_box.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.72), 6))
	help_box.position = Vector2(40, 36)
	help_box.custom_minimum_size = Vector2(560, 0)
	help_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_box)
	help_label = UIKit.label("", 28)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size = Vector2(520, 0)
	help_box.add_child(help_label)
	show_help("Welcome to Port Calder. Left thumb to move, drag right side to look. Tap ≡ for the menu.", 9.0)

	Game.settings_changed.connect(_apply_visibility)
	_apply_visibility()


func show_help(text: String, seconds := 6.0) -> void:
	help_label.text = text
	help_box.visible = true
	help_box.modulate.a = 1.0
	_help_timer = seconds


func _apply_visibility() -> void:
	var show: bool = Game.settings.show_hud
	minimap.visible = show
	_bars.visible = show
	clock_label.get_parent().visible = show


func _process(delta: float) -> void:
	clock_label.text = Game.clock_string(Game.state.time_of_day)
	money_label.text = "$" + Game.format_money(Game.state.money)
	_bars.queue_redraw()
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer < 0.6:
			help_box.modulate.a = maxf(_help_timer / 0.6, 0.0)
		if _help_timer <= 0.0:
			help_box.visible = false


func _draw_bars() -> void:
	var w := _bars.size.x
	var gap := 8.0
	var half := (w - gap) * 0.5
	var h := _bars.size.y
	var health: float = Game.state.health / 100.0
	var stamina: float = Game.state.stamina / 100.0
	_bars.draw_rect(Rect2(0, 0, half, h), Color(0.12, 0.25, 0.12, 0.85))
	_bars.draw_rect(Rect2(0, 0, half * health, h), Color(0.36, 0.72, 0.32))
	_bars.draw_rect(Rect2(half + gap, 0, half, h), Color(0.1, 0.2, 0.3, 0.85))
	_bars.draw_rect(Rect2(half + gap, 0, half * stamina, h), Color(0.35, 0.6, 0.9))
