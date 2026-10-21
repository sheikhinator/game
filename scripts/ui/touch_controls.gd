class_name TouchControls
extends Control
## Floating left-thumb joystick, right-side camera drag, and action buttons.

signal pause_pressed

var player: Player

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _buttons := {}      # name -> {rect, held, index}

const STICK_RADIUS := 120.0


func _ready() -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	Game.settings_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s: float = float(Game.settings.button_scale)
	var w := size.x
	var h := size.y
	var r := 74.0 * s
	_buttons = {
		"jump": {"center": Vector2(w - 160 * s, h - 310 * s), "r": r, "held": false, "index": -1},
		"sprint": {"center": Vector2(w - 330 * s, h - 170 * s), "r": r, "held": false, "index": -1},
		"pause": {"center": Vector2(w - 96 * s, 84 * s), "r": 44 * s, "held": false, "index": -1},
	}
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for key in _buttons:
				var b: Dictionary = _buttons[key]
				if event.position.distance_to(b.center) <= b.r * 1.15:
					b.held = true
					b.index = event.index
					_on_button(key, true)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if event.position.x < size.x * 0.42 and _stick_index == -1:
				_stick_index = event.index
				_stick_origin = event.position
				_stick_pos = event.position
			elif _look_index == -1:
				_look_index = event.index
				_look_last = event.position
		else:
			for key in _buttons:
				var b: Dictionary = _buttons[key]
				if b.index == event.index:
					b.held = false
					b.index = -1
					_on_button(key, false)
			if event.index == _stick_index:
				_stick_index = -1
				player.move_input = Vector2.ZERO
			if event.index == _look_index:
				_look_index = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			_stick_pos = event.position
			var d: Vector2 = _stick_pos - _stick_origin
			if d.length() > STICK_RADIUS:
				# Let the base follow the thumb so it never runs out of room.
				_stick_origin = _stick_pos - d.normalized() * STICK_RADIUS
				d = d.normalized() * STICK_RADIUS
			player.move_input = d / STICK_RADIUS
			queue_redraw()
		elif event.index == _look_index:
			player.look_input += (event.position - _look_last) * 1.4
			_look_last = event.position


func _on_button(key: String, pressed: bool) -> void:
	match key:
		"jump":
			if pressed:
				player.jump_requested = true
		"sprint":
			player.sprint_held = pressed
		"pause":
			if pressed:
				pause_pressed.emit()


func _draw() -> void:
	# Joystick: a faint ring when idle, a full glass stick while held.
	if _stick_index >= 0:
		draw_circle(_stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.18))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 96, Color(1, 1, 1, 0.28), 2.0, true)
		draw_circle(_stick_pos, 50, Color(1, 1, 1, 0.22))
		draw_arc(_stick_pos, 50, 0, TAU, 64, Color(1, 1, 1, 0.7), 2.5, true)
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		var held: bool = b.held
		var c: Vector2 = b.center
		var r: float = b.r
		draw_circle(c, r, Color(1, 1, 1, 0.85) if held else Color(0.02, 0.025, 0.035, 0.38))
		draw_arc(c, r, 0, TAU, 96, Color(1, 1, 1, 0.45 if not held else 0.0), 2.0, true)
		var ink := Color(0.05, 0.05, 0.06) if held else Color(1, 1, 1, 0.92)
		var u := r * 0.32
		match key:
			"jump":
				_chevron(c + Vector2(0, -u * 0.35), u, ink)
				_chevron(c + Vector2(0, u * 0.55), u, Color(ink, ink.a * 0.45))
			"sprint":
				_chevron_right(c + Vector2(-u * 0.45, 0), u, ink)
				_chevron_right(c + Vector2(u * 0.45, 0), u, ink)
			"pause":
				for i in 3:
					var y := c.y + (i - 1) * u * 0.62
					draw_line(Vector2(c.x - u * 0.85, y), Vector2(c.x + u * 0.85, y), ink, 3.0, true)


func _chevron(c: Vector2, u: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-u, u * 0.5), c + Vector2(0, -u * 0.5), c + Vector2(u, u * 0.5)]), col, 4.0, true)


func _chevron_right(c: Vector2, u: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-u * 0.45, -u), c + Vector2(u * 0.45, 0), c + Vector2(-u * 0.45, u)]), col, 4.0, true)
