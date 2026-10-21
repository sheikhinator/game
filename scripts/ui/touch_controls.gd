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
		"jump": {"center": Vector2(w - 150 * s, h - 300 * s), "r": r, "label": "JUMP", "held": false, "index": -1},
		"sprint": {"center": Vector2(w - 330 * s, h - 160 * s), "r": r, "label": "RUN", "held": false, "index": -1},
		"pause": {"center": Vector2(w - 70 * s, 70 * s), "r": 48 * s, "label": "≡", "held": false, "index": -1},
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
	var font := UIKit.heading_font()
	# Joystick: faint hint when idle, full stick while held.
	if _stick_index >= 0:
		draw_circle(_stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.25))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
		draw_circle(_stick_pos, 52, Color(1, 1, 1, 0.55))
	else:
		var hint := Vector2(230, size.y - 230)
		draw_arc(hint, STICK_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.16), 3.0, true)
		draw_circle(hint, 40, Color(1, 1, 1, 0.12))
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		var held: bool = b.held
		draw_circle(b.center, b.r, Color(1, 1, 1, 0.75) if held else Color(0, 0, 0, 0.35))
		draw_arc(b.center, b.r, 0, TAU, 64, Color(1, 1, 1, 0.55), 3.0, true)
		var fs := int(b.r * 0.42) if key != "pause" else int(b.r * 0.9)
		var ts := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, b.center + Vector2(-ts.x * 0.5, ts.y * 0.32), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.BLACK if held else Color.WHITE)
