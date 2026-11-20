extends Node3D

var player := Vector3.ZERO
var flames := 3
var carried := 0
var score := 0
var lanterns: Array[MeshInstance3D] = []
var motes: Array[Vector3] = []
var mote_nodes: Array[MeshInstance3D] = []
var won := false
var hud: Label

func _ready() -> void:
	_setup_world()
	_update_hud()

func _process(delta: float) -> void:
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.x += input_vec.x * 4.0 * delta
	player.z += input_vec.y * 4.0 * delta
	$Player.position = player + Vector3(0, 0.7, 0)
	if Input.is_action_just_pressed("ui_accept"):
		_collect_or_deposit()
	_update_hud()

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101326")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("596080")
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("ffd9a0")
	sun.light_energy = 0.8
	add_child(sun)

	var island := MeshInstance3D.new()
	var island_mesh := CylinderMesh.new()
	island_mesh.top_radius = 14.0
	island_mesh.bottom_radius = 15.0
	island_mesh.height = 0.5
	island_mesh.radial_segments = 48
	island.mesh = island_mesh
	island.material_override = _material(Color("263b35"))
	island.position.y = -0.25
	add_child(island)

	var player_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.height = 1.4
	body.radius = 0.35
	player_mesh.mesh = body
	player_mesh.material_override = _material(Color("d9c4a1"))
	player_mesh.name = "Player"
	player_mesh.position.y = 0.7
	add_child(player_mesh)

	for i in 5:
		var angle := TAU * float(i) / 5.0
		var lamp := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.45
		mesh.height = 2.0
		lamp.mesh = mesh
		lamp.material_override = _material(Color("e09a42"))
		lamp.position = Vector3(cos(angle) * 9.0, 1.0, sin(angle) * 9.0)
		add_child(lamp)
		lanterns.append(lamp)
		motes.append(lamp.position + Vector3(0, 0.5, 0))

	for mote_position in motes:
		var mote := MeshInstance3D.new()
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.14
		mote_mesh.height = 0.28
		mote.mesh = mote_mesh
		mote.material_override = _material(Color("ffe27a"))
		mote.position = mote_position
		add_child(mote)
		mote_nodes.append(mote)

	var shade := MeshInstance3D.new()
	var shade_mesh := SphereMesh.new()
	shade_mesh.radius = 0.6
	shade_mesh.height = 1.2
	shade.mesh = shade_mesh
	shade.material_override = _material(Color("342044"))
	shade.position = Vector3(0, 0.6, -6)
	shade.name = "Shade"
	add_child(shade)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 12, 14)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	add_child(camera)
	camera.current = true

	hud = Label.new()
	hud.position = Vector2(24, 24)
	hud.add_theme_font_size_override("font_size", 22)
	add_child(hud)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _update_hud() -> void:
	if hud:
		var status := "ĐÃ THẮP SÁNG ĐẢO!" if won else "Đêm 1 — Đảo Bến"
		hud.text = "%s\nMây  •  Máu: %d  •  Đom đóm: %d  •  Điểm: %d\nMũi tên: di chuyển   Enter: nhặt / nạp đèn" % [status, flames, carried, score]

func _collect_or_deposit() -> void:
	for i in motes.size():
		if motes[i].distance_to(player) <= 1.5:
			motes.remove_at(i)
			mote_nodes[i].queue_free()
			mote_nodes.remove_at(i)
			carried += 1
			score += 10
			return
	for lamp in lanterns:
		if lamp.position.distance_to(player) <= 2.0 and carried > 0:
			carried -= 1
			lamp.scale = Vector3.ONE * (1.0 + float(carried + 1) * 0.03)
			score += 100
			if score >= 500:
				won = true
			return

