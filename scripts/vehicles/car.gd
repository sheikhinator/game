class_name Car
extends VehicleBody3D
## Player-drivable car with GTA V-style handling: weighty, grippy, forgiving.

const FLEET := ["sedan_black", "sedan_silver", "sedan_red", "taxi", "hatch_white", "hatch_blue", "suv_grey", "suv_green", "van_white"]

var model_name := ""
var visual: Node3D
var spec := {}
var wheels: Array[VehicleWheel3D] = []
var throttle := 0.0      # -1..1 (negative = brake / reverse)
var steer_input := 0.0   # -1..1 (positive = left)
var handbrake := false
var driver: Node = null
var headlights: Array[SpotLight3D] = []

var _max_force := 5200.0
var _max_brake := 60.0


static func create(name: String) -> Car:
	var c := Car.new()
	c.model_name = name
	return c


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	mass = 1450.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.38, 0.1)
	continuous_cd = true
	can_sleep = true
	spec = CarLook.spec(model_name)
	visual = CarLook.instantiate(model_name)
	add_child(visual)
	# Generated cars face -Z; Godot vehicles drive towards +Z.
	visual.rotation.y = PI
	var kind: String = spec.get("kind", "sedan")
	if kind == "suv":
		mass = 1900.0
	elif kind == "van":
		mass = 2300.0
		_max_force = 6200.0
	_build_collision()
	_build_wheels()
	_build_lights()


func _build_collision() -> void:
	var L: float = spec.get("length", 4.6)
	var W: float = spec.get("width", 1.8)
	var clr: float = spec.get("clearance", 0.16)
	var belt := 0.95
	var roof := 1.42
	if spec.has("belt"):
		belt = 0.0
		roof = 0.0
		for v in spec.belt:
			belt = maxf(belt, v)
		for v in spec.roof:
			roof = maxf(roof, v)
	var lower := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(W * 0.96, belt - clr - 0.02, L * 0.97)
	lower.shape = lb
	lower.position = Vector3(0, clr + 0.02 + lb.size.y * 0.5, 0)
	add_child(lower)
	var upper := CollisionShape3D.new()
	var ub := BoxShape3D.new()
	ub.size = Vector3(W * 0.8, roof - belt, L * 0.5)
	upper.shape = ub
	upper.position = Vector3(0, belt + ub.size.y * 0.5, -L * 0.04)
	add_child(upper)


func _build_wheels() -> void:
	var r: float = spec.get("wheel_r", 0.33)
	for wname in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		var mesh := visual.find_child(wname, true, false) as Node3D
		if mesh == null:
			continue
		var gt := mesh.global_transform
		# Wheel vertices are baked in car space; find the hub from the mesh bounds.
		var hub_local := (mesh as MeshInstance3D).get_aabb().get_center() if mesh is MeshInstance3D else Vector3.ZERO
		var hub := gt * hub_local
		var w := VehicleWheel3D.new()
		w.name = wname
		var front: bool = wname.begins_with("wheel_f")
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = r
		w.wheel_rest_length = 0.16
		w.suspension_travel = 0.2
		w.suspension_stiffness = 55.0
		w.suspension_max_force = mass * 9.8
		w.damping_compression = 1.6
		w.damping_relaxation = 2.4
		w.wheel_friction_slip = 3.2 if front else 3.0
		w.wheel_roll_influence = 0.08
		# The wheel's chassis connection is read when it enters the tree: place it first.
		w.position = to_local(hub) + Vector3(0, 0.12, 0)
		add_child(w)
		# Move the visual wheel under the physics wheel so it spins and steers.
		mesh.get_parent().remove_child(mesh)
		w.add_child(mesh)
		mesh.global_basis = gt.basis
		mesh.position = -(mesh.basis * hub_local)
		wheels.append(w)


func _build_lights() -> void:
	var L: float = spec.get("length", 4.6)
	var W: float = spec.get("width", 1.8)
	for s in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.95, 0.85)
		l.spot_range = 32.0
		l.spot_angle = 32.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.position = Vector3(s * W * 0.32, 0.72, L * 0.5 + 0.05)
		l.rotation_degrees = Vector3(-6, 180, 0)
		add_child(l)
		headlights.append(l)


func set_lights(on: bool) -> void:
	for l in headlights:
		l.light_energy = 4.0 if on else 0.0
		l.visible = on


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func _physics_process(delta: float) -> void:
	if driver == null:
		engine_force = 0.0
		brake = 2.0
		steering = move_toward(steering, 0.0, delta * 2.0)
		return
	var v := forward_speed()
	# Throttle forward; pulling back brakes, then reverses once stopped.
	if throttle > 0.05:
		engine_force = _max_force * throttle * clampf(1.0 - v / 62.0, 0.15, 1.0)
		brake = 0.0
	elif throttle < -0.05:
		if v > 1.0:
			engine_force = 0.0
			brake = _max_brake * -throttle
		else:
			engine_force = _max_force * 0.55 * throttle * clampf(1.0 + v / 9.0, 0.0, 1.0)
			brake = 0.0
	else:
		engine_force = 0.0
		brake = 1.2
	# Steering gets gentler at speed, GTA style.
	var max_steer := lerpf(0.62, 0.16, clampf(absf(v) / 38.0, 0.0, 1.0))
	steering = move_toward(steering, steer_input * max_steer, delta * 2.6)
	for w in wheels:
		if not w.use_as_steering:
			w.wheel_friction_slip = 1.3 if handbrake else 3.0
			w.brake = 25.0 if handbrake else 0.0
	if OS.get_cmdline_user_args().has("--debug-car") and Engine.get_physics_frames() % 30 == 0:
		var contacts := []
		for w in wheels:
			contacts.append(w.is_in_contact())
		print("CAR v=%.2f fwd=%.2f eng=%.0f brk=%.1f steer=%.2f contacts=%s pos=%s" % [linear_velocity.length(), v, engine_force, brake, steering, contacts, global_position])
	# Light downforce keeps it planted at speed.
	apply_central_force(-global_basis.y * linear_velocity.length() * 14.0)
