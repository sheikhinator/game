class_name MapView
extends Control
## Draws the city from CityBuilder data. Used for the HUD minimap (rotating,
## follows the player) and the pause-menu map (north up, drag to pan, pinch/scroll to zoom).

var city: CityBuilder
var player: Node3D
var minimap := true
var pixels_per_meter := 1.6
var center := Vector2.ZERO     # world XZ at the middle of the view (full map)
var heading := 0.0             # camera yaw for the rotating minimap

const BG := Color(0.17, 0.2, 0.18)
const BLOCK := Color(0.27, 0.29, 0.31)
const ROAD := Color(0.86, 0.87, 0.89)
const BUILDING := Color(0.36, 0.38, 0.41)

var _touches := {}


func _ready() -> void:
	clip_contents = true
	if minimap:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if minimap and player:
		center = Vector2(player.global_position.x, player.global_position.z)
		heading = player.get("yaw")
	queue_redraw()


func _to_screen(world: Vector2) -> Vector2:
	var rel := (world - center) * pixels_per_meter
	if minimap:
		rel = rel.rotated(heading)
	return size * 0.5 + rel


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if city == null:
		return
	var rot := heading if minimap else 0.0
	draw_set_transform(size * 0.5 - center.rotated(rot) * pixels_per_meter, rot, Vector2.ONE * pixels_per_meter)
	var b := city.bounds()
	draw_rect(b, BLOCK)
	for fp in city.footprints:
		draw_rect(fp, BUILDING)
	var road_w := CityBuilder.ROAD_HALF * 2.0
	for seg in city.road_segments:
		draw_line(seg[0], seg[1], ROAD, road_w)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Player arrow.
	if player:
		var p := _to_screen(Vector2(player.global_position.x, player.global_position.z))
		var model: Node3D = player.get("model")
		var face := (model.global_rotation.y if model else 0.0)
		var ang := -face + PI + (heading if minimap else 0.0)
		var pts := PackedVector2Array([Vector2(0, -16), Vector2(11, 12), Vector2(0, 6), Vector2(-11, 12)])
		var xf := Transform2D(ang, p)
		var out := PackedVector2Array()
		for q in pts:
			out.append(xf * q)
		draw_colored_polygon(out, Color.WHITE)
		draw_polyline(out + PackedVector2Array([out[0]]), Color(0, 0, 0, 0.8), 2.0, true)

	if minimap:
		# North marker on the rim.
		var n := Vector2(0, -1).rotated(heading) * (minf(size.x, size.y) * 0.5 - 18) + size * 0.5
		draw_circle(n, 15, Color(0, 0, 0, 0.7))
		var f := UIKit.heading_font()
		draw_string(f, n + Vector2(-7, 8), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9), false, 4.0)


func _gui_input(event: InputEvent) -> void:
	if minimap:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if _touches.size() >= 2:
			var keys := _touches.keys()
			var other: Vector2 = _touches[keys[0]] if keys[0] != event.index else _touches[keys[1]]
			var before: float = (_touches[event.index] as Vector2).distance_to(other)
			var after: float = event.position.distance_to(other)
			if before > 1.0:
				pixels_per_meter = clampf(pixels_per_meter * after / before, 0.3, 6.0)
		else:
			center -= event.relative / pixels_per_meter
		_touches[event.index] = event.position
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			pixels_per_meter = clampf(pixels_per_meter * 1.15, 0.3, 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pixels_per_meter = clampf(pixels_per_meter / 1.15, 0.3, 6.0)
