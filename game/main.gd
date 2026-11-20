extends Node3D

var player := Vector3.ZERO
var flames := 3
var carried := 0
var score := 0
var lanterns: Array[MeshInstance3D] = []
var lantern_progress: Array[int] = []
var motes: Array[Vector3] = []
var mote_nodes: Array[MeshInstance3D] = []
var mote_ttl_ticks: Array[int] = []
var mote_kinds: Array[String] = []
var shade_states: Array[Dictionary] = []
var drifter_states: Array[Dictionary] = []
var charm_states: Array[Dictionary] = []
var won := false
var lost := false
var outcome_awarded := false
var hud: Label
var lantern_fuel: Array[float] = []
var lantern_ever_lit: Array[bool] = []
var lantern_relit_count: Array[int] = []
var lantern_fuel_bars: Array[MeshInstance3D] = []
var successful_lights: int = 0
var capacity: int = 10
var colorblind_mode: bool = false
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.FORWARD
var facing_direction := Vector3.FORWARD
var horizontal_velocity := Vector3.ZERO
var vertical_velocity := 0.0
var night := 1
var night_name := "Đêm 1 — Đảo Bến"
var time_left := 300.0
var invulnerability := 0.0
var pulse_cooldown := 0.0
var shade_stun := 0.0
var shade_push_ticks := 0
var shade_push_direction := Vector3.RIGHT
var shade: MeshInstance3D
var world_environment: WorldEnvironment
var sim_tick := 0
var game_camera: Camera3D
var camera_yaw := 0.0
var grounded := true
var pad_launched := false
var pad_horizontal_velocity := Vector3.ZERO
var shade_spawn_remaining := 5.0
var respawn_ticks := 0
var fall_triggered := false
var charm_ticks := 0
var next_shade_id := 1
var next_drifter_id := 1
var recoil_ticks := 0
var recoil_direction := Vector3.ZERO
var pause_layer: Control
var timer_label: Label

const LANTERN_POSITIONS := {
	1: [Vector3(0,0,25), Vector3(23.8,0,7.7), Vector3(14.7,0,-20.2), Vector3(-14.7,0,-20.2), Vector3(-23.8,0,7.7)],
	2: [Vector3(0,0,20), Vector3(17,0,-10), Vector3(-17,0,-10), Vector3(70,0,20), Vector3(87,0,-10), Vector3(53,0,-10)],
	3: [Vector3(0,6,6), Vector3(18,3,10), Vector3(-18,3,10), Vector3(35,0,-10), Vector3(-35,0,-10), Vector3(20,0,-35), Vector3(-20,0,-35)]
}

func _ready() -> void:
	var flow_cfg := ConfigFile.new()
	if flow_cfg.load("user://night_flow.cfg") == OK:
		night = clampi(int(flow_cfg.get_value("flow", "night", night)), 1, 3)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--night" and i + 1 < args.size(): night = clampi(int(args[i + 1]), 1, 3)
	night_name = ["", "Đêm 1 — Đảo Bến", "Đêm 2 — Đảo Cau", "Đêm 3 — Đảo Chuông"][night]
	time_left = [0.0, 240.0, 270.0, 300.0][night]
	player = Vector3(0, 0, -15) if night == 3 else Vector3.ZERO
	var settings_cfg := ConfigFile.new()
	if settings_cfg.load("user://settings.cfg") == OK:
		colorblind_mode = bool(settings_cfg.get_value("accessibility", "colorblind", false))
	_setup_world()
	_setup_charms()
	_register_gameplay_actions()
	var ui_script := load("res://phase2_ui.gd")
	var ui = ui_script.new()
	ui.name = "Phase2UI"
	add_child(ui)
	_apply_accessibility()
	_update_hud()

func _physics_process(delta: float) -> void:
	if get_tree().paused or won or lost: return
	sim_tick += 1
	time_left = maxf(0.0, time_left - delta)
	_advance_counters()
	var input_vec := Input.get_vector("move_left_game", "move_right_game", "move_forward_game", "move_back_game")
	var forward := Vector3(sin(camera_yaw), 0, cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var move_dir := right * input_vec.x - forward * input_vec.y
	if move_dir.length_squared() > 0.0: facing_direction = move_dir.normalized()
	if respawn_ticks == 0: _move_player(delta, move_dir)
	if not fall_triggered and player.y < -10.0: _handle_fall()
	if respawn_ticks == 0:
		_collect_motes()
		_collect_charms()
	if respawn_ticks == 0 and Input.is_action_just_pressed("interact_game"): _collect_or_deposit()
	if respawn_ticks == 0 and Input.is_action_just_pressed("pulse_game"): _activate_pulse()
	_step_shades(delta)
	_step_drifters(delta)
	_spawn_scheduled_entities()
	$Player.position = player + Vector3(0, 0.7, 0)
	if is_instance_valid(game_camera):
		game_camera.position = player - forward * 14.0 + Vector3(0, 12, 0)
		game_camera.look_at(player)
	_evaluate_outcome()
	_update_hud()

func _advance_counters() -> void:
	dash_cooldown = maxf(0.0, dash_cooldown - 1.0 / 60.0)
	invulnerability = maxf(0.0, invulnerability - 1.0 / 60.0)
	pulse_cooldown = maxf(0.0, pulse_cooldown - 1.0 / 60.0)
	charm_ticks = maxi(0, charm_ticks - 1)
	if respawn_ticks > 0:
		respawn_ticks -= 1
		if respawn_ticks == 0:
			player = Vector3(0, 0, -15) if night == 3 else Vector3.ZERO
			vertical_velocity = 0.0; horizontal_velocity = Vector3.ZERO; grounded = true; fall_triggered = false
	for i in range(motes.size() - 1, -1, -1):
		if mote_ttl_ticks[i] > 0:
			mote_ttl_ticks[i] -= 1
			if mote_ttl_ticks[i] == 0: _remove_mote(i)
	for i in lanterns.size():
		if lantern_progress[i] >= 10:
			var drain_count := 0
			for shade_data in shade_states:
				if shade_data.get("state") == "drain" and shade_data.get("target_lantern_id") == ("L%d" % (i + 1)):
					drain_count += 1
			lantern_fuel[i] = maxf(0.0, lantern_fuel[i] - (1.0 + 5.0 * float(drain_count)) * (1.0 / 60.0))
			if lantern_fuel[i] <= 0.0:
				lantern_progress[i] = 0
				lantern_fuel[i] = 0.0
				lantern_ever_lit[i] = true
				lanterns[i].get_child(0).light_energy = 0.0
				world_environment.environment.ambient_light_energy = 0.15 + 0.55 * float(lantern_progress.count(10)) / float(lantern_progress.size())
				for shade_data in shade_states:
					if shade_data.get("state") == "drain" and shade_data.get("target_lantern_id") == ("L%d" % (i + 1)):
						shade_data["state"] = "wander"; shade_data["target_lantern_id"] = ""
			if i < lantern_fuel_bars.size() and is_instance_valid(lantern_fuel_bars[i]):
				var bar: MeshInstance3D = lantern_fuel_bars[i]
				bar.visible = lantern_progress[i] >= 10
				bar.scale.x = maxf(0.01, lantern_fuel[i] / 100.0)
				if lantern_fuel[i] < 30.0:
					lanterns[i].visible = fposmod(float(sim_tick) / 60.0, 1.0) < 0.5
				else:
					lanterns[i].visible = true
		else:
			if i < lantern_fuel_bars.size() and is_instance_valid(lantern_fuel_bars[i]):
				lantern_fuel_bars[i].visible = false
			lanterns[i].visible = true
	for charm in charm_states:
		if not charm["available"]:
			charm["respawn_ticks"] -= 1
			if charm["respawn_ticks"] <= 0:
				charm["available"] = true
				charm["node"].visible = true
	for shade_data in shade_states:
		shade_data.safe_ticks = maxi(0, int(shade_data.get("safe_ticks", 0)) - 1)
		if shade_data["spawn_ticks"] > 0:
			shade_data["spawn_ticks"] -= 1
			var material: StandardMaterial3D = shade_data["material"]
			var alpha := 1.0 - float(shade_data["spawn_ticks"]) / 60.0
			material.albedo_color.a = alpha
			if shade_data["spawn_ticks"] == 0:
				shade_data["state"] = "wander"
				shade_data["spawn_finished_tick"] = sim_tick
		elif shade_data["stun_ticks"] > 0:
			shade_data["stun_ticks"] -= 1
			if shade_data["stun_ticks"] == 0: shade_data["state"] = "wander"
	recoil_ticks = maxi(0, recoil_ticks)

func _move_player(delta: float, move_dir: Vector3) -> void:
	var old_position := player
	var old_floor := _ground_height(player.x, player.z)
	if Input.is_action_just_pressed("jump_game") and grounded:
		vertical_velocity = 7.0; grounded = false; $Phase2UI.play_sfx("jump")
	if Input.is_action_just_pressed("dash_game") and dash_time <= 0.0 and (dash_cooldown <= 0.0 or charm_ticks > 0):
		dash_direction = move_dir.normalized() if move_dir.length_squared() > 0.0 else facing_direction
		dash_time = 0.2
		if charm_ticks <= 0: dash_cooldown = 1.5
		$Phase2UI.play_sfx("dash")
	if recoil_ticks > 0:
		player += recoil_direction * 2.0 * delta
		recoil_ticks -= 1
	elif dash_time > 0.0:
		player.x += dash_direction.x * 14.0 * delta; player.z += dash_direction.z * 14.0 * delta
		dash_time = maxf(0.0, dash_time - delta)
	elif pad_launched:
		player += pad_horizontal_velocity * delta
		player.y += vertical_velocity * delta; vertical_velocity -= 20.0 * delta
	else:
		var max_speed := 7.2 if charm_ticks > 0 else 6.0
		var desired := move_dir.normalized() * max_speed if move_dir.length_squared() > 1.0 else move_dir * max_speed
		horizontal_velocity.x = move_toward(horizontal_velocity.x, desired.x, 60.0 * delta)
		horizontal_velocity.z = move_toward(horizontal_velocity.z, desired.z, 60.0 * delta)
		player.x += horizontal_velocity.x * delta; player.z += horizontal_velocity.z * delta
		if not grounded:
			player.y += vertical_velocity * delta; vertical_velocity -= 20.0 * delta
	_apply_wind(delta)
	var floor_y := _ground_height(player.x, player.z)
	if night == 3 and Vector2(player.x, player.z).length() < 2.0 and player.y < 14.0:
		player.x = old_position.x; player.z = old_position.z; floor_y = _ground_height(player.x, player.z)
	if dash_time <= 0.0 and grounded and floor_y > old_floor + 0.05 and not _on_ramp(player):
		player.x = old_position.x; player.z = old_position.z; horizontal_velocity = Vector3.ZERO; floor_y = old_floor
	elif dash_time <= 0.0 and is_finite(floor_y) and player.y <= floor_y and vertical_velocity <= 0.0:
		player.y = floor_y; vertical_velocity = 0.0; grounded = true; pad_launched = false
	else:
		grounded = false
	if grounded and night == 2:
		if Vector2(player.x-20.0, player.z-18.0).length() <= 1.0:
			pad_launched = true; grounded = false; vertical_velocity = 14.0; pad_horizontal_velocity = Vector3(24, 0, 0)
		elif Vector2(player.x-50.0, player.z+18.0).length() <= 1.0:
			pad_launched = true; grounded = false; vertical_velocity = 14.0; pad_horizontal_velocity = Vector3(-24, 0, 0)
	elif grounded and night == 3 and Vector3(player.x, player.y, player.z).distance_to(Vector3(0, 3, 13)) <= 1.0:
		pad_launched = true; grounded = false; vertical_velocity = 12.0; pad_horizontal_velocity = Vector3(0, 0, -8)

func _handle_fall() -> void:
	fall_triggered = true; flames -= 1; carried = 0; invulnerability = 1.5; respawn_ticks = 60
	vertical_velocity = 0.0; horizontal_velocity = Vector3.ZERO; pad_launched = false
	$Phase2UI.play_sfx("hit")

func _apply_wind(delta: float) -> void:
	if night != 3: return
	var elapsed := 360.0 - time_left
	var wind_phase := fposmod(elapsed, 30.0)
	if elapsed >= 28.0 and wind_phase < 5.0:
		var direction := deg_to_rad(float(int(elapsed / 30.0) * 47 % 360))
		if wind_phase >= 2.0:
			player.x += cos(direction) * 2.0 * delta; player.z += sin(direction) * 2.0 * delta

func _register_gameplay_actions() -> void:
	var mapping := {"jump_game": KEY_SPACE, "dash_game": KEY_SHIFT, "pulse_game": KEY_Q, "interact_game": KEY_E, "move_left_game": KEY_A, "move_right_game": KEY_D, "move_forward_game": KEY_W, "move_back_game": KEY_S}
	for action_name in mapping:
		if not InputMap.has_action(action_name): InputMap.add_action(action_name)
		var event := InputEventKey.new(); event.keycode = mapping[action_name]; InputMap.action_add_event(action_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless") and not get_tree().paused:
		var cfg := ConfigFile.new(); cfg.load("user://settings.cfg")
		var sensitivity := float(cfg.get_value("input", "sensitivity", 1.0))
		camera_yaw -= event.relative.x * sensitivity * 0.003

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	world_environment = world
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0E1430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("596080")
	env.ambient_light_energy = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color("1B2350")
	env.fog_light_energy = 0.65
	env.fog_density = 0.018
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("ffd9a0")
	sun.light_energy = 0.8
	add_child(sun)

	var island := MeshInstance3D.new()
	var island_mesh := CylinderMesh.new()
	island_mesh.top_radius = [0.0,40.0,28.0,45.0][night]
	island_mesh.bottom_radius = island_mesh.top_radius + 1.0
	island_mesh.height = 0.5
	island_mesh.radial_segments = 48
	island.mesh = island_mesh
	island.material_override = _material(Color("2F5D50"))
	island.position.y = -0.25
	add_child(island)
	if night == 2:
		_create_platform(Vector3(70, 0, 0), 28.0, Color("2F5D50"))
		_create_box(Vector3(35, 0.0, 0), Vector3(18, 0.22, 4), Color("6B4A2F"))
		_create_jump_pad(Vector3(20, 0, 18))
		_create_jump_pad(Vector3(50, 0, -18))
	elif night == 3:
		var upper_ring := MeshInstance3D.new()
		upper_ring.name = "Night3UpperTerrace"
		upper_ring.mesh = _build_half_ring_mesh(12.0, 24.0, 48)
		upper_ring.position = Vector3(0, 3, 0); upper_ring.material_override = _material(Color("C9B48A")); add_child(upper_ring)
		_create_platform(Vector3(0, 6, 0), 8.0, Color("2F5D50"))
		var tower := MeshInstance3D.new()
		var tower_mesh := CylinderMesh.new(); tower_mesh.top_radius = 2.0; tower_mesh.bottom_radius = 2.0; tower_mesh.height = 8.0
		tower.name = "Night3BellTower"; tower.mesh = tower_mesh; tower.position = Vector3(0, 10, 0); tower.material_override = _material(Color("6B4A2F")); add_child(tower)
		_create_jump_pad(Vector3(0, 3, 13))
		for angle in [30.0, 150.0]:
			var ramp := MeshInstance3D.new(); var ramp_mesh := BoxMesh.new(); ramp_mesh.size = Vector3(6.71, 0.3, 3)
			ramp.mesh = ramp_mesh; ramp.position = Vector3(27, 1.5, 0).rotated(Vector3.UP, -deg_to_rad(angle)); ramp.rotation.y = -deg_to_rad(angle); ramp.rotation.z = -atan2(3.0, 6.0); ramp.material_override = _material(Color("6B4A2F")); add_child(ramp)

	var player_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.height = 1.4
	body.radius = 0.35
	player_mesh.mesh = body
	player_mesh.material_override = _material(Color("E8E2D0"))
	player_mesh.name = "Player"
	player_mesh.position.y = 0.7
	add_child(player_mesh)
	var hat_brim := MeshInstance3D.new(); var brim := CylinderMesh.new(); brim.top_radius = 0.68; brim.bottom_radius = 0.68; brim.height = 0.08
	hat_brim.mesh = brim; hat_brim.position = Vector3(0, 0.72, 0); hat_brim.material_override = _material(Color("C9B48A")); player_mesh.add_child(hat_brim)
	var hat_top := MeshInstance3D.new(); var cone := CylinderMesh.new(); cone.top_radius = 0.03; cone.bottom_radius = 0.38; cone.height = 0.55
	hat_top.mesh = cone; hat_top.position = Vector3(0, 0.98, 0); hat_top.material_override = _material(Color("C9B48A")); player_mesh.add_child(hat_top)
	var carried_lantern := MeshInstance3D.new(); var tiny_lantern := SphereMesh.new(); tiny_lantern.radius = 0.12; tiny_lantern.height = 0.24
	carried_lantern.mesh = tiny_lantern; carried_lantern.position = Vector3(0.5, 0.2, -0.35); carried_lantern.material_override = _material(Color("FFB347")); player_mesh.add_child(carried_lantern)

	for i in LANTERN_POSITIONS[night].size():
		var lamp := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.45
		mesh.height = 2.0
		lamp.mesh = mesh
		lamp.material_override = _material(Color("5B5F6E"))
		lamp.position = LANTERN_POSITIONS[night][i] + Vector3(0, 1.0, 0)
		add_child(lamp)
		var lamp_light := OmniLight3D.new()
		lamp_light.light_color = Color("ffbd61")
		lamp_light.light_energy = 0.0
		lamp_light.omni_range = 5.0
		lamp.add_child(lamp_light)
		lanterns.append(lamp)
		lantern_progress.append(0)
		lantern_fuel.append(0.0)
		lantern_ever_lit.append(false)
		lantern_relit_count.append(0)
		var fuel_bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new(); bar_mesh.size = Vector3(1.0, 0.1, 0.1)
		fuel_bar.mesh = bar_mesh
		fuel_bar.material_override = _material(Color("00B3FF") if colorblind_mode else Color("FFB347"))
		fuel_bar.position = Vector3(0, 1.3, 0)
		fuel_bar.visible = false
		lamp.add_child(fuel_bar)
		lantern_fuel_bars.append(fuel_bar)
	var initial_points := _initial_mote_positions()
	if night == 1: initial_points.resize(20)
	for mote_position in initial_points:
		motes.append(mote_position)
		mote_ttl_ticks.append(-1)
		mote_kinds.append("random")

	for mote_position in motes:
		var mote := MeshInstance3D.new()
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.14
		mote_mesh.height = 0.28
		mote.mesh = mote_mesh
		mote.material_override = _material(Color("FFF6C2"))
		mote.position = mote_position + Vector3(0, 0.5, 0)
		add_child(mote)
		var mote_light := OmniLight3D.new()
		mote_light.light_color = Color("ffe58c")
		mote_light.light_energy = 0.8
		mote_light.omni_range = 2.0
		mote.add_child(mote_light)
		mote_nodes.append(mote)

	shade_spawn_remaining = 0.0

	var island_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 13.8
	ring_mesh.outer_radius = 14.2
	island_ring.mesh = ring_mesh
	island_ring.material_override = _material(Color("6b4b80"))
	island_ring.position.y = 0.05
	add_child(island_ring)

	game_camera = Camera3D.new()
	game_camera.position = player + Vector3(0, 12, -14)
	add_child(game_camera)
	game_camera.look_at(player)
	game_camera.current = true

	hud = null

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _initial_mote_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if night == 1:
		for degrees in range(0, 360, 45): points.append(Vector3(12, 0, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
		for i in 16: points.append(Vector3(33, 0, 0).rotated(Vector3.UP, deg_to_rad(float(i) * 22.5)))
	elif night == 2:
		for center_x in [0.0, 70.0]:
			for degrees in [0, 90, 180, 270]: points.append(Vector3(10, 0, 0).rotated(Vector3.UP, deg_to_rad(degrees)) + Vector3(center_x, 0, 0))
			for degrees in range(0, 360, 45): points.append(Vector3(22, 0, 0).rotated(Vector3.UP, deg_to_rad(degrees)) + Vector3(center_x, 0, 0))
	else:
		for degrees in range(0, 360, 20): points.append(Vector3(34, 0, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
		for degrees in range(20, 180, 20): points.append(Vector3(18, 3, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
		for degrees in [45, 135, 225, 315]: points.append(Vector3(5, 6, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
	return points

func _ground_height(x: float, z: float) -> float:
	var radius := Vector2(x, z).length()
	if night == 1: return 0.0 if radius <= 40.0 else -INF
	if night == 2:
		if Vector2(x, z).length() <= 28.0 or Vector2(x-70.0, z).length() <= 28.0: return 0.0
		return 0.0 if x >= 26.0 and x <= 44.0 and absf(z) <= 2.0 else -INF
	if radius <= 8.0: return 6.0
	if radius >= 12.0 and radius <= 24.0 and z > 0.0: return 3.0
	if _on_ramp(Vector3(x, 0, z)): return (30.0 - radius) * 0.5
	return 0.0 if radius <= 45.0 else -INF

func _on_ramp(at: Vector3) -> bool:
	var radius := Vector2(at.x, at.z).length()
	if radius < 24.0 or radius > 30.0: return false
	var angle := fposmod(rad_to_deg(atan2(at.z, at.x)), 360.0)
	return minf(absf(angle-30.0), absf(angle-150.0)) <= rad_to_deg(1.5 / maxf(radius, 1.0))

func _spawn_mote(at: Vector3, ttl_ticks: int = -1, kind: String = "random") -> void:
	motes.append(Vector3(at.x, _ground_height(at.x, at.z), at.z))
	mote_ttl_ticks.append(ttl_ticks)
	mote_kinds.append(kind)
	var mote := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.14; mesh.height = 0.28
	mote.mesh = mesh; mote.material_override = _material(Color("FFF6C2")); mote.position = motes[-1] + Vector3(0, 0.5, 0); add_child(mote)
	var light := OmniLight3D.new(); light.light_color = Color("FFE58A"); light.light_energy = 0.8; light.omni_range = 2.0; mote.add_child(light)
	mote_nodes.append(mote)

func _remove_mote(index: int) -> void:
	if index < 0 or index >= motes.size(): return
	motes.remove_at(index); mote_ttl_ticks.remove_at(index); mote_kinds.remove_at(index)
	if is_instance_valid(mote_nodes[index]): mote_nodes[index].queue_free()
	mote_nodes.remove_at(index)

func _setup_charms() -> void:
	var positions: Array[Vector3] = []
	if night == 2: positions = [Vector3(35, 0, 0)]
	elif night == 3: positions = [Vector3(30, 0, 25), Vector3(-30, 0, 25)]
	for i in positions.size():
		var node := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(0.5, 0.12, 0.35)
		node.mesh = mesh; node.material_override = _material(Color("C8102E")); node.position = positions[i] + Vector3(0, 0.18, 0); add_child(node)
		var rim := MeshInstance3D.new(); var rim_mesh := BoxMesh.new(); rim_mesh.size = Vector3(0.62, 0.07, 0.47); rim.mesh = rim_mesh; rim.material_override = _material(Color("F2C14E")); node.add_child(rim)
		charm_states.append({"id": "C%d" % (i + 1), "pos": positions[i], "node": node, "available": true, "respawn_ticks": 0})

func _collect_charms() -> void:
	if respawn_ticks > 0: return
	for charm in charm_states:
		if charm.available and Vector2(player.x - charm.pos.x, player.z - charm.pos.z).length() <= 1.0 and absf(player.y - charm.pos.y) <= 1.5:
			charm.available = false; charm.respawn_ticks = 2700; charm.node.visible = false; charm_ticks = 600
			$Phase2UI.play_sfx("pickup")

func _activate_pulse() -> void:
	if carried < 3 or pulse_cooldown > 0.0: return
	carried -= 3; pulse_cooldown = 3.0; $Phase2UI.play_sfx("pulse")
	var center := player + Vector3.UP * 0.8
	for shade_data in shade_states:
		if shade_data.state == "removed" or shade_data.spawn_ticks > 0 or center.distance_to(shade_data.node.position) > 5.0: continue
		var was_drain: bool = (shade_data.get("state") == "drain")
		shade_data.stun_ticks = 120; shade_data.state = "stunned"; shade_data.push_ticks = 15
		score += 15 if was_drain else 5
		var away: Vector3 = shade_data.node.position - player; away.y = 0.0
		shade_data.push_dir = away.normalized() if away.length_squared() > 0.0001 else Vector3.RIGHT
	for drifter in drifter_states:
		if drifter.state == "removed" or center.distance_to(drifter.node.position) > 5.0: continue
		if drifter.state == "chase": drifter.state = "flee"; drifter.ticks = 241
		elif drifter.state == "flee" and drifter.stolen > 0:
			for _i in drifter.stolen:
				_spawn_mote(drifter.node.position, 480, "dropped")
			drifter.stolen = 0
			drifter.state = "flee"
			drifter.ticks = 121

func _step_shades(delta: float) -> void:
	var hit_this_tick := false
	for shade_data in shade_states:
		if shade_data.state == "removed" or shade_data.spawn_ticks > 0: continue
		if shade_data.stun_ticks > 0:
			if shade_data.push_ticks > 0:
				shade_data.node.position += shade_data.push_dir * (4.0 / 15.0)
				shade_data.push_ticks -= 1
			continue
		var to_player: Vector3 = player - shade_data.node.position; to_player.y = 0.0
		var distance: float = to_player.length()
		if shade_data.state == "drain":
			if distance <= 6.0:
				shade_data.state = "chase"; shade_data["target_lantern_id"] = ""
			else:
				var target_idx := -1
				for i in lanterns.size():
					if ("L%d" % (i + 1)) == shade_data.get("target_lantern_id", ""): target_idx = i; break
				if target_idx < 0 or lantern_progress[target_idx] < 10 or lantern_fuel[target_idx] >= 30.0 or Vector2(shade_data.node.position.x - lanterns[target_idx].position.x, shade_data.node.position.z - lanterns[target_idx].position.z).length() > 2.0:
					shade_data.state = "wander"; shade_data["target_lantern_id"] = ""
			continue
		if shade_data.state == "recoil":
			shade_data.node.position += shade_data.recoil_dir * 2.0 * delta; shade_data.recoil_ticks -= 1
			if shade_data.recoil_ticks <= 0: shade_data.state = "chase" if distance <= 18.0 else "wander"
		elif distance <= 12.0:
			shade_data.state = "chase"; shade_data["target_lantern_id"] = ""
		elif distance > 18.0 and shade_data.state == "chase":
			shade_data.state = "wander"
		if shade_data.state == "wander":
			var chosen_target := -1
			var chosen_target_dist := INF
			for i in lanterns.size():
				if lantern_progress[i] >= 10 and lantern_fuel[i] < 30.0:
					var ld := Vector2(shade_data.node.position.x - lanterns[i].position.x, shade_data.node.position.z - lanterns[i].position.z).length()
					if ld < chosen_target_dist: chosen_target = i; chosen_target_dist = ld
			if chosen_target < 0:
				for i in lanterns.size():
					if lantern_progress[i] < 10:
						var ld := Vector2(shade_data.node.position.x - lanterns[i].position.x, shade_data.node.position.z - lanterns[i].position.z).length()
						if ld < chosen_target_dist: chosen_target = i; chosen_target_dist = ld
			if chosen_target >= 0:
				shade_data["target_lantern_id"] = "L%d" % (chosen_target + 1)
				var target_pos: Vector3 = lanterns[chosen_target].position
				var to_tgt := Vector2(target_pos.x - shade_data.node.position.x, target_pos.z - shade_data.node.position.z)
				var speed: float = 4.5 if night == 3 else 4.0
				if to_tgt.length() > 0.001:
					var step_vec := to_tgt.normalized() * speed * delta
					shade_data.node.position.x += step_vec.x
					shade_data.node.position.z += step_vec.y
				if lantern_progress[chosen_target] >= 10 and lantern_fuel[chosen_target] < 30.0 and to_tgt.length() <= 2.0:
					shade_data.state = "drain"
		if shade_data.state == "chase" and distance > 0.001:
			var candidate: Vector3 = shade_data.node.position + to_player.normalized() * (4.5 if night == 3 else 4.0) * delta
			var blocked := false
			for lamp_i in lanterns.size():
				if lantern_progress[lamp_i] < 10 or lantern_fuel[lamp_i] < 30.0: continue
				var lamp_pos: Vector3 = lanterns[lamp_i].position
				var candidate_offset := Vector2(candidate.x-lamp_pos.x, candidate.z-lamp_pos.z)
				if candidate_offset.length() < 6.0:
					var current_offset := Vector2(shade_data.node.position.x-lamp_pos.x, shade_data.node.position.z-lamp_pos.z)
					if current_offset.length() < 6.0:
						var push_out := current_offset.normalized() if current_offset.length_squared() > 0.001 else Vector2.RIGHT
						shade_data.node.position.x = lamp_pos.x + push_out.x * 6.0
						shade_data.node.position.z = lamp_pos.z + push_out.y * 6.0
					else: blocked = true
			if not blocked: shade_data.node.position = candidate
		if int(shade_data.get("safe_ticks", 0)) <= 0 and not hit_this_tick and respawn_ticks == 0 and invulnerability <= 0.0 and Vector2(shade_data.node.position.x-player.x, shade_data.node.position.z-player.z).length() <= 1.0 and absf(shade_data.node.position.y-player.y) <= 1.5:
			flames -= 1; hit_this_tick = true
			var dropped: int = carried / 2
			carried -= dropped
			for drop_i in dropped:
				var drop_angle := TAU * float(drop_i) / float(maxi(1, dropped))
				var drop_radius := 1.5 + 1.0 * float(drop_i % 2)
				_spawn_mote(player + Vector3(cos(drop_angle)*drop_radius, 0, sin(drop_angle)*drop_radius), 480, "dropped")
			invulnerability = 1.5
			var away: Vector3 = player - shade_data.node.position; away.y = 0; recoil_direction = away.normalized() if away.length_squared() > 0.001 else Vector3.RIGHT
			shade_data.state = "recoil"; shade_data.recoil_ticks = 60
			$Phase2UI.play_sfx("hit")

func _step_drifters(delta: float) -> void:
	for drifter in drifter_states:
		if drifter.state == "removed": continue
		var away: Vector3 = drifter.node.position - player; away.y = 0.0
		var distance: float = away.length()
		if drifter.state == "idle":
			if carried >= 5 and distance <= 15.0: drifter.state = "chase"
			else:
				drifter.phase += delta * (2.0 / 3.0)
				drifter.node.position = drifter.home + Vector3(cos(drifter.phase)*3.0, 0.0, sin(drifter.phase)*3.0)
				continue
		if drifter.state == "chase":
			if carried < 5 or distance > 15.0: drifter.state = "idle"; continue
			if distance > 0.001: drifter.node.position -= away.normalized() * 7.0 * delta
			if Vector2(drifter.node.position.x-player.x, drifter.node.position.z-player.z).length() <= 1.2:
				var amount := mini(3, carried); carried -= amount; drifter.stolen = amount; drifter.state = "flee"; drifter.ticks = 240
		elif drifter.state == "flee":
			if distance > 0.001: drifter.node.position += away.normalized() * 7.0 * delta
			drifter.ticks -= 1
			if drifter.ticks <= 0: drifter.state = "removed"; drifter.node.queue_free()

func _spawn_scheduled_entities() -> void:
	var first := 300 if night == 1 else (420 if night == 2 else 360)
	var interval := 480 if night == 1 else (420 if night == 2 else 360)
	if sim_tick >= first and (sim_tick - first) % interval == 0 and shade_states.size() < (6 if night == 1 else (8 if night == 2 else 10)):
		var positions := _shade_spawn_positions()
		for _i in (2 if night == 1 and sim_tick == first else 1):
			if shade_states.size() >= (6 if night == 1 else (8 if night == 2 else 10)): break
			var at: Vector3 = positions[(shade_states.size() + sim_tick) % positions.size()]
			if Vector2(at.x-player.x, at.z-player.z).length() < 15.0: continue
			_spawn_shade(at)
	if sim_tick % 240 == 0 and motes.size() < 30:
		for at in _initial_mote_positions():
			var occupied := false
			for existing in motes:
				if Vector2(existing.x-at.x, existing.z-at.z).length() < 0.25: occupied = true; break
			if not occupied: _spawn_mote(at); break
	var active_drifters := 0
	for drifter in drifter_states:
		if drifter.state != "removed": active_drifters += 1
	if night >= 2 and sim_tick % 1200 == 0 and active_drifters < 2:
		var positions := _shade_spawn_positions(); var at: Vector3 = positions[sim_tick % positions.size()]
		_spawn_drifter(at)

func _shade_spawn_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if night == 1:
		for degrees in range(15, 360, 30): out.append(Vector3(37*cos(deg_to_rad(degrees)), 1, 37*sin(deg_to_rad(degrees))))
	elif night == 2:
		for cx in [0.0,70.0]:
			for i in 8:
				var degrees := 22.5 + float(i) * 45.0
				out.append(Vector3(cx+26*cos(deg_to_rad(degrees)),1,26*sin(deg_to_rad(degrees))))
	else:
		for i in 16:
			var degrees := float(i) * 22.5
			out.append(Vector3(43*cos(deg_to_rad(degrees)),1,43*sin(deg_to_rad(degrees))))
	return out

func _spawn_shade(at: Vector3) -> void:
	var node := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.65; mesh.height = 1.3; node.mesh = mesh
	var mat := _material(Color("120A1A")); mat.albedo_color.a = 0.0; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = mat; node.position = at; add_child(node)
	shade_states.append({"id":"S%d" % next_shade_id,"node":node,"material":mat,"state":"spawning","spawn_ticks":60,"stun_ticks":0,"push_ticks":0,"push_dir":Vector3.RIGHT,"recoil_ticks":0,"recoil_dir":Vector3.RIGHT})
	next_shade_id += 1
	$Phase2UI.play_sfx("shade")

func _spawn_drifter(at: Vector3) -> void:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(0.35,1.8,1.4); node.mesh = mesh
	node.material_override = _material(Color("8FA3B8")); node.position = at; add_child(node)
	drifter_states.append({"id":"D%d" % next_drifter_id,"node":node,"state":"idle","stolen":0,"ticks":0,"home":at,"phase":0.0})
	next_drifter_id += 1

func _create_jump_pad(at: Vector3) -> void:
	var pad := MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius = 1; mesh.bottom_radius = 1; mesh.height = 0.25
	pad.mesh = mesh; pad.position = at + Vector3(0, 0.15, 0); pad.material_override = _material(Color("F2C14E")); add_child(pad)

func _show_pause_menu() -> void:
	if pause_layer: return
	get_tree().paused = true
	pause_layer = Control.new()
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 260)
	pause_layer.add_child(panel)
	var buttons := VBoxContainer.new()
	panel.add_child(buttons)
	for caption in ["Tiếp tục", "Chơi lại Đêm", "Cài đặt", "Về menu"]:
		var button := Button.new()
		button.text = caption
		buttons.add_child(button)
		if caption == "Tiếp tục":
			button.pressed.connect(func(): pause_layer.queue_free(); pause_layer = null; get_tree().paused = false)
		elif caption == "Chơi lại Đêm":
			button.pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
		elif caption == "Về menu":
			button.pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())

func _create_platform(at: Vector3, radius: float, color: Color) -> void:
	var platform := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = 0.5
	platform.mesh = shape
	platform.position = at + Vector3(0, -0.25, 0)
	platform.material_override = _material(color)
	add_child(platform)

func _build_half_ring_mesh(inner_radius: float, outer_radius: float, segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := PI * float(i) / float(segments)
		var a1 := PI * float(i + 1) / float(segments)
		var inner0 := Vector3(inner_radius * cos(a0), 0.0, inner_radius * sin(a0))
		var outer0 := Vector3(outer_radius * cos(a0), 0.0, outer_radius * sin(a0))
		var inner1 := Vector3(inner_radius * cos(a1), 0.0, inner_radius * sin(a1))
		var outer1 := Vector3(outer_radius * cos(a1), 0.0, outer_radius * sin(a1))
		for vertex in [inner0, outer1, outer0, inner0, inner1, outer1]: surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _create_box(at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.position = at
	node.material_override = _material(color)
	add_child(node)

func _update_hud() -> void:
	if hud:
		var status := "ĐÃ THẮP SÁNG ĐẢO!" if won else "Đêm 1 — Đảo Bến"
		hud.text = "%s\nMây  •  Máu: %d  •  Đom đóm: %d  •  Điểm: %d\nMũi tên: di chuyển   Enter: nhặt / nạp đèn" % [status, flames, carried, score]

func _collect_or_deposit() -> void:
	if carried <= 0: return
	var chosen := -1
	var chosen_distance := INF
	for idx in lanterns.size():
		var lamp: MeshInstance3D = lanterns[idx]
		var distance := Vector2(lamp.position.x - player.x, lamp.position.z - player.z).length()
		if distance <= 2.0:
			if lantern_progress[idx] < 10:
				if distance < chosen_distance or (is_equal_approx(distance, chosen_distance) and idx < chosen):
					chosen = idx; chosen_distance = distance
			elif lantern_fuel[idx] < 100.0:
				var needed := int(ceil((100.0 - lantern_fuel[idx]) / 10.0))
				if needed > 0 and (distance < chosen_distance or (is_equal_approx(distance, chosen_distance) and idx < chosen)):
					chosen = idx; chosen_distance = distance
	if chosen < 0: return

	if lantern_progress[chosen] < 10:
		var cost := 5 if lantern_ever_lit[chosen] else 10
		var amount := mini(carried, cost - lantern_progress[chosen])
		if amount <= 0: return
		carried -= amount
		lantern_progress[chosen] += amount
		score += amount * 5
		$Phase2UI.play_sfx("lantern")
		if lantern_progress[chosen] >= cost:
			lantern_progress[chosen] = 10
			lantern_fuel[chosen] = 100.0
			var is_relight := lantern_ever_lit[chosen]
			lantern_ever_lit[chosen] = true
			if is_relight:
				lantern_relit_count[chosen] += 1
				score += 40
			else:
				score += 100
			successful_lights += 1
			capacity = mini(20, 10 + 2 * successful_lights)
			lanterns[chosen].get_child(0).light_energy = 2.0
			var lamp_position: Vector3 = lanterns[chosen].position
			for shade_data in shade_states:
				var offset := Vector2(shade_data.node.position.x-lamp_position.x, shade_data.node.position.z-lamp_position.z)
				if offset.length() < 6.0:
					var outward := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
					shade_data.node.position.x = lamp_position.x + outward.x * 6.0
					shade_data.node.position.z = lamp_position.z + outward.y * 6.0
					shade_data.safe_ticks = 30
					if shade_data.get("state") == "drain" and shade_data.get("target_lantern_id") == ("L%d" % (chosen + 1)):
						shade_data["state"] = "wander"; shade_data["target_lantern_id"] = ""
			world_environment.environment.ambient_light_energy = 0.15 + 0.55 * float(lantern_progress.count(10)) / float(lantern_progress.size())
	else:
		var needed := int(ceil((100.0 - lantern_fuel[chosen]) / 10.0))
		var used := mini(carried, needed)
		if used > 0:
			var was_low := lantern_fuel[chosen] < 30.0
			carried -= used
			lantern_fuel[chosen] = minf(100.0, lantern_fuel[chosen] + float(used * 10))
			score += used * 5
			$Phase2UI.play_sfx("lantern")
			if was_low and lantern_fuel[chosen] >= 30.0:
				var lamp_pos: Vector3 = lanterns[chosen].position
				for shade_data in shade_states:
					if shade_data.get("state") == "drain" and shade_data.get("target_lantern_id") == ("L%d" % (chosen + 1)):
						shade_data["state"] = "wander"; shade_data["target_lantern_id"] = ""
					var offset := Vector2(shade_data.node.position.x-lamp_pos.x, shade_data.node.position.z-lamp_pos.z)
					if offset.length() < 6.0:
						var outward := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
						shade_data.node.position.x = lamp_pos.x + outward.x * 6.0
						shade_data.node.position.z = lamp_pos.z + outward.y * 6.0
						shade_data.safe_ticks = 30

func _evaluate_outcome() -> void:
	if won or lost or outcome_awarded: return
	if flames <= 0:
		lost = true
		outcome_awarded = true
		return
	if time_left <= 0.0:
		var lit_count := lantern_progress.count(10)
		var total_count := lanterns.size()
		var needed := int(ceil(0.6 * float(total_count)))
		if lit_count >= needed:
			won = true
			for i in lanterns.size():
				if lantern_progress[i] >= 10:
					score += 50 + int(floor(lantern_fuel[i]))
			score += flames * 50
			outcome_awarded = true
		else:
			lost = true
			outcome_awarded = true

func _collect_motes() -> void:
	if respawn_ticks > 0: return
	for i in range(motes.size() - 1, -1, -1):
		if carried < capacity and Vector2(motes[i].x-player.x, motes[i].z-player.z).length() <= 1.0 and absf(motes[i].y-player.y) <= 1.5:
			motes.remove_at(i)
			mote_ttl_ticks.remove_at(i)
			mote_kinds.remove_at(i)
			mote_nodes[i].queue_free()
			mote_nodes.remove_at(i)
			carried += 1
			$Phase2UI.play_sfx("pickup")

func _apply_accessibility() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		colorblind_mode = bool(cfg.get_value("accessibility", "colorblind", false))
	for shade_data in shade_states:
		if is_instance_valid(shade_data.get("node")):
			var mat: StandardMaterial3D = shade_data["material"]
			mat.albedo_color = Color("00B3FF") if colorblind_mode else Color("120A1A")
	for i in lanterns.size():
		if lantern_progress[i] < 10:
			lanterns[i].scale = Vector3(1.0, 0.8, 1.0) if colorblind_mode else Vector3.ONE
		else:
			lanterns[i].scale = Vector3.ONE

