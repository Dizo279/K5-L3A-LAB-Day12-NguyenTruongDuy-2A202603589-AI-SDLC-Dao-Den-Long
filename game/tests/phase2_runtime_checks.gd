extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func _run() -> void:
	var settings_existed := FileAccess.file_exists("user://settings.cfg")
	var previous_settings := FileAccess.get_file_as_bytes("user://settings.cfg") if settings_existed else PackedByteArray()
	var previous_master_volume := AudioServer.get_bus_volume_linear(0)
	var flow_existed := FileAccess.file_exists("user://night_flow.cfg")
	var previous_flow := FileAccess.get_file_as_bytes("user://night_flow.cfg") if flow_existed else PackedByteArray()
	var game: Node = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().paused = false

	game.player = Vector3.ZERO
	game.carried = 1
	game.flames = 2
	game.score = 0
	game.time_left = 30.5
	game.won = false
	for i in game.lanterns.size():
		game.lanterns[i].position = Vector3(100.0 + i * 10.0, 0.0, 100.0)
		game.lantern_progress[i] = 10
	game.lanterns[0].position = Vector3(0.0, 0.0, 1.0)
	game.lantern_progress[0] = 9
	game._collect_or_deposit()
	game._evaluate_outcome()
	_check("last lantern gets lit", game.lantern_progress[0] == 10 and game.won)
	_check("winning deposit includes time and flame bonus once", game.score == 270)

	game.won = false
	game.carried = 10
	game.score = 0
	game.lantern_progress.fill(0)
	for i in game.lanterns.size():
		game.lanterns[i].position = Vector3(100.0 + i * 10.0, 0.0, 100.0)
	game.lanterns[0].position = Vector3(0.0, 0.0, 1.8)
	game.lanterns[1].position = Vector3(0.0, 0.0, 0.5)
	game._collect_or_deposit()
	_check("interaction chooses closest eligible lantern", game.lantern_progress[1] == 10 and game.lantern_progress[0] == 0)

	var terrace: ArrayMesh = game._build_half_ring_mesh(12.0, 24.0, 48)
	var terrace_vertices: PackedVector3Array = terrace.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var terrace_valid := not terrace_vertices.is_empty()
	for vertex in terrace_vertices:
		var radius := Vector2(vertex.x, vertex.z).length()
		if vertex.z < -0.0001 or radius < 12.0 - 0.0001 or radius > 24.0 + 0.0001:
			terrace_valid = false
	_check("Night 3 upper terrace is only the z-positive half ring", terrace_valid)

	var ui: Node = game.get_node("Phase2UI")
	var pause_controls: Array[String] = []
	var pause_menu: VBoxContainer = ui.get("pause_menu")
	for child in pause_menu.get_children():
		if child is Button: pause_controls.append(child.text)
	_check("pause menu exposes resume, restart, settings and main menu", pause_controls.has("Resume") and pause_controls.has("Restart Night") and pause_controls.has("Settings") and pause_controls.has("Main Menu"))
	ui.call("_show_intro", 2)
	var intro_root: Control = ui.get_child(ui.get_child_count()-1)
	var intro_panel: PanelContainer = intro_root.get_child(1)
	var intro_label := intro_panel.get_child(0).get_child(0) as Label
	_check("night intro names the island and Elder Dang", intro_label.text.contains("Island of Palms") and intro_label.text.contains("Elder Dang"))
	ui.call("_show_main_menu")
	var menu_root: Control = ui.get_child(ui.get_child_count()-1)
	var menu_panel: PanelContainer = menu_root.get_child(1)
	var menu_buttons := menu_panel.get_child(0)
	_check("main menu offers all three night selections", menu_buttons.get_child_count() == 4)
	game.night = 1; game.score = 400
	ui.call("_show_result", true)
	var win_root: Control = ui.get_child(ui.get_child_count()-1)
	var win_panel: PanelContainer = win_root.get_child(1)
	var win_list: VBoxContainer = win_panel.get_child(0)
	_check("Night 1 result offers continuation to Night 2", win_list.get_child(1) is Button and (win_list.get_child(1) as Button).text == "CONTINUE TO NIGHT 2")
	win_root.queue_free()
	game.night = 2
	ui.call("_show_result", false)
	var loss_root: Control = ui.get_child(ui.get_child_count()-1)
	var loss_list: VBoxContainer = (loss_root.get_child(1) as PanelContainer).get_child(0)
	_check("loss result offers replay of the current night", loss_list.get_child(1) is Button and (loss_list.get_child(1) as Button).text == "REPLAY NIGHT")
	loss_root.queue_free()
	game.night = 3
	ui.call("_show_result", true)
	var dawn_root: Control = ui.get_child(ui.get_child_count()-1)
	var dawn_list: VBoxContainer = (dawn_root.get_child(1) as PanelContainer).get_child(0)
	_check("Night 3 result shows total-score dawn screen", (dawn_list.get_child(0) as Label).text.contains("DAWN") and (dawn_list.get_child(0) as Label).text.contains("Total score"))
	dawn_root.queue_free()
	game.night = 2
	game._setup_charms()
	game.player = Vector3(35, 0, 0)
	game._collect_charms()
	_check("Night 2 charm pickup grants 600 ticks and hides the charm", game.charm_ticks == 600 and not game.charm_states[0].available)
	for _tick in 2700: game._advance_counters()
	_check("charm respawns after 2700 simulation ticks", game.charm_states[0].available)

	for mote_node in game.mote_nodes: mote_node.queue_free()
	game.motes.clear(); game.mote_nodes.clear(); game.mote_ttl_ticks.clear(); game.mote_kinds.clear()
	game.player = Vector3.ZERO
	game.carried = 0
	game._spawn_mote(Vector3(0, 0, 0), 2, "dropped")
	game._collect_motes()
	_check("mote pickup is within XZ radius and capacity", game.carried == 1 and game.motes.is_empty())
	game._spawn_mote(Vector3(6, 0, 0), 2, "dropped")
	game._advance_counters(); game._advance_counters()
	_check("dropped mote expires at its TTL", game.motes.is_empty())

	game._spawn_shade(Vector3(20, 1, 0))
	for _tick in 60: game._advance_counters()
	_check("shade completes 60-tick spawning state", game.shade_states[0].state == "wander")
	game.player = Vector3(20, 0, 0)
	game.carried = 3
	game.score = 0
	game._activate_pulse()
	_check("pulse stuns shade, consumes three motes and awards stun points", game.shade_states[0].state == "stunned" and game.shade_states[0].stun_ticks == 120 and game.carried == 0 and game.score == 5)
	var shade_before: Vector3 = game.shade_states[0].node.position
	for _tick in 15: game._step_shades(1.0/60.0)
	_check("pulse pushes shade 4 metres during first 15 ticks", is_equal_approx(shade_before.distance_to(game.shade_states[0].node.position), 4.0))
	game._spawn_shade(Vector3(10, 1, 0))
	game.shade_states[1].spawn_ticks = 0; game.shade_states[1].state = "wander"
	game.player = Vector3(10.5, 0, 0); game.carried = 4; game.flames = 3; game.invulnerability = 0
	game._step_shades(0.0)
	_check("shade contact costs one flame and drops floor(carried/2)", game.flames == 2 and game.carried == 2 and game.motes.size() == 2)
	game.player = Vector3.ZERO
	game._spawn_drifter(Vector3(0.8, 0, 0))
	game.drifter_states[0].state = "chase"; game.carried = 5
	game._step_drifters(0.0)
	_check("drifter contact steals at most three motes without flame damage", game.carried == 2 and game.drifter_states[0].stolen == 3 and game.flames == 2)
	game.drifter_states[0].node.position = Vector3(1, 0, 0)
	game.carried = 3; game.pulse_cooldown = 0.0
	game._activate_pulse(); game._step_drifters(0.0)
	_check("pulse on loaded fleeing drifter drops stolen motes and starts 120-tick removal (stolen=%d ticks=%d motes=%d state=%s)" % [game.drifter_states[0].stolen, game.drifter_states[0].ticks, game.motes.size(), game.drifter_states[0].state], game.drifter_states[0].stolen == 0 and game.drifter_states[0].ticks == 120 and game.motes.size() == 5)
	for _tick in 120: game._step_drifters(0.0)
	_check("pulsed drifter is removed after its 120-tick linger", game.drifter_states[0].state == "removed")

	ui.call("_show_settings")
	var settings: VBoxContainer = ui.get("settings_box")
	var volume_slider := settings.get_child(0) as HSlider
	var sensitivity_slider := settings.get_child(2) as HSlider
	volume_slider.value = 0.37; sensitivity_slider.value = 2.0
	(settings.get_child(4) as Button).emit_signal("pressed")
	var saved := ConfigFile.new(); var saved_ok := saved.load("user://settings.cfg") == OK
	_check("settings persist volume and mouse sensitivity", saved_ok and is_equal_approx(float(saved.get_value("audio", "volume", 0.0)), 0.37) and is_equal_approx(float(saved.get_value("input", "sensitivity", 0.0)), 2.0))
	ui.call("_load_settings")
	_check("saved volume is applied when settings reload", is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.37))
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.camera_yaw = 0.0
	var mouse_motion := InputEventMouseMotion.new(); mouse_motion.relative = Vector2(100, 0)
	game._unhandled_input(mouse_motion)
	_check("saved mouse sensitivity controls camera yaw (yaw=%f captured=%s)" % [game.camera_yaw, str(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)], is_equal_approx(game.camera_yaw, -0.6))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var generated_tone: AudioStreamWAV = ui.call("_tone", 440.0, 0.1, false)
	_check("audio cue generator creates playable WAV data", generated_tone.data.size() > 0)
	ui.set("gameplay_active", true)
	ui.call("_process", 0.0)
	var hud_label := ui.get("hud") as Label
	_check("gameplay HUD includes flames, lanterns, score, motes and cooldowns", hud_label.text.contains("FLAMES") and hud_label.text.contains("LANTERNS") and hud_label.text.contains("PULSE"))
	if settings_existed:
		var restore_settings := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		restore_settings.store_buffer(previous_settings); restore_settings.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	if flow_existed:
		var restore_flow := FileAccess.open("user://night_flow.cfg", FileAccess.WRITE)
		restore_flow.store_buffer(previous_flow); restore_flow.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://night_flow.cfg"))
	AudioServer.set_bus_volume_linear(0, previous_master_volume)

	var music_player := ui.get("music") as AudioStreamPlayer
	var sfx_player := ui.get("sfx") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	if sfx_player != null:
		sfx_player.stop()
		sfx_player.stream = null
	game.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Phase 2 graphical runtime checks passed")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
