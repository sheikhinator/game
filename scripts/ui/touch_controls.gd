class_name TouchControls
extends Control
## Touch layer: floating left-thumb stick, camera drag on the right,
## and context buttons that change on foot and behind the wheel.

signal pause_pressed

var player: Player

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _buttons := {}      # name -> {center, r, held, index}
var _mode := ""

const STICK_RADIUS := 120.0


func _ready() -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	Game.settings_changed.connect(_layout)
	_layout()


func _current_mode() -> String:
	if player == null:
		return "foot"
	if player.vehicle != null:
		return "drive"
	return "foot_car" if player.nearby_car != null else "foot"


func _process(_d: float) -> void:
	if _current_mode() != _mode:
		_layout()


func _layout() -> void:
	_mode = _current_mode()
	var s: float = float(Game.settings.button_scale)
	var w := size.x
	var h := size.y
	var r := 74.0 * s
	_release_all()
	_buttons = {"pause": _btn(Vector2(w - 96 * s, 84 * s), 44 * s)}
	match _mode:
		"drive":
			_buttons.gas = _btn(Vector2(w - 170 * s, h - 190 * s), 92 * s)
			_buttons.brake = _btn(Vector2(w - 390 * s, h - 150 * s), 72 * s)
			_buttons.handbrake = _btn(Vector2(w - 330 * s, h - 340 * s), 58 * s)
			_buttons.exit = _btn(Vector2(w - 96 * s, 230 * s), 52 * s)
		_:
			_buttons.jump = _btn(Vector2(w - 160 * s, h - 310 * s), r)
			_buttons.sprint = _btn(Vector2(w - 330 * s, h - 170 * s), r)
			if _mode == "foot_car":
				_buttons.enter = _btn(Vector2(w - 400 * s, h - 360 * s), 64 * s)
	queue_redraw()


func _btn(c: Vector2, r: float) -> Dictionary:
	return {"center": c, "r": r, "held": false, "index": -1}


func _release_all() -> void:
	if player:
		player.sprint_held = false
		player.drive_throttle = 0.0
		player.drive_handbrake = false


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
				_stick_origin = _stick_pos - d.normalized() * STICK_RADIUS
				d = d.normalized() * STICK_RADIUS
			player.move_input = d / STICK_RADIUS
			queue_redraw()
		elif event.index == _look_index:
			player.look_input += (event.position - _look_last) * 1.4
			_look_last = event.position


func _held(key: String) -> bool:
	return _buttons.has(key) and _buttons[key].held


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
		"enter":
			if pressed:
				player.enter_vehicle()
		"exit":
			if pressed:
				player.exit_vehicle()
		"gas", "brake":
			player.drive_throttle = (1.0 if _held("gas") else 0.0) - (1.0 if _held("brake") else 0.0)
		"handbrake":
			player.drive_handbrake = pressed


func _draw() -> void:
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
		var accent: bool = key in ["enter", "gas"]
		var fill := Color(1, 1, 1, 0.85) if held else (Color(UIKit.ACCENT, 0.26) if accent else Color(0.02, 0.025, 0.035, 0.38))
		draw_circle(c, r, fill)
		var ring := Color(UIKit.ACCENT, 0.9) if accent else Color(1, 1, 1, 0.45)
		if not held:
			draw_arc(c, r, 0, TAU, 96, ring, 2.0, true)
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
			"enter", "exit":
				_wheel_icon(c, u * 1.3, ink)
			"gas":
				_chevron(c + Vector2(0, -u * 0.6), u * 1.1, ink)
				_chevron(c + Vector2(0, u * 0.25), u * 1.1, ink)
			"brake":
				_chevron(c + Vector2(0, u * 0.6), -u * 1.1, ink)
				_chevron(c + Vector2(0, -u * 0.25), -u * 1.1, ink)
			"handbrake":
				draw_arc(c, u * 1.1, -2.4, -0.74, 32, ink, 3.0, true)
				draw_arc(c, u * 1.1, 0.74, 2.4, 32, ink, 3.0, true)
				var f := UIKit.display(600)
				var fs := int(u * 1.5)
				var ts := f.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				draw_string(f, c + Vector2(-ts.x * 0.5, fs * 0.36), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _chevron(c: Vector2, u: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-u, u * 0.5), c + Vector2(0, -u * 0.5), c + Vector2(u, u * 0.5)]), col, 4.0, true)


func _chevron_right(c: Vector2, u: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-u * 0.45, -u), c + Vector2(u * 0.45, 0), c + Vector2(-u * 0.45, u)]), col, 4.0, true)


func _wheel_icon(c: Vector2, rr: float, col: Color) -> void:
	draw_arc(c, rr, 0, TAU, 48, col, 3.0, true)
	draw_circle(c, rr * 0.22, col)
	for a in [PI * 0.5, PI * 0.5 + 2.1, PI * 0.5 - 2.1]:
		draw_line(c, c + Vector2(cos(a), sin(a)) * rr, col, 3.0, true)
