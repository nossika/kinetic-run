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


func _ready() -> void:
	_setup_lighting_and_sky()
	_setup_world_nodes()
	_setup_ui_layer()
	restart_run(0)


func _setup_lighting_and_sky() -> void:
	var is_headless := DisplayServer.get_name() == "headless"
	var env := Environment.new()
	if not is_headless:
		var sky := Sky.new()
		var sky_tex := MaterialLibrary.load_storybook_sky_texture()
		if sky_tex != null:
			var pano_mat := PanoramaSkyMaterial.new()
			pano_mat.panorama = sky_tex
			pano_mat.energy_multiplier = 0.94
			sky.sky_material = pano_mat
		else:
			var sky_mat := ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color(0.28, 0.64, 0.92)
			sky_mat.sky_horizon_color = Color(0.68, 0.87, 0.98)
			sky_mat.ground_horizon_color = Color(0.68, 0.87, 0.98)
			sky_mat.ground_bottom_color = Color(0.46, 0.74, 0.94)
			sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.sky_rotation = Vector3(deg_to_rad(8.0), 0.0, 0.0)
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.62, 0.84, 0.96)

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.90
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.42
	env.ambient_light_color = Color(0.92, 0.95, 1.0)
	env.ambient_light_energy = 0.36

	# Subtle cool sky-blue horizon mist so warm wooden tracks and vivid toys pop cleanly
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.88, 0.98)
	env.fog_light_energy = 0.95
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.04

	env.glow_enabled = true
	env.glow_hdr_threshold = 1.45
	env.glow_intensity = 0.10
	env.glow_bloom = 0.02

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "MainSunLight"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 0.84
	sun.shadow_opacity = 0.78
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_enabled = not is_headless
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFillLight"
	fill.rotation_degrees = Vector3(-34.0, 148.0, 0.0)
	fill.light_color = Color(0.82, 0.90, 1.0)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)


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

	thrust_controller.apply_vertical_gravity_to_space(get_world_3d().space)

	game_state = "RACING"
	if hud_overlay != null:
		hud_overlay.seed_input_enabled = true
	_refresh_hud()


func _physics_process(delta: float) -> void:
	_update_vfx_rings(delta)
	if game_state == "RACING":
		simulate_race_step(delta)


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
	if player_ball != null and chase_camera != null:
		var shake_t := clampf(1.0 - player_ball.global_position.distance_to(origin) / 42.0, 0.0, 1.0)
		if shake_t > 0.0:
			chase_camera.add_shake(0.38 * shake_t)
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
	if track_generator == null:
		return
	var entities := track_generator.active_entities
	for i in range(entities.size() - 1, -1, -1):
		if not is_instance_valid(entities[i]):
			entities.remove_at(i)
	var count := entities.size()
	var snapshot: Array = []
	snapshot.resize(count)
	for i in range(count):
		snapshot[i] = entities[i]
	for i in range(count):
		var raw_ent: Variant = snapshot[i]
		if raw_ent == null or not is_instance_valid(raw_ent):
			continue
		var ent := raw_ent as Node3D
		if ent == null or ent.is_queued_for_deletion():
			continue
		if ent.has_method("apply_shockwave"):
			ent.apply_shockwave(origin, radius, force, chain_depth, player_ball)


func _spawn_vfx_ring(origin: Vector3, max_radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.84
	torus.outer_radius = 1.02
	torus.rings = 28
	torus.ring_segments = 14
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.99, 0.82, 0.52, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.98, 0.72, 0.36)
	mat.emission_energy_multiplier = 0.75
	torus.material = mat
	ring.mesh = torus
	ring.position = origin + Vector3(0.0, 0.18, 0.0)
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
		var t := clampf(elapsed / 0.28, 0.0, 1.0)
		var r := lerpf(0.3, float(item["max_r"]), t)
		node.scale = Vector3(r, 1.0 - t * 0.65, r)
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
		return "当前构筑：初始陶瓷球（冲过终点三选一强化）"
	var parts: Array[String] = []
	for def in active:
		var cnt := synergy_bus.get_upgrade_count(def.id)
		if cnt > 1:
			parts.append("%s x%d" % [def.title, cnt])
		else:
			parts.append(def.title)
	return "当前构筑：" + " · ".join(parts)
