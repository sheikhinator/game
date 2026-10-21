class_name DayNight
extends Node3D
## Sky, sun, moon, fog, street lights and graphics presets, driven by Game.state.time_of_day.

var world_env: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var _cloud_time := 0.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
var time_scale := 1.0  # extra multiplier, e.g. fast cycle on the title screen

var _lamp_timer := 0.0
var _lamps_on := false


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 420.0
	env.fog_sky_affect = 0.06
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08

	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

	apply_graphics(Game.settings.graphics)
	Game.settings_changed.connect(func(): apply_graphics(Game.settings.graphics))
	_update_sky(Game.state.time_of_day)


func _process(delta: float) -> void:
	var minutes: float = maxf(Game.settings.day_minutes, 1.0)
	var paused := get_tree().paused
	if not paused:
		Game.state.time_of_day += delta * time_scale * 24.0 / (minutes * 60.0)
		if Game.state.time_of_day >= 24.0:
			Game.state.time_of_day -= 24.0
			Game.state.day += 1
	_update_sky(Game.state.time_of_day)
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = 0.5
		_update_lamps()


func _update_sky(t: float) -> void:
	# Sun travels east to west; noon high in the south.
	var day_phase := (t - 6.0) / 12.0              # 0 at sunrise, 1 at sunset
	var elev := sin(day_phase * PI)                 # -1..1
	var elev_deg := rad_to_deg(asin(clampf(elev, -1.0, 1.0))) * 0.85
	var azimuth := lerpf(100.0, 260.0, clampf(day_phase, 0.0, 1.0))
	sun.rotation_degrees = Vector3(-elev_deg, azimuth, 0)
	var day := smoothstep(-0.08, 0.25, elev)
	var golden := smoothstep(0.35, 0.02, elev) * smoothstep(-0.12, 0.05, elev)

	sun.light_energy = lerpf(0.0, 1.7, day)
	sun.light_color = Color(1.0, 0.97, 0.92).lerp(Color(1.0, 0.62, 0.35), golden)
	sun.visible = sun.light_energy > 0.01

	moon.rotation_degrees = Vector3(-35, azimuth + 180.0, 0)
	moon.light_energy = 0.16 * (1.0 - day)
	moon.visible = moon.light_energy > 0.01

	var top_day := Color(0.22, 0.42, 0.76)
	var hor_day := Color(0.68, 0.78, 0.88)
	var top_night := Color(0.008, 0.014, 0.04)
	var hor_night := Color(0.04, 0.055, 0.1)
	var hor_gold := Color(0.98, 0.56, 0.3)
	var top_col := top_night.lerp(top_day, day)
	var hor_col := hor_night.lerp(hor_day, day).lerp(hor_gold, golden * 0.85)
	sky_mat.set_shader_parameter("top_color", top_col)
	sky_mat.set_shader_parameter("horizon_color", hor_col)
	sky_mat.set_shader_parameter("ground_color", Color(0.06, 0.06, 0.07).lerp(Color(0.24, 0.23, 0.22), day))
	sky_mat.set_shader_parameter("sun_tint", sun.light_color)
	sky_mat.set_shader_parameter("day", day)
	sky_mat.set_shader_parameter("energy", lerpf(0.5, 1.0, day))
	_cloud_time += get_process_delta_time() * (1.0 if not get_tree().paused else 0.0)
	sky_mat.set_shader_parameter("cloud_time", _cloud_time + Game.state.time_of_day * 30.0)
	env.ambient_light_energy = lerpf(0.14, 0.9, day)
	env.ambient_light_color = Color(0.32, 0.33, 0.36).lerp(Color(0.86, 0.84, 0.8), day)
	env.fog_light_color = hor_col
	env.fog_density = 0.0
	env.tonemap_exposure = lerpf(1.25, 1.0, day)
	_lamps_on = elev < 0.08


func is_night() -> bool:
	return _lamps_on


func _update_lamps() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	for l in lamps:
		var near := l.global_position.distance_squared_to(cp) < 90.0 * 90.0
		var on := _lamps_on and near
		l.visible = on
		l.light_energy = 3.0 if on else 0.0


func apply_graphics(preset: String) -> void:
	var vp := get_viewport()
	match preset:
		"Low":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.6
			sun.directional_shadow_max_distance = 45.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.glow_enabled = false
		"Medium":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.75
			sun.directional_shadow_max_distance = 70.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.glow_enabled = true
		"High":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
			sun.directional_shadow_max_distance = 110.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			env.ssao_enabled = true
			env.ssao_radius = 1.2
			env.ssao_intensity = 1.6
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.glow_enabled = true
		_:  # Ultra
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			sun.directional_shadow_max_distance = 160.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			env.ssao_enabled = true
			env.ssao_radius = 1.4
			env.ssao_intensity = 2.0
			env.ssil_enabled = true
			env.ssr_enabled = true
			env.ssr_max_steps = 48
			env.glow_enabled = true
