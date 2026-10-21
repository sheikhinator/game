class_name Player
extends CharacterBody3D
## Third-person on-foot controller with a GTA-style chase camera.

const WALK_SPEED := 1.7
const JOG_SPEED := 4.0
const SPRINT_SPEED := 6.8
const ACCEL := 10.0
const TURN_SPEED := 10.0
const JUMP_VELOCITY := 4.6
const GRAVITY := 14.0

var model: CharacterModel
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D

var yaw := 0.0          # camera yaw
var pitch := -0.18      # camera pitch
var move_input := Vector2.ZERO   # from touch joystick, -1..1
var look_input := Vector2.ZERO   # accumulated pixels this frame
var sprint_held := false
var jump_requested := false

var _was_on_floor := true
var _land_timer := 0.0
var _last_pos := Vector3.ZERO
var _dev_cam_dist := 0.0
var _dev_yaw := INF


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	model = CharacterModel.new()
	add_child(model)
	model.setup(Game.state.appearance)

	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 3.4
	spring.margin = 0.25
	spring.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 900.0
	spring.add_child(camera)
	camera.position = Vector3(0.45, 0, 0)
	camera.current = true
	cam_pivot.global_position = global_position + Vector3(0, 1.55, 0)
	_last_pos = global_position
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam-dist="):
			_dev_cam_dist = float(arg.get_slice("=", 1))
		elif arg.begins_with("--cam-pitch="):
			pitch = float(arg.get_slice("=", 1))
		elif arg.begins_with("--cam-yaw="):
			_dev_yaw = float(arg.get_slice("=", 1))


func _unhandled_input(event: InputEvent) -> void:
	# Desktop testing: right mouse drag to look.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look_input += event.relative


func _physics_process(delta: float) -> void:
	# --- input
	var kb := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	var key_w := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var inp := move_input + kb + key_w
	if inp.length() > 1.0:
		inp = inp.normalized()
	var sprint := sprint_held or Input.is_key_pressed(KEY_SHIFT)
	if Input.is_key_pressed(KEY_SPACE):
		jump_requested = true

	# --- camera look
	var sens: float = 0.0045 * float(Game.settings.cam_sensitivity)
	yaw -= look_input.x * sens
	var inv := -1.0 if Game.settings.invert_y else 1.0
	pitch = clampf(pitch - look_input.y * sens * inv, -1.15, 0.55)
	look_input = Vector2.ZERO

	# --- movement relative to camera
	var basis_yaw := Basis(Vector3.UP, yaw)
	var dir := basis_yaw * Vector3(inp.x, 0, inp.y)
	var amount := inp.length()
	var target_speed := 0.0
	if amount > 0.05:
		target_speed = SPRINT_SPEED if sprint else (WALK_SPEED if amount < 0.55 else JOG_SPEED)
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want := dir.normalized() * target_speed if amount > 0.05 else Vector3.ZERO
	hv = hv.lerp(want, clampf(ACCEL * delta, 0, 1))
	velocity.x = hv.x
	velocity.z = hv.z

	if is_on_floor():
		if jump_requested:
			velocity.y = JUMP_VELOCITY
			model.play("Jump_Start", 0.1)
	else:
		velocity.y -= GRAVITY * delta
	jump_requested = false

	move_and_slide()

	# Face direction of travel.
	if hv.length() > 0.3:
		var target_rot := atan2(hv.x, hv.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rot, clampf(TURN_SPEED * delta, 0, 1))

	_update_animation(hv.length(), delta)
	_update_camera(delta)

	Game.state.distance_walked += global_position.distance_to(_last_pos)
	_last_pos = global_position
	# Stamina drains while sprinting and recovers otherwise.
	if sprint and hv.length() > 4.0:
		Game.state.stamina = maxf(0.0, Game.state.stamina - 6.0 * delta)
	else:
		Game.state.stamina = minf(100.0, Game.state.stamina + 9.0 * delta)


func _update_animation(speed: float, delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		if velocity.y < -2.0:
			model.play("Jump", 0.25)
	else:
		if not _was_on_floor:
			_land_timer = 0.25
			model.play("Jump_Land", 0.08)
		_land_timer -= delta
		if _land_timer <= 0.0:
			if speed < 0.25:
				model.play("Idle", 0.25)
			elif speed < 2.6:
				model.play("Walk", 0.2, clampf(speed / 1.5, 0.6, 1.4))
			elif speed < 5.5:
				model.play("Jog_Fwd", 0.2, clampf(speed / 4.0, 0.7, 1.3))
			else:
				model.play("Sprint", 0.2, clampf(speed / 6.8, 0.8, 1.2))
	_was_on_floor = on_floor


func _update_camera(delta: float) -> void:
	var target := global_position + Vector3(0, 1.55, 0)
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, clampf(14.0 * delta, 0, 1))
	cam_pivot.rotation = Vector3(pitch, yaw, 0)
	# Pull the camera back a little when running for a sense of speed.
	var speed := Vector2(velocity.x, velocity.z).length()
	spring.spring_length = lerpf(spring.spring_length, 3.4 + clampf(speed - 3.0, 0, 4) * 0.25, clampf(3.0 * delta, 0, 1))
	if _dev_cam_dist > 0.0:
		spring.spring_length = _dev_cam_dist
		spring.collision_mask = 0
	camera.fov = lerpf(camera.fov, 62.0 + clampf(speed - 4.0, 0, 4) * 1.5, clampf(3.0 * delta, 0, 1))


func set_spawn(pos: Vector3, facing: float) -> void:
	global_position = pos
	yaw = facing
	model.rotation.y = facing + PI
	if _dev_yaw != INF:
		yaw = _dev_yaw
	cam_pivot.global_position = pos + Vector3(0, 1.55, 0)
	_last_pos = pos
