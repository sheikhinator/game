extends Node3D
func _ready():
	var names = ["sedan_black","sedan_red","taxi","hatch_white","hatch_blue","suv_grey","suv_green","van_white","sedan_silver"]
	for i in names.size():
		var c = CarLook.instantiate(names[i]); add_child(c)
		c.position = Vector3((i % 3 - 1) * 3.3, 0, (i / 3) * -6.0)
		c.rotation_degrees.y = 35
	var g = MeshInstance3D.new(); g.mesh = PlaneMesh.new(); g.mesh.size = Vector2(60, 60); var gm = StandardMaterial3D.new(); gm.albedo_color = Color(0.35,0.35,0.36); g.mesh.material = gm; add_child(g)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 50, 0); sun.light_energy = 1.7; sun.shadow_enabled = true; add_child(sun)
	var we = WorldEnvironment.new(); var e = Environment.new(); var sky = Sky.new(); var sm = ProceduralSkyMaterial.new(); sm.sky_top_color = Color(0.25,0.45,0.8); sm.sky_horizon_color = Color(0.7,0.78,0.88); sky.sky_material = sm; e.background_mode = Environment.BG_SKY; e.sky = sky; e.tonemap_mode = Environment.TONE_MAPPER_AGX; e.ssao_enabled = true; e.ssr_enabled = true; we.environment = e; add_child(we)
	var cam = Camera3D.new(); cam.position = Vector3(1, 4.5, 9.5); cam.fov = 50; add_child(cam); cam.look_at(Vector3(0, 0.3, -5)); cam.current = true
