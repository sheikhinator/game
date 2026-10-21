class_name Traffic
extends Node3D
## Parked cars along the kerbs and AI traffic driving the street grid (right-hand traffic).

const LANE := 2.9          # lane centre offset from road centre
const PARK := 4.95         # parked-car offset from road centre
const CRUISE := 11.0       # m/s, about 40 km/h
const TURN_SPEED := 6.0

var city: CityBuilder
var rng := RandomNumberGenerator.new()
var drivers: Array = []    # [{car, from: Vector2i, dir: Vector2i, path: Array, t, len}]
var player: Node3D


func setup(c: CityBuilder, p: Node3D, traffic_count := 16) -> void:
	city = c
	player = p
	rng.seed = 4242
	_spawn_parked()
	for i in traffic_count:
		_spawn_driver()


static func right_of(d: Vector3) -> Vector3:
	return d.cross(Vector3.UP).normalized()


func _node_pos(n: Vector2i) -> Vector3:
	return Vector3(n.x * CityBuilder.PITCH, 0, n.y * CityBuilder.PITCH)


func _in_grid(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= city.grid_x and n.y <= city.grid_z


func _random_model() -> String:
	return Car.FLEET[rng.randi() % Car.FLEET.size()]


# ---------------------------------------------------------------- parked cars

func _spawn_parked() -> void:
	var half := CityBuilder.INTER * 0.5
	for j in city.grid_z + 1:
		for i in city.grid_x:
			for side in [-1, 1]:
				var d := Vector3(1, 0, 0) if side > 0 else Vector3(-1, 0, 0)
				_park_row(Vector3(i * CityBuilder.PITCH + half, 0, j * CityBuilder.PITCH), Vector3(1, 0, 0), d)
	for i in city.grid_x + 1:
		for j in city.grid_z:
			for side in [-1, 1]:
				var d := Vector3(0, 0, 1) if side > 0 else Vector3(0, 0, -1)
				_park_row(Vector3(i * CityBuilder.PITCH, 0, j * CityBuilder.PITCH + half), Vector3(0, 0, 1), d)


func _park_row(start: Vector3, axis: Vector3, facing: Vector3) -> void:
	var off := right_of(facing) * PARK
	var t := 9.0
	while t < CityBuilder.BLOCK - 9.0:
		if rng.randf() < 0.38:
			var car := PropCar.create(_random_model())
			add_child(car)
			car.global_position = start + axis * t + off
			car.look_at(car.global_position + facing, Vector3.UP, true)
		t += rng.randf_range(6.5, 9.0)


# ---------------------------------------------------------------- traffic AI

func _spawn_driver() -> void:
	var from := Vector2i(rng.randi_range(0, city.grid_x), rng.randi_range(0, city.grid_z))
	var dirs := _options(from, Vector2i.ZERO)
	if dirs.is_empty():
		return
	var dir: Vector2i = dirs[rng.randi() % dirs.size()]
	var car := PropCar.create(_random_model())
	add_child(car)
	var d := {"car": car, "from": from, "dir": dir, "path": [], "t": rng.randf_range(0.0, 0.8), "speed": CRUISE}
	_plan_segment(d)
	drivers.append(d)
	_place(d)


func _options(at: Vector2i, came: Vector2i) -> Array:
	var out := []
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if dd == -came and came != Vector2i.ZERO:
			continue
		if _in_grid(at + dd):
			out.append(dd)
	return out


## Builds the path from leaving `from` to just past the next intersection's turn.
func _plan_segment(d: Dictionary) -> void:
	var from: Vector2i = d.from
	var dir: Vector2i = d.dir
	var to: Vector2i = from + dir
	var d3 := Vector3(dir.x, 0, dir.y)
	var r := right_of(d3) * LANE
	var half := CityBuilder.INTER * 0.5
	var a := _node_pos(from) + d3 * half + r
	var b := _node_pos(to) - d3 * half + r
	var opts := _options(to, dir)
	var next: Vector2i = dir
	if not opts.is_empty():
		# Prefer straight on, sometimes turn.
		next = dir if (dir in opts and rng.randf() < 0.55) else opts[rng.randi() % opts.size()]
	var n3 := Vector3(next.x, 0, next.y)
	var exit_pt := _node_pos(to) + n3 * half + right_of(n3) * LANE
	var ctrl: Vector3
	if next == dir:
		ctrl = (b + exit_pt) * 0.5
	else:
		ctrl = b + d3 * (exit_pt - b).dot(d3)
	var pts := [a, b]
	for k in range(1, 9):
		var t := k / 8.0
		pts.append(b.lerp(ctrl, t).lerp(ctrl.lerp(exit_pt, t), t))
	d.path = pts
	d.next = next
	d.to = to
	var total := 0.0
	for k in range(1, pts.size()):
		total += (pts[k] as Vector3).distance_to(pts[k - 1])
	d.len = total
	d.dist = d.t * (a.distance_to(b))


func _sample(path: Array, dist: float) -> Array:
	for k in range(1, path.size()):
		var seg: float = (path[k] as Vector3).distance_to(path[k - 1])
		if dist <= seg or k == path.size() - 1:
			var f := clampf(dist / maxf(seg, 0.001), 0.0, 1.0)
			var p: Vector3 = (path[k - 1] as Vector3).lerp(path[k], f)
			var fwd: Vector3 = ((path[k] as Vector3) - (path[k - 1] as Vector3)).normalized()
			return [p, fwd, k >= 2]
		dist -= seg
	return [path[-1], Vector3.FORWARD, true]


func _place(d: Dictionary) -> void:
	var car: PropCar = d.car
	if not is_instance_valid(car):
		return
	var s := _sample(d.path, d.dist)
	var p: Vector3 = s[0]
	var fwd: Vector3 = s[1]
	car.global_position = p
	if fwd.length() > 0.1:
		var target := Basis.looking_at(fwd, Vector3.UP, true)
		car.global_basis = car.global_basis.slerp(target, 0.35).orthonormalized()
	d.turning = s[2]


func _physics_process(delta: float) -> void:
	var cars := []
	for d in drivers:
		if is_instance_valid(d.car):
			cars.append(d.car)
	for d in drivers:
		var car: PropCar = d.car
		if not is_instance_valid(car):
			continue
		var want := TURN_SPEED if d.get("turning", false) else CRUISE
		# Hold back for any car or the player close ahead in our path.
		var fwd := car.global_basis.z
		for other in cars:
			if other == car:
				continue
			var rel: Vector3 = (other as Node3D).global_position - car.global_position
			var ahead := rel.dot(fwd)
			if ahead > 0.5 and ahead < 11.0 and absf(rel.dot(right_of(fwd))) < 2.2:
				want = minf(want, maxf(0.0, (ahead - 6.0) * 1.5))
		for blocker in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("player_car"):
			var rel2: Vector3 = (blocker as Node3D).global_position - car.global_position
			var ahead2 := rel2.dot(fwd)
			if ahead2 > 0.5 and ahead2 < 12.0 and absf(rel2.dot(right_of(fwd))) < 2.4:
				want = minf(want, maxf(0.0, (ahead2 - 5.0) * 1.2))
		d.speed = move_toward(d.speed, want, delta * (7.0 if want < d.speed else 3.0))
		car.speed = d.speed
		d.dist += d.speed * delta
		if d.dist >= d.len:
			# Continue onto the road we turned into.
			var carry: float = d.dist - d.len
			d.from = d.to
			d.dir = d.next
			d.t = 0.0
			_plan_segment(d)
			d.dist = carry
		_place(d)
	drivers = drivers.filter(func(x): return is_instance_valid(x.car))
