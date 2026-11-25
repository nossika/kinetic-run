class_name GameWorld3D
extends Node3D

var game_state: String = "RACING"
var run_state: RunState = RunState.new()
var synergy_bus: PhysicsSynergyBus = PhysicsSynergyBus.new()
var upgrade_catalog: UpgradeCatalog = UpgradeCatalog.new()
var tilt_controller: GravityTiltController = GravityTiltController.new()

var track_generator: TrackGenerator3D = null
var player_ball: PlayerBall3D = null
var chase_camera: ChaseCamera3D = null
var hud_overlay: HudOverlay = null
var draft_panel: UpgradeDraftPanel = null
var summary_panel: RunSummaryPanel = null

var current_draft_choices: Array[UpgradeDefinition] = []
var override_tilt_input: Variant = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _vfx_rings: Array[Dictionary] = []


func _ready() -> void:
	_setup_lighting_and_sky()
	_setup_world_nodes()
	_setup_ui_layer()
	restart_run(0)


func _setup_lighting_and_sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.05, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.42, 0.65)
	env.ambient_light_energy = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.15

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(0.96, 0.97, 1.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = DisplayServer.get_name() != "headless"
	add_child(sun)


func _setup_world_nodes() -> void:
	track_generator = TrackGenerator3D.new()
	track_generator.name = "TrackGenerator3D"
	track_generator.finish_crossed.connect(on_finish_line_crossed)
	track_generator.barrel_detonated.connect(_on_barrel_detonated)
	add_child(track_generator)

	player_ball = PlayerBall3D.new()
	player_ball.name = "PlayerBall3D"
	add_child(player_ball)
	player_ball.setup(synergy_bus)
	player_ball.synergy_actions_requested.connect(_on_synergy_actions_requested)
	player_ball.target_smashed.connect(_on_target_smashed)

	chase_camera = ChaseCamera3D.new()
	chase_camera.name = "ChaseCamera3D"
	chase_camera.current = true
	add_child(chase_camera)


func _setup_ui_layer() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UILayer"
	add_child(canvas)

	hud_overlay = HudOverlay.new()
	canvas.add_child(hud_overlay)

	draft_panel = UpgradeDraftPanel.new()
	draft_panel.upgrade_chosen.connect(select_draft_upgrade)
	canvas.add_child(draft_panel)

	summary_panel = RunSummaryPanel.new()
	summary_panel.restart_requested.connect(func() -> void: restart_run(0))
	canvas.add_child(summary_panel)


func restart_run(seed_val: int = 0) -> void:
	synergy_bus.reset_all()
	run_state.start_new_run(seed_val)
	_rng.seed = run_state.run_seed
	draft_panel.visible = false
	summary_panel.visible = false
	_start_level(1)


func _start_level(level: int) -> void:
	run_state.begin_level(level)
	synergy_bus.reset_level_transient()
	tilt_controller.reset()

	var level_seed := run_state.run_seed + level * 7919
	track_generator.generate_track(level, level_seed)

	player_ball.sync_from_stats()
	var start_pos := Vector3(0.0, player_ball.current_radius + 0.15, -1.5)
	player_ball.reset_for_track(start_pos)
	chase_camera.snap_to_target(start_pos)

	var space_rid := get_world_3d().space
	tilt_controller.apply_to_space(space_rid, tilt_controller.compute_gravity_vector(0.0, 1.0))

	game_state = "RACING"
	_refresh_hud()


func _physics_process(delta: float) -> void:
	_update_vfx_rings(delta)
	if game_state == "RACING":
		simulate_race_step(delta)


func simulate_race_step(delta: float) -> void:
	if game_state != "RACING":
		return

	var input_axis := _read_tilt_input()
	var max_tilt := synergy_bus.stats.get_stat("max_tilt_deg")
	var lat_mult := synergy_bus.stats.get_stat("tilt_lateral_force_mult")
	var g_vec := tilt_controller.update_tilt(input_axis, max_tilt, delta, lat_mult)
	tilt_controller.apply_to_space(get_world_3d().space, g_vec)

	player_ball.step_ball(delta, tilt_controller.current_tilt_deg)

	var spd := player_ball.linear_velocity.length()
	var ek := 0.5 * player_ball.mass * spd * spd
	run_state.record_physics_sample(spd, ek)

	chase_camera.update_camera(
		player_ball.global_position,
		tilt_controller.current_tilt_deg,
		spd,
		delta
	)

	if not player_ball.is_respawning and player_ball.global_position.z <= track_generator.finish_z:
		on_finish_line_crossed()
		return

	if run_state.tick_timer(delta):
		_enter_game_over()
		return

	_refresh_hud()


func _read_tilt_input() -> float:
	if override_tilt_input != null:
		return clampf(float(override_tilt_input), -1.0, 1.0)

	var left_pressed := (
		Input.is_key_pressed(KEY_LEFT)
		or Input.is_physical_key_pressed(KEY_A)
	)
	var right_pressed := (
		Input.is_key_pressed(KEY_RIGHT)
		or Input.is_physical_key_pressed(KEY_D)
	)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var vp_size := get_viewport().get_visible_rect().size
		if vp_size.x > 1.0:
			var mouse_x := get_viewport().get_mouse_position().x
			if mouse_x < vp_size.x * 0.45:
				left_pressed = true
			elif mouse_x > vp_size.x * 0.55:
				right_pressed = true

	var axis := 0.0
	if left_pressed:
		axis -= 1.0
	if right_pressed:
		axis += 1.0
	return axis


func on_finish_line_crossed() -> void:
	if game_state != "RACING":
		return
	game_state = "DRAFTING"
	player_ball.freeze = true
	current_draft_choices = upgrade_catalog.roll_draft_choices(
		_rng,
		3,
		run_state.owned_upgrade_ids
	)
	draft_panel.show_choices(run_state.current_level, current_draft_choices)


func select_draft_upgrade(choice_index: int) -> void:
	if game_state != "DRAFTING":
		return
	if choice_index < 0 or choice_index >= current_draft_choices.size():
		return
	var chosen := current_draft_choices[choice_index]
	synergy_bus.apply_upgrade(chosen)
	run_state.record_upgrade(chosen.id)
	draft_panel.visible = false
	_start_level(run_state.current_level + 1)


func _enter_game_over() -> void:
	game_state = "GAME_OVER"
	player_ball.freeze = true
	summary_panel.show_summary(run_state, _format_build_summary())


func _on_target_smashed(_world_pos: Vector3) -> void:
	run_state.record_smash(1)
	chase_camera.add_shake(0.22)


func _on_barrel_detonated(origin: Vector3, radius: float, force: float, chain_depth: int) -> void:
	chase_camera.add_shake(0.38)
	_execute_shockwave(origin, radius, force, chain_depth)


func _on_synergy_actions_requested(actions: Dictionary) -> void:
	var bonus_t := float(actions.get("bonus_time", 0.0))
	if bonus_t > 0.0:
		run_state.add_bonus_time(bonus_t)
	var waves: Array = actions.get("shockwaves", [])
	for w in waves:
		var origin: Vector3 = w["origin"]
		var radius := float(w["radius"])
		var force := float(w["force"])
		var depth := int(w["chain_depth"])
		_execute_shockwave(origin, radius, force, depth)


func _execute_shockwave(origin: Vector3, radius: float, force: float, chain_depth: int) -> void:
	_spawn_vfx_ring(origin, radius)
	var snapshot := track_generator.active_entities.duplicate()
	for ent in snapshot:
		if ent == null or not is_instance_valid(ent):
			continue
		if ent.has_method("apply_shockwave"):
			ent.apply_shockwave(origin, radius, force, chain_depth, player_ball)


func _spawn_vfx_ring(origin: Vector3, max_radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.25, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.58, 0.15)
	mat.emission_energy_multiplier = 2.2
	cyl.material = mat
	ring.mesh = cyl
	ring.position = origin + Vector3(0.0, 0.15, 0.0)
	ring.scale = Vector3(0.2, 1.0, 0.2)
	add_child(ring)
	_vfx_rings.append({"node": ring, "elapsed": 0.0, "max_r": max_radius})


func _update_vfx_rings(delta: float) -> void:
	for i in range(_vfx_rings.size() - 1, -1, -1):
		var item: Dictionary = _vfx_rings[i]
		var node: MeshInstance3D = item["node"]
		if not is_instance_valid(node):
			_vfx_rings.remove_at(i)
			continue
		var elapsed := float(item["elapsed"]) + delta
		item["elapsed"] = elapsed
		var t := clampf(elapsed / 0.26, 0.0, 1.0)
		var r := lerpf(0.3, float(item["max_r"]), t)
		node.scale = Vector3(r, 1.0 - t * 0.7, r)
		if t >= 1.0:
			node.queue_free()
			_vfx_rings.remove_at(i)


func _refresh_hud() -> void:
	if hud_overlay == null:
		return
	var progress := clampf(absf(minf(0.0, player_ball.global_position.z)) / maxf(1.0, track_generator.total_length), 0.0, 1.0)
	hud_overlay.update_hud(
		run_state.current_level,
		run_state.time_remaining,
		player_ball.linear_velocity.length(),
		player_ball.mass,
		progress,
		synergy_bus.combo_stacks,
		synergy_bus.get_effective_impulse_mult(),
		player_ball.is_respawning,
		_format_build_summary()
	)


func _format_build_summary() -> String:
	var active := synergy_bus.get_active_upgrades()
	if active.is_empty():
		return "当前构筑：初始钨钢球（冲过终点三选一强化）"
	var parts: Array[String] = []
	for def in active:
		var cnt := synergy_bus.get_upgrade_count(def.id)
		if cnt > 1:
			parts.append("%s x%d" % [def.title, cnt])
		else:
			parts.append(def.title)
	return "当前构筑：" + " · ".join(parts)
