extends Node3D

var player := Vector3.ZERO
var flames := 3
var carried := 0
var score := 0
var lanterns: Array[MeshInstance3D] = []
var lantern_progress: Array[int] = []
var motes: Array[Vector3] = []
var mote_nodes: Array[MeshInstance3D] = []
var won := false
var hud: Label
var dash_time := 0.0
var dash_cooldown := 0.0
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
	time_left = [0.0,300.0,330.0,360.0][night]
	player = Vector3(0, 0, -15) if night == 3 else Vector3.ZERO
	_setup_world()
	_register_gameplay_actions()
	var ui_script := load("res://phase2_ui.gd")
	var ui = ui_script.new()
	ui.name = "Phase2UI"
	add_child(ui)
	if str(flow_cfg.get_value("flow", "mode", "menu")) == "play": ui.call_deferred("play_sfx", "shade")
	_update_hud()

func _physics_process(delta: float) -> void:
	if get_tree().paused: return
	sim_tick += 1
	time_left = maxf(0.0, time_left - delta)
	var input_vec := Input.get_vector("move_left_game", "move_right_game", "move_forward_game", "move_back_game")
	var forward := Vector3(sin(camera_yaw), 0, cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
	var move_dir := right * input_vec.x - forward * input_vec.y
	var old_position := player
	dash_cooldown = max(0.0, dash_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	shade_stun = maxf(0.0, shade_stun - delta)
	if Input.is_action_just_pressed("jump_game") and grounded:
		vertical_velocity = 7.0
		grounded = false
		$Phase2UI.play_sfx("jump")
	if Input.is_action_just_pressed("dash_game") and dash_cooldown <= 0.0 and move_dir.length() > 0.0:
		dash_time = 0.2
		dash_cooldown = 1.5
		$Phase2UI.play_sfx("dash")
	var speed := 14.0 if dash_time > 0.0 else 6.0
	dash_time = max(0.0, dash_time - delta)
	if pad_launched:
		player += pad_horizontal_velocity * delta
	else:
		player += move_dir.normalized() * speed * delta
	vertical_velocity -= 20.0 * delta
	player.y += vertical_velocity * delta
	var floor_y := _ground_height(player.x, player.z)
	if grounded and not Input.is_action_just_pressed("jump_game") and floor_y > old_position.y + 0.05 and not _on_ramp(player):
		player = old_position
		floor_y = _ground_height(player.x, player.z)
		vertical_velocity = 0.0
	elif floor_y > -INF and player.y <= floor_y and vertical_velocity <= 0.0:
		player.y = floor_y
		vertical_velocity = 0.0
		grounded = true
		pad_launched = false
	else:
		grounded = false
	if night == 2 and grounded:
		if Vector2(player.x-20.0, player.z-18.0).length() <= 1.0:
			pad_launched = true; grounded = false; vertical_velocity = 14.0; pad_horizontal_velocity = Vector3(24, 0, 0)
		elif Vector2(player.x-50.0, player.z+18.0).length() <= 1.0:
			pad_launched = true; grounded = false; vertical_velocity = 14.0; pad_horizontal_velocity = Vector3(-24, 0, 0)
	elif night == 3 and Vector3(player.x, player.y, player.z).distance_to(Vector3(0, 3, 13)) <= 1.0:
		pad_launched = true; grounded = false; vertical_velocity = 12.0; pad_horizontal_velocity = Vector3(0, 0, -8)
	$Player.position = player + Vector3(0, 0.7, 0)
	if is_instance_valid(game_camera):
		game_camera.position = player - forward * 14.0 + Vector3(0, 12, 0)
		game_camera.look_at(player)
	if Input.is_action_just_pressed("interact_game"):
		_collect_or_deposit()
	_collect_motes()
	if shade_spawn_remaining > 0.0:
		shade_spawn_remaining = maxf(0.0, shade_spawn_remaining - delta)
		if shade_spawn_remaining == 0.0:
			var spawn_radius := 37.0 if night == 1 else (26.0 if night == 2 else 43.0)
			shade.position = Vector3(spawn_radius * 0.707, 0.6, spawn_radius * 0.707)
			shade.visible = true
			$Phase2UI.play_sfx("shade")
	if Input.is_action_just_pressed("pulse_game") and carried >= 3 and pulse_cooldown <= 0.0:
		carried -= 3
		pulse_cooldown = 3.0
		if is_instance_valid(shade) and shade.visible and shade.position.distance_to(player + Vector3(0, 0.8, 0)) <= 5.0:
			shade_stun = 2.0
			shade_push_direction = Vector3(shade.position.x - player.x, 0, shade.position.z - player.z).normalized()
			if shade_push_direction.length_squared() == 0.0: shade_push_direction = Vector3.RIGHT
			shade_push_ticks = 15
			score += 5
		$Phase2UI.play_sfx("pulse")
	if is_instance_valid(shade) and shade.visible and shade_push_ticks > 0:
		shade.position += shade_push_direction * 4.0 * delta / (15.0 / 60.0)
		shade_push_ticks -= 1
	if is_instance_valid(shade) and shade.visible and shade_stun <= 0.0:
		var to_player := player - shade.position
		if to_player.length() <= 12.0 and to_player.length() > 0.01: shade.position += to_player.normalized() * 4.0 * delta
		if to_player.length() <= 1.0 and invulnerability <= 0.0:
			flames -= 1
			invulnerability = 1.5
			carried = floori(float(carried) / 2.0)
			$Phase2UI.play_sfx("hit")
	if night == 3 and time_left <= 330.0:
		var elapsed := 360.0 - time_left
		var wind_phase := fposmod(elapsed, 30.0)
		if elapsed >= 30.0 and wind_phase < 5.0:
			var direction := deg_to_rad(float(int(elapsed / 30.0) * 47 % 360))
			player.x += cos(direction) * 2.0 * delta
			player.z += sin(direction) * 2.0 * delta
	if night == 1 and sim_tick % 240 == 0 and motes.size() < 30:
		var points := _initial_mote_positions()
		for point in points:
			var occupied := false
			for existing in motes:
				if existing.distance_to(point) < 0.01: occupied = true; break
			if not occupied:
				_spawn_mote(point)
				break
	_update_hud()

func _register_gameplay_actions() -> void:
	var mapping := {"jump_game": KEY_SPACE, "dash_game": KEY_SHIFT, "pulse_game": KEY_Q, "interact_game": KEY_E, "move_left_game": KEY_A, "move_right_game": KEY_D, "move_forward_game": KEY_W, "move_back_game": KEY_S}
	for action_name in mapping:
		if not InputMap.has_action(action_name): InputMap.add_action(action_name)
		var event := InputEventKey.new(); event.keycode = mapping[action_name]; InputMap.action_add_event(action_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
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
		var ring := TorusMesh.new(); ring.inner_radius = 12; ring.outer_radius = 24; upper_ring.mesh = ring
		upper_ring.position = Vector3(0, 3, 0); upper_ring.material_override = _material(Color("C9B48A")); add_child(upper_ring)
		_create_platform(Vector3(0, 6, 0), 8.0, Color("2F5D50"))
		_create_box(Vector3(0, 10, 0), Vector3(4, 8, 4), Color("6B4A2F"))
		_create_jump_pad(Vector3(0, 3, 13))
		for angle in [30.0, 150.0]:
			var ramp := MeshInstance3D.new(); var ramp_mesh := BoxMesh.new(); ramp_mesh.size = Vector3(14, 0.3, 3)
			ramp.mesh = ramp_mesh; ramp.position = Vector3(27, 1.5, 0).rotated(Vector3.UP, deg_to_rad(angle)); ramp.rotation.y = deg_to_rad(angle); ramp.material_override = _material(Color("6B4A2F")); add_child(ramp)

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
		lamp.material_override = _material(Color("e09a42"))
		lamp.position = LANTERN_POSITIONS[night][i] + Vector3(0, 1.0, 0)
		add_child(lamp)
		var lamp_light := OmniLight3D.new()
		lamp_light.light_color = Color("ffbd61")
		lamp_light.light_energy = 0.0
		lamp_light.omni_range = 5.0
		lamp.add_child(lamp_light)
		lanterns.append(lamp)
		lantern_progress.append(0)
	var initial_points := _initial_mote_positions()
	if night == 1: initial_points.resize(20)
	for mote_position in initial_points: motes.append(mote_position)

	for mote_position in motes:
		var mote := MeshInstance3D.new()
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.14
		mote_mesh.height = 0.28
		mote.mesh = mote_mesh
		mote.material_override = _material(Color("ffe27a"))
		mote.position = mote_position
		add_child(mote)
		var mote_light := OmniLight3D.new()
		mote_light.light_color = Color("ffe58c")
		mote_light.light_energy = 0.8
		mote_light.omni_range = 2.0
		mote.add_child(mote_light)
		mote_nodes.append(mote)

	shade = MeshInstance3D.new()
	var shade_mesh := SphereMesh.new()
	shade_mesh.radius = 0.6
	shade_mesh.height = 1.2
	shade.mesh = shade_mesh
	shade.material_override = _material(Color("342044"))
	shade.position = Vector3(0, 0.6, -6)
	shade.name = "Shade"
	shade.visible = false
	add_child(shade)
	var shade_light := OmniLight3D.new()
	shade_light.light_color = Color("6d2d91")
	shade_light.light_energy = 1.5
	shade_light.omni_range = 3.0
	shade.add_child(shade_light)
	shade_spawn_remaining = 5.0

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
		for degrees in range(0, 360, 45): points.append(Vector3(12, 0.5, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
		for i in 16: points.append(Vector3(33, 0.5, 0).rotated(Vector3.UP, deg_to_rad(float(i) * 22.5)))
	elif night == 2:
		for center_x in [0.0, 70.0]:
			for degrees in [0, 90, 180, 270]: points.append(Vector3(10, 0.5, 0).rotated(Vector3.UP, deg_to_rad(degrees)) + Vector3(center_x, 0, 0))
			for degrees in range(0, 360, 45): points.append(Vector3(22, 0.5, 0).rotated(Vector3.UP, deg_to_rad(degrees)) + Vector3(center_x, 0, 0))
	else:
		for degrees in range(0, 360, 20): points.append(Vector3(34, 0.5, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
		for degrees in range(20, 180, 20): points.append(Vector3(18, 3.5, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
		for degrees in [45, 135, 225, 315]: points.append(Vector3(5, 6.5, 0).rotated(Vector3.UP, deg_to_rad(degrees)))
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

func _spawn_mote(at: Vector3) -> void:
	motes.append(at)
	var mote := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.14; mesh.height = 0.28
	mote.mesh = mesh; mote.material_override = _material(Color("FFF6C2")); mote.position = at; add_child(mote)
	var light := OmniLight3D.new(); light.light_color = Color("FFE58A"); light.light_energy = 0.8; light.omni_range = 2.0; mote.add_child(light)
	mote_nodes.append(mote)

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
	for lamp in lanterns:
		var idx := lanterns.find(lamp)
		if lamp.position.distance_to(player) <= 2.0 and carried > 0 and lantern_progress[idx] < 10:
			var amount := mini(carried, 10 - lantern_progress[idx])
			carried -= amount
			lantern_progress[idx] += amount
			lamp.scale = Vector3.ONE * (1.0 + float(lantern_progress[idx]) * 0.03)
			score += amount * 10
			$Phase2UI.play_sfx("lantern")
			if lantern_progress[idx] >= 10:
				score += 100
				lamp.get_child(0).light_energy = 2.0
				world_environment.environment.ambient_light_energy = 0.15 + 0.55 * float(lantern_progress.count(10)) / float(lantern_progress.size())
			if lantern_progress.all(func(value): return value >= 10): won = true
			return

func _collect_motes() -> void:
	for i in range(motes.size() - 1, -1, -1):
		if carried < 10 and motes[i].distance_to(player) <= 1.0:
			motes.remove_at(i)
			mote_nodes[i].queue_free()
			mote_nodes.remove_at(i)
			carried += 1
			$Phase2UI.play_sfx("pickup")

