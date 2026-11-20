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
	var flow_existed := FileAccess.file_exists("user://night_flow.cfg")
	var previous_flow := FileAccess.get_file_as_bytes("user://night_flow.cfg") if flow_existed else PackedByteArray()
	var game: Node = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().paused = false

	# 1. Night duration checks
	_check("Night 1 initial duration is 240s", is_equal_approx(float(game.time_left), 240.0))

	# 2. Fuel decay and lantern_out
	game.lantern_progress[0] = 10
	game.lantern_fuel[0] = 0.02
	game.lanterns[0].get_child(0).light_energy = 2.0
	game._advance_counters()
	game._advance_counters()
	_check("Lantern with depleted fuel turns off and sets ever_lit", game.lantern_progress[0] == 0 and game.lantern_ever_lit[0] and game.lantern_fuel[0] == 0.0 and is_equal_approx(game.lanterns[0].get_child(0).light_energy, 0.0))

	# 3. Relighting ever_lit lantern costs only 5 motes
	game.player = Vector3(0, 0, 24)
	game.lanterns[0].position = Vector3(0, 0, 25)
	game.carried = 7
	game.score = 0
	game.successful_lights = 0
	game._collect_or_deposit()
	_check("Relighting ever_lit lantern costs 5 motes, sets fuel 100, grants +65 score and increases capacity to 12", game.carried == 2 and game.lantern_progress[0] == 10 and game.lantern_fuel[0] == 100.0 and game.score == 65 and game.capacity == 12)

	# 4. Refueling lit lantern
	game.lantern_fuel[0] = 75.0
	game.carried = 5
	game.score = 0
	game._collect_or_deposit()
	# ceil((100-75)/10) = 3 motes needed
	_check("Refueling uses 3 motes, adds 15 score and restores fuel to 100", game.carried == 2 and is_equal_approx(game.lantern_fuel[0], 100.0) and game.score == 15)

	# 5. Full lantern ignored when refueling
	game.score = 0
	game._collect_or_deposit()
	_check("Full lantern is not chosen for interaction", game.carried == 2 and game.score == 0)

	# 6. Shade targeting weak lantern (< 30 fuel) and entering drain state
	game.lantern_fuel[0] = 20.0
	game._spawn_shade(Vector3(0, 0, 23)) # 2m from lantern at (0, 0, 25)
	game.shade_states[0].spawn_ticks = 0
	game.shade_states[0].state = "wander"
	game.player = Vector3(0, 0, -10) # Away from shade
	game._step_shades(0.0)
	_check("Shade near lantern with fuel < 30 enters drain state", game.shade_states[0].state == "drain")

	# 7. Pulse on draining shade awards 15 points
	game.player = Vector3(0, 0, 23)
	game.carried = 3
	game.pulse_cooldown = 0.0
	game.score = 0
	game._activate_pulse()
	_check("Pulse on draining shade awards 15 points", game.shade_states[0].state == "stunned" and game.score == 15)

	# 8. Refueling to >= 30 pushes shades and restores safe zone
	game.shade_states[0].state = "wander"
	game.shade_states[0].stun_ticks = 0
	game.shade_states[0].node.position = Vector3(0, 0, 24) # inside 6m safe zone
	game.carried = 2
	game.lantern_fuel[0] = 25.0
	game.player = Vector3(0, 0, 25)
	game._collect_or_deposit()
	# Refueled to 45.0 >= 30 -> safe zone pushes shade
	var dist_to_lamp: float = Vector2(game.shade_states[0].node.position.x - game.lanterns[0].position.x, game.shade_states[0].node.position.z - game.lanterns[0].position.z).length()
	_check("Refueling to >= 30 pushes shade to 6m safe radius", is_equal_approx(dist_to_lamp, 6.0))

	# 9. No early win when all lanterns lit
	game.won = false
	game.time_left = 100.0
	game.lantern_progress.fill(10)
	game._evaluate_outcome()
	_check("Thắp đủ đèn không thắng sớm khi time_left > 0", not game.won)

	# 10. Dawn survival win (>= 60% lit) and score bonus
	game.time_left = 0.0
	game.flames = 2
	game.score = 0
	game.won = false
	game.lost = false
	game.outcome_awarded = false
	for i in game.lanterns.size():
		game.lantern_progress[i] = 10 if i < 3 else 0 # 3 out of 5 lit = 60%
		game.lantern_fuel[i] = 60.0 if i < 3 else 0.0
	game._evaluate_outcome()
	# Expected score: 3 * (50 + 60) + 2 * 50 = 330 + 100 = 430
	_check("Dawn survival wins with 3/5 lanterns and calculates correct fuel bonus", game.won and game.score == 430)

	# 11. Dawn survival loss when < 60% lit
	game.won = false
	game.lost = false
	game.outcome_awarded = false
	game.lantern_progress[2] = 0 # only 2 lit < 3
	game._evaluate_outcome()
	_check("Dawn survival loses when less than 60% lit", game.lost and not game.won)

	# 12. Colorblind accessibility settings and visual cues
	var ui: Node = game.get_node("Phase2UI")
	ui.call("_show_settings")
	var settings: VBoxContainer = ui.get("settings_box")
	var cb_checkbox := settings.get_child(4) as CheckBox
	cb_checkbox.button_pressed = true
	(settings.get_child(5) as Button).emit_signal("pressed")
	var saved := ConfigFile.new()
	var saved_ok := saved.load("user://settings.cfg") == OK
	_check("Colorblind setting persists to settings.cfg", saved_ok and bool(saved.get_value("accessibility", "colorblind", false)))
	_check("Game applies colorblind mode", bool(game.colorblind_mode))
	ui.set("gameplay_active", true)
	game.time_left = 25.0
	ui.call("_process", 0.0)
	var clock_label := ui.get("clock") as Label
	_check("Colorblind mode displays warning symbol and white clock", clock_label.text.contains("⚠") and clock_label.get_theme_color("font_color") == Color("FFFFFF"))

	# Cleanup
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

	game.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Phase 3 graphical runtime checks passed")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
