class_name GameWorld3D
extends Node3D

var game_state: String = "RACING"
var run_state: RunState = RunState.new()
var synergy_bus: PhysicsSynergyBus = PhysicsSynergyBus.new()
var upgrade_catalog: UpgradeCatalog = UpgradeCatalog.new()
var thrust_controller: LateralThrustController = LateralThrustController.new()

var track_generator: TrackGenerator3D = null
var player_ball: PlayerBall3D = null
var chase_camera: ChaseCamera3D = null
var hud_overlay: HudOverlay = null
var draft_panel: UpgradeDraftPanel = null
var summary_panel: RunSummaryPanel = null

var current_draft_choices: Array[UpgradeDefinition] = []
var override_tilt_input: Variant = null

var _vfx_rings: Array[Dictionary] = []
var _workbench_backdrop: MeshInstance3D = null


func _ready() -> void:
	_setup_lighting_and_sky()
	_setup_world_nodes()
	_setup_ui_layer()
	restart_run(0)


func _setup_lighting_and_sky() -> void:
	var is_headless := DisplayServer.get_name() == "headless"
	var env := Environment.new()
	if not is_headless:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.58, 0.76, 0.95)
		sky_mat.sky_horizon_color = Color(0.92, 0.90, 0.85)
		sky_mat.ground_horizon_color = Color(0.76, 0.68, 0.58)
		sky_mat.ground_bottom_color = Color(0.52, 0.42, 0.32)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.85, 0.88, 0.92)

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.96
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.82, 0.76)
	env.ambient_light_energy = 0.44
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.25
	env.glow_intensity = 0.22
	env.glow_bloom = 0.05

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "MainSunLight"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.89)
	sun.light_energy = 1.05
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_enabled = not is_headless
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFillLight"
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	fill.light_color = Color(0.80, 0.88, 1.0)
	fill.light_energy = 0.20
	fill.shadow_enabled = false
	add_child(fill)

	if not is_headless:
		_workbench_backdrop = MeshInstance3D.new()
		_workbench_backdrop.name = "WorkbenchBackdrop"
		var wb_box := BoxMesh.new()
		wb_box.size = Vector3(260.0, 1.0, 360.0)
		wb_box.material = MaterialLibrary.make_workbench_material(Color(0.46, 0.36, 0.26))
		_workbench_backdrop.mesh = wb_box
		_workbench_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_workbench_backdrop.rotation_degrees = Vector3(TrackGenerator3D.TRACK_SLOPE_PITCH_DEG, 0.0, 0.0)
		_workbench_backdrop.position = Vector3(0.0, -14.0, -120.0)

		var slat_mat := StandardMaterial3D.new()
		slat_mat.albedo_color = Color(0.24, 0.18, 0.12)
		slat_mat.roughness = 0.84
		slat_mat.metallic_specular = 0.10
		var slat_mesh_z := BoxMesh.new()
		slat_mesh_z.size = Vector3(0.16, 0.03, 360.0)
		slat_mesh_z.material = slat_mat
		for x_idx in range(-9, 10):
			if abs(x_idx) <= 1:
				continue
			var seam := MeshInstance3D.new()
			seam.mesh = slat_mesh_z
			seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			seam.position = Vector3(float(x_idx) * 8.5, 0.515, 0.0)
			_workbench_backdrop.add_child(seam)

		var slat_mesh_x := BoxMesh.new()
		slat_mesh_x.size = Vector3(260.0, 0.025, 0.16)
		slat_mesh_x.material = slat_mat
		for z_idx in range(-8, 9):
			var cross_seam := MeshInstance3D.new()
			cross_seam.mesh = slat_mesh_x
			cross_seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cross_seam.position = Vector3(0.0, 0.512, float(z_idx) * 18.0)
			_workbench_backdrop.add_child(cross_seam)

		add_child(_workbench_backdrop)


func _setup_world_nodes() -> void:
	track_generator = TrackGenerator3D.new()
	track_generator.name = "TrackGenerator3D"
	track_generator.finish_crossed.connect(on_finish_line_crossed)
	track_generator.barrel_detonated.connect(_on_barrel_detonated)
	track_generator.bonus_ring_collected.connect(_on_bonus_ring_collected)
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
	hud_overlay.seed_dialog_toggled.connect(_on_seed_dialog_toggled)
	hud_overlay.seed_submitted.connect(restart_run_with_seed_text)
	canvas.add_child(hud_overlay)

	draft_panel = UpgradeDraftPanel.new()
	draft_panel.upgrade_chosen.connect(select_draft_upgrade)
	canvas.add_child(draft_panel)

	summary_panel = RunSummaryPanel.new()
	summary_panel.restart_requested.connect(func() -> void: restart_run(0))
	summary_panel.restart_same_seed_requested.connect(restart_same_seed)
	summary_panel.restart_custom_seed_requested.connect(restart_run_with_seed_text)
	canvas.add_child(summary_panel)


func restart_run(seed_val: int = 0) -> void:
	synergy_bus.reset_all()
	run_state.start_new_run(seed_val)
	if hud_overlay != null:
		hud_overlay.close_seed_dialog(false)
	if draft_panel != null:
		draft_panel.visible = false
	if summary_panel != null:
		summary_panel.visible = false
	_start_level(1)


func restart_run_with_seed_text(raw_text: String) -> void:
	synergy_bus.reset_all()
	run_state.start_new_run_from_text(raw_text)
	if hud_overlay != null:
		hud_overlay.close_seed_dialog(false)
	if draft_panel != null:
		draft_panel.visible = false
	if summary_panel != null:
		summary_panel.visible = false
	_start_level(1)


func restart_same_seed() -> void:
	restart_run_with_seed_text(run_state.seed_text)


func _set_world_simulation_active(active: bool) -> void:
	if track_generator != null:
		track_generator.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_inside_tree() and get_world_3d() != null:
		PhysicsServer3D.space_set_active(get_world_3d().space, active)


func _sync_workbench_backdrop() -> void:
	if _workbench_backdrop == null or track_generator == null:
		return
	var ref_world := chase_camera.global_position if chase_camera != null else player_ball.global_position
	var cam_local := track_generator.world_to_track_local(ref_world)
	_workbench_backdrop.global_position = track_generator.track_local_to_world(
		Vector3(0.0, -14.5, cam_local.z - 110.0)
	)


func _start_level(level: int) -> void:
	_set_world_simulation_active(true)
	run_state.begin_level(level)
	synergy_bus.reset_level_transient()
	thrust_controller.reset()

	var level_seed := RunState.derive_track_seed(run_state.run_seed, level)
	track_generator.generate_track(level, level_seed)

	player_ball.track_reference = track_generator.get_track_root()
	player_ball.sync_from_stats()
	var start_pos := track_generator.track_local_to_world(Vector3(0.0, player_ball.current_radius + 0.15, -1.5))
	player_ball.reset_for_track(start_pos)
	chase_camera.snap_to_target(start_pos)
	_sync_workbench_backdrop()

	thrust_controller.apply_vertical_gravity_to_space(get_world_3d().space)

	game_state = "RACING"
	if hud_overlay != null:
		hud_overlay.seed_input_enabled = true
	_refresh_hud()


func _physics_process(delta: float) -> void:
	_update_vfx_rings(delta)
	if game_state == "RACING":
		simulate_race_step(delta)
	_sync_workbench_backdrop()


func simulate_race_step(delta: float) -> void:
	if game_state != "RACING":
		return

	var input_axis := _read_tilt_input()
	var lat_mult := synergy_bus.stats.get_stat("tilt_lateral_force_mult")
	var lat_accel := thrust_controller.compute_lateral_accel(input_axis, lat_mult, player_ball.is_airborne())
	player_ball.step_ball(delta, thrust_controller.current_axis, lat_accel)

	var spd := player_ball.linear_velocity.length()
	var ek := 0.5 * player_ball.mass * spd * spd
	run_state.record_physics_sample(spd, ek)

	chase_camera.update_camera(
		player_ball.global_position,
		thrust_controller.current_axis,
		spd,
		delta
	)

	var local_pos := track_generator.world_to_track_local(player_ball.global_position)
	if not player_ball.is_respawning and local_pos.z <= track_generator.finish_z:
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
		var vp := get_viewport()
		if vp != null and vp.gui_get_hovered_control() == null:
			var vp_size := vp.get_visible_rect().size
			if vp_size.x > 1.0:
				var mouse_x := vp.get_mouse_position().x
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


func _on_seed_dialog_toggled(is_open: bool) -> void:
	if is_open:
		if game_state != "RACING":
			return
		thrust_controller.reset()
		player_ball.set_paused(true)
		_set_world_simulation_active(false)
		game_state = "SEED_INPUT"
		_refresh_hud()
	else:
		if game_state != "SEED_INPUT":
			return
		game_state = "RACING"
		_set_world_simulation_active(true)
		player_ball.set_paused(false)
		_refresh_hud()


func on_finish_line_crossed() -> void:
	if game_state != "RACING":
		return
	if hud_overlay != null:
		hud_overlay.close_seed_dialog(false)
		hud_overlay.seed_input_enabled = false
	_set_world_simulation_active(true)
	game_state = "DRAFTING"
	thrust_controller.reset()
	player_ball.clear_thrust_indicators()
	player_ball.set_paused(true)

	var draft_rng := RandomNumberGenerator.new()
	draft_rng.seed = RunState.derive_draft_seed(run_state.run_seed, run_state.current_level)
	current_draft_choices = upgrade_catalog.roll_draft_choices(
		draft_rng,
		3,
		run_state.owned_upgrade_ids
	)
	_refresh_hud()
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
	if hud_overlay != null:
		hud_overlay.close_seed_dialog(false)
		hud_overlay.seed_input_enabled = false
	_set_world_simulation_active(true)
	game_state = "GAME_OVER"
	thrust_controller.reset()
	player_ball.clear_thrust_indicators()
	player_ball.set_paused(true)
	_refresh_hud()
	summary_panel.show_summary(run_state, _format_build_summary())


func _on_bonus_ring_collected(seconds: float) -> void:
	run_state.add_bonus_time(seconds)
	_refresh_hud()


func _on_target_smashed(_world_pos: Vector3) -> void:
	run_state.record_smash(1)
	chase_camera.add_shake(0.22)


func _on_barrel_detonated(origin: Vector3, radius: float, force: float, chain_depth: int) -> void:
	chase_camera.add_shake(0.38)
	if player_ball != null and not player_ball.is_respawning:
		var already_boosted := origin.distance_squared_to(player_ball.last_external_boost_origin) <= 0.0001
		if already_boosted:
			player_ball.last_external_boost_origin = Vector3(INF, INF, INF)
		else:
			var dist := player_ball.global_position.distance_to(origin)
			if dist <= radius:
				var falloff := clampf(1.0 - (dist / (radius * 1.25)), 0.35, 1.0)
				player_ball.notify_external_boost(
					ExplosiveBarrel.BALL_BLAST_IMPULSE_PER_KG * player_ball.mass * falloff,
					origin
				)
				player_ball.last_external_boost_origin = Vector3(INF, INF, INF)
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
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.72, 0.25, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.58, 0.15)
	mat.emission_energy_multiplier = 1.6
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
	var local_pos := track_generator.world_to_track_local(player_ball.global_position)
	var progress := clampf(absf(minf(0.0, local_pos.z)) / maxf(1.0, track_generator.total_length), 0.0, 1.0)
	hud_overlay.update_hud(
		run_state.current_level,
		run_state.time_remaining,
		player_ball.linear_velocity.length(),
		player_ball.mass,
		progress,
		synergy_bus.combo_stacks,
		synergy_bus.get_effective_impulse_mult(),
		player_ball.is_respawning,
		_format_build_summary(),
		run_state.seed_text,
		thrust_controller.current_axis
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
