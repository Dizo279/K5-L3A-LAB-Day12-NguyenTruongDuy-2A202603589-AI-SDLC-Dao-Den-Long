extends CanvasLayer

var game: Node
var hud: Label
var clock: Label
var prompt: Label
var lantern_arrow: Label
var overlay: ColorRect
var pause_menu: VBoxContainer
var settings_box: VBoxContainer
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var elapsed := 0.0
var fps_samples: Array[float] = []
var fps_written := false
var warning_active := false
var result_shown := false
var last_countdown_second := 11
var gameplay_active := false

func _ready() -> void:
	game = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_hud()
	_build_pause()
	_build_audio()
	_load_settings()
	var flow := ConfigFile.new()
	flow.load("user://night_flow.cfg")
	match str(flow.get_value("flow", "mode", "menu")):
		"intro":
			gameplay_active = false
			_set_game_hud(false)
			get_tree().paused = true
			_show_intro(int(flow.get_value("flow", "night", 1)))
		"play":
			gameplay_active = true
			_set_game_hud(true)
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			result_shown = false
		_:
			gameplay_active = false
			_set_game_hud(false)
			get_tree().paused = true
			_show_main_menu()

func _process(delta: float) -> void:
	if not fps_written:
		elapsed += delta
		if elapsed >= 2.0 and elapsed < 12.0:
			fps_samples.append(Engine.get_frames_per_second())
		if elapsed >= 12.0 and not fps_samples.is_empty():
			var total := 0.0
			for sample in fps_samples: total += sample
			var file := FileAccess.open("user://fps-1280x720.txt", FileAccess.WRITE)
			file.store_string("resolution=1280x720\nframes=%d\naverage_fps=%.2f\nminimum_sample_fps=%.2f\n" % [fps_samples.size(), total / fps_samples.size(), fps_samples.min()])
			fps_written = true
	if game == null or not gameplay_active: return
	if not result_shown and (bool(game.get("won")) or float(game.get("time_left")) <= 0.0 or int(game.get("flames")) <= 0):
		_show_result(bool(game.get("won")))
		return
	var left := maxf(0.0, float(game.get("time_left")))
	var sec := int(ceil(left))
	clock.text = "%02d:%02d" % [floori(float(sec) / 60.0), sec % 60]
	clock.add_theme_color_override("font_color", Color("FF5A5F") if sec <= 30 else Color("F5F1E6"))
	clock.visible = sec > 30 or fposmod(elapsed, 0.5) < 0.25
	var carried := clampi(int(game.get("carried")), 0, 10)
	var lantern_list: Array = game.get("lanterns")
	var progress: Array = game.get("lantern_progress")
	var lit_count := 0
	var nearest: MeshInstance3D = null
	var nearest_distance := INF
	var interact_near := false
	for i in lantern_list.size():
		var lamp: MeshInstance3D = lantern_list[i]
		var distance := Vector2(lamp.position.x - game.get("player").x, lamp.position.z - game.get("player").z).length()
		if i < progress.size() and progress[i] >= 10: lit_count += 1
		elif distance < nearest_distance:
			nearest = lamp
			nearest_distance = distance
		if i < progress.size() and progress[i] < 10 and distance <= 2.0: interact_near = true
	var dash_cd := float(game.get("dash_cooldown"))
	var pulse_cd := float(game.get("pulse_cooldown"))
	hud.text = "FLAMES  %s     LANTERNS  %d/%d     SCORE  %d\nFIREFLIES  %s     DASH %.1fs   PULSE %.1fs   WASD/ARROWS: MOVE   SPACE: JUMP   SHIFT: DASH   Q: PULSE" % ["● ".repeat(int(game.get("flames"))), lit_count, lantern_list.size(), int(game.get("score")), "●".repeat(carried) + "○".repeat(10-carried), dash_cd, pulse_cd]
	prompt.visible = interact_near
	prompt.text = "E — Charge lantern (%d/10)" % carried
	lantern_arrow.visible = false
	if nearest != null and nearest_distance > 2.0:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var screen_pos := camera.unproject_position(nearest.global_position)
			var viewport_size := get_viewport().get_visible_rect().size
			if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
				lantern_arrow.visible = true
				lantern_arrow.position = Vector2(clampf(screen_pos.x, 24, viewport_size.x-210), clampf(screen_pos.y, 60, viewport_size.y-60))
	var duration: float = [0.0, 300.0, 330.0, 360.0][int(game.get("night"))]
	var elapsed_night := duration - left
	var wind_phase := fposmod(elapsed_night, 30.0)
	var wind_now := int(game.get("night")) == 3 and elapsed_night >= 28.0 and wind_phase >= 28.0
	if wind_now:
		hud.text += "     WIND WARNING — gust soon"
		if not warning_active: play_sfx("wind")
	warning_active = wind_now
	if sec <= 10 and sec < last_countdown_second:
		play_sfx("wind")
	last_countdown_second = sec

func _build_hud() -> void:
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color("F5F1E6"))
	add_child(hud)
	clock = Label.new()
	clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock.add_theme_font_size_override("font_size", 26)
	add_child(clock)
	prompt = Label.new(); prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); prompt.position.y = -72; prompt.add_theme_font_size_override("font_size", 20); prompt.visible = false; add_child(prompt)
	lantern_arrow = Label.new(); lantern_arrow.text = "▲ NEXT LANTERN"; lantern_arrow.add_theme_font_size_override("font_size", 18); lantern_arrow.add_theme_color_override("font_color", Color("F2C14E")); lantern_arrow.visible = false; add_child(lantern_arrow)
	var action := InputEventKey.new(); action.keycode = KEY_ESCAPE
	if not InputMap.has_action("pause_game"): InputMap.add_action("pause_game")
	InputMap.action_add_event("pause_game", action)
	var p := InputEventKey.new(); p.keycode = KEY_P; InputMap.action_add_event("pause_game", p)

func _set_game_hud(show_hud: bool) -> void:
	for element in [hud, clock, prompt, lantern_arrow]:
		if is_instance_valid(element): element.visible = show_hud

func _build_pause() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.08, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	add_child(overlay)
	var panel := PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(360, 320); overlay.add_child(panel)
	pause_menu = VBoxContainer.new(); panel.add_child(pause_menu)
	for caption in ["PAUSED", "Resume", "Restart Night", "Settings", "Main Menu"]:
		if caption == "PAUSED":
			var header := Label.new(); header.text = caption; header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pause_menu.add_child(header); continue
		var button := Button.new(); button.text = caption; pause_menu.add_child(button)
		match caption:
			"Resume": button.pressed.connect(_resume)
			"Restart Night": button.pressed.connect(func(): get_tree().paused = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; get_tree().reload_current_scene())
			"Settings": button.pressed.connect(_show_settings)
			"Main Menu": button.pressed.connect(_return_to_menu)
	settings_box = VBoxContainer.new(); settings_box.visible = false; pause_menu.add_child(settings_box)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		if settings_box.visible:
			settings_box.visible = false; pause_menu.visible = true
		elif not _has_flow_overlay():
			overlay.visible = not overlay.visible
			get_tree().paused = overlay.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if overlay.visible else Input.MOUSE_MODE_CAPTURED

func _has_flow_overlay() -> bool:
	return get_tree().paused and overlay.visible == false

func _resume() -> void:
	overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _flow(mode: String, night_id: int = 1) -> void:
	gameplay_active = mode == "play"
	var cfg := ConfigFile.new(); cfg.set_value("flow", "mode", mode); cfg.set_value("flow", "night", night_id); cfg.save("user://night_flow.cfg")

func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_flow("menu", int(game.get("night")))
	get_tree().reload_current_scene()

func _show_main_menu() -> void:
	var root := _full_screen()
	var panel := PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(440, 300); root.add_child(panel)
	var list := VBoxContainer.new(); panel.add_child(list)
	var title := Label.new(); title.text = "LANTERN ISLAND"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; list.add_child(title)
	var names := ["Island of Harbor", "Island of Palms", "Island of Bells"]
	for i in 3:
		var night_id := i + 1
		var button := Button.new(); button.text = "NIGHT %d — %s" % [night_id, names[i]]; list.add_child(button); button.pressed.connect(func(): _choose_night(night_id))

func _choose_night(night_id: int) -> void:
	var cfg := ConfigFile.new(); cfg.load("user://night_flow.cfg")
	if night_id == 1: cfg.set_value("flow", "total_score", 0)
	cfg.set_value("flow", "night", night_id); cfg.set_value("flow", "mode", "intro"); cfg.save("user://night_flow.cfg")
	get_tree().reload_current_scene()

func _show_intro(night_id: int) -> void:
	var names := ["", "Island of Harbor", "Island of Palms", "Island of Bells"]
	var root := _full_screen()
	var panel := PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(440, 200); root.add_child(panel)
	var list := VBoxContainer.new(); panel.add_child(list)
	var quote := Label.new(); quote.text = "Night %d — %s\nElder Dang: The fog has swallowed every light. Bring the fireflies home." % [night_id, names[night_id]]; quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; list.add_child(quote)
	var begin := Button.new(); begin.text = "BEGIN NIGHT %d" % night_id; list.add_child(begin); begin.pressed.connect(func(): _flow("play", night_id); get_tree().paused = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; get_tree().reload_current_scene())
	var back := Button.new(); back.text = "BACK TO MENU"; list.add_child(back); back.pressed.connect(_return_to_menu)

func _full_screen() -> Control:
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(root)
	var shade := ColorRect.new(); shade.color = Color(0.02, 0.04, 0.12, 0.92); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(shade)
	return root

func _show_settings() -> void:
	pause_menu.visible = true
	settings_box.visible = true
	for child in pause_menu.get_children():
		if child != settings_box: child.visible = false
	for child in settings_box.get_children(): child.queue_free()
	var cfg := ConfigFile.new(); cfg.load("user://settings.cfg")
	var volume := HSlider.new(); volume.min_value = 0; volume.max_value = 1; volume.step = 0.01; volume.value = cfg.get_value("audio", "volume", 0.8); settings_box.add_child(volume)
	var volume_label := Label.new(); volume_label.text = "Master volume"; settings_box.add_child(volume_label)
	var sensitivity := HSlider.new(); sensitivity.min_value = 0.2; sensitivity.max_value = 3; sensitivity.step = 0.05; sensitivity.value = cfg.get_value("input", "sensitivity", 1.0); settings_box.add_child(sensitivity)
	var sensitivity_label := Label.new(); sensitivity_label.text = "Mouse sensitivity"; settings_box.add_child(sensitivity_label)
	var save := Button.new(); save.text = "Save settings"; settings_box.add_child(save)
	save.pressed.connect(func(): cfg.set_value("audio", "volume", volume.value); cfg.set_value("input", "sensitivity", sensitivity.value); cfg.save("user://settings.cfg"); AudioServer.set_bus_volume_linear(0, volume.value); _hide_settings())
	var back := Button.new(); back.text = "Back"; settings_box.add_child(back); back.pressed.connect(_hide_settings)

func _hide_settings() -> void:
	settings_box.visible = false
	for child in pause_menu.get_children():
		if child != settings_box: child.visible = true

func _show_result(won: bool) -> void:
	result_shown = true
	gameplay_active = false
	_set_game_hud(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_sfx("win" if won else "lose")
	var flow := ConfigFile.new(); flow.load("user://night_flow.cfg")
	var night_id := int(game.get("night"))
	var total := int(flow.get_value("flow", "total_score", 0))
	if won:
		total += int(game.get("score"))
		flow.set_value("flow", "total_score", total)
	flow.set_value("flow", "mode", "result")
	flow.save("user://night_flow.cfg")
	var root := _full_screen()
	var panel := PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(440, 240); root.add_child(panel)
	var list := VBoxContainer.new(); panel.add_child(list)
	var message := Label.new()
	message.text = "NIGHT CLEARED\nScore: %d" % int(game.get("score")) if won else "NIGHT LOST\nTry this night again."
	if won and night_id == 3: message.text = "DAWN\nTotal score: %d" % total
	list.add_child(message)
	if won and night_id < 3:
		var next := Button.new(); next.text = "CONTINUE TO NIGHT %d" % (night_id + 1); list.add_child(next); next.pressed.connect(func(): _flow("intro", night_id + 1); get_tree().paused = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; get_tree().reload_current_scene())
	else:
		var retry := Button.new(); retry.text = "REPLAY NIGHT" if not won else "BACK TO MENU"; list.add_child(retry)
		if not won: retry.pressed.connect(func(): _flow("play", night_id); get_tree().paused = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; get_tree().reload_current_scene())
		else: retry.pressed.connect(_return_to_menu)
	var menu_button := Button.new(); menu_button.text = "MAIN MENU"; list.add_child(menu_button); menu_button.pressed.connect(_return_to_menu)

func _build_audio() -> void:
	if DisplayServer.get_name() == "headless": return
	music = AudioStreamPlayer.new(); music.stream = _tone(110.0, 2.0, true); music.volume_db = -24; add_child(music); music.play()
	sfx = AudioStreamPlayer.new(); sfx.volume_db = -10; add_child(sfx)

func play_sfx(kind: String) -> void:
	if not is_instance_valid(sfx): return
	var hz := {"pickup": 880.0, "lantern": 520.0, "pulse": 330.0, "hit": 150.0, "jump": 660.0, "dash": 990.0, "win": 1040.0, "lose": 180.0, "shade": 240.0, "wind": 740.0}
	sfx.stream = _tone(float(hz.get(kind, 440.0)), 0.35, false); sfx.play()

func _tone(frequency: float, duration: float, looped: bool) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * duration); var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var envelope := 1.0 if looped else 1.0 - float(i) / count
		var fundamental := sin(TAU * frequency * float(i) / rate)
		if looped: fundamental = (fundamental + 0.5 * sin(TAU * frequency * 1.5 * float(i) / rate) + 0.25 * sin(TAU * frequency * 2.0 * float(i) / rate)) / 1.75
		data.encode_s16(i * 2, int(fundamental * 900.0 * envelope))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = rate; wav.stereo = false; wav.data = data
	if looped: wav.loop_mode = AudioStreamWAV.LOOP_FORWARD; wav.loop_end = count
	return wav

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK: AudioServer.set_bus_volume_linear(0, float(cfg.get_value("audio", "volume", 0.8)))
