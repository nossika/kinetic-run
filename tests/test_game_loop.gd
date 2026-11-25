extends TestBase


func run() -> void:
	await _test_main_scene_boots_and_rolls_forward()
	await _test_finish_draft_next_level_and_timeout_restart()
	await _test_emergent_build_outpaces_baseline_in_3d_simulation()
	await _test_vertical_gravity_zero_roll_and_slope_stability()
	await _test_deterministic_seed_across_levels_and_legendary_exclusion()
	await _test_hud_seed_modal_pause_bonus_ring_and_summary_seed_actions()


func _test_main_scene_boots_and_rolls_forward() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	assert_true(main_packed != null, "Main scene res://scenes/main.tscn must exist")
	if main_packed == null:
		return

	var world = main_packed.instantiate()
	scene_tree.root.add_child(world)
	await scene_tree.physics_frame

	assert_eq(world.game_state, "RACING", "Game starts in RACING state")
	assert_eq(world.run_state.current_level, 1, "Starts on Level 1")
	assert_approx(world.run_state.time_remaining, 30.0, 0.2, "Starts with ~30.0s countdown")

	var z_start: float = world.player_ball.global_position.z
	for _i in range(25):
		await scene_tree.physics_frame

	assert_lt(
		world.player_ball.global_position.z,
		z_start - 1.5,
		"PlayerBall3D automatically rolls forward along -Z under sloped gravity"
	)

	world.queue_free()
	await scene_tree.process_frame


func _test_finish_draft_next_level_and_timeout_restart() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if main_packed == null:
		return

	var world = main_packed.instantiate()
	scene_tree.root.add_child(world)
	await scene_tree.physics_frame

	var level1_finish_z: float = world.track_generator.finish_z

	# Simulate crossing finish line -> transitions to DRAFTING with 3 choices
	world.on_finish_line_crossed()
	assert_eq(world.game_state, "DRAFTING", "Crossing finish enters DRAFTING state")
	assert_eq(world.current_draft_choices.size(), 3, "Draft screen offers 3 upgrade choices")

	# Pick choice 0 -> advances to Level 2 with longer track and reset 30s timer
	var picked_id: String = world.current_draft_choices[0].id
	world.select_draft_upgrade(0)
	assert_eq(world.game_state, "RACING", "Selecting upgrade resumes RACING on next level")
	assert_eq(world.run_state.current_level, 2, "Advances to Level 2")
	assert_approx(world.run_state.time_remaining, 30.0, 0.05, "Level 2 resets timer to 30.0s")
	assert_true(world.run_state.owned_upgrade_ids.has(picked_id), "Selected upgrade recorded in RunState")
	assert_lt(world.track_generator.finish_z, level1_finish_z - 40.0, "Level 2 finish_z is substantially further than Level 1")

	# Simulate timeout -> enters GAME_OVER
	world.simulate_race_step(35.0)
	assert_eq(world.game_state, "GAME_OVER", "Expiring timer enters GAME_OVER state")

	# Restart run -> resets back to Level 1 with clean upgrades
	world.restart_run(777)
	assert_eq(world.game_state, "RACING", "Restart returns to RACING")
	assert_eq(world.run_state.current_level, 1, "Restart resets level to 1")
	assert_eq(world.run_state.owned_upgrade_ids.size(), 0, "Restart clears owned upgrades")

	world.queue_free()
	await scene_tree.process_frame


func _test_emergent_build_outpaces_baseline_in_3d_simulation() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if main_packed == null:
		return

	# 1. Baseline unupgraded run on Level 4 seeded track
	var world_base = main_packed.instantiate()
	scene_tree.root.add_child(world_base)
	await scene_tree.physics_frame
	world_base.restart_run(20261125)
	world_base._start_level(4)

	for frame in range(120):
		world_base.override_tilt_input = sin(float(frame) * 0.15)
		await scene_tree.physics_frame

	var base_dist: float = absf(world_base.player_ball.global_position.z)
	var base_peak_kmh: float = world_base.run_state.peak_speed_kmh
	world_base.queue_free()
	await scene_tree.process_frame

	# 2. Emergent synergy build on the exact same Level 4 seeded track
	var world_synergy = main_packed.instantiate()
	scene_tree.root.add_child(world_synergy)
	await scene_tree.physics_frame
	world_synergy.restart_run(20261125)
	for upg_id in [
		"tungsten_core",
		"giant_field",
		"tail_thruster",
		"tailwind_sail",
		"kinetic_furnace",
		"vector_refractor",
		"momentum_overload",
	]:
		world_synergy.synergy_bus.apply_upgrade(world_synergy.upgrade_catalog.get_upgrade(upg_id))
	world_synergy._start_level(4)

	for frame in range(120):
		world_synergy.override_tilt_input = sin(float(frame) * 0.15)
		await scene_tree.physics_frame

	var syn_dist: float = absf(world_synergy.player_ball.global_position.z)
	var syn_peak_kmh: float = world_synergy.run_state.peak_speed_kmh

	assert_gt(
		syn_dist,
		base_dist * 1.35,
		"Emergent physics build covers >1.35x distance of baseline ball in 2.0s simulation"
	)
	assert_gt(
		syn_peak_kmh,
		base_peak_kmh * 1.25,
		"Emergent physics build reaches substantially higher peak km/h than baseline"
	)

	world_synergy.queue_free()
	await scene_tree.process_frame


func _capture_world_track_state(world: Variant) -> Dictionary:
	var chunk_types: Array[String] = []
	for ch in world.track_generator.active_chunks:
		chunk_types.append(String(ch.chunk_type))

	var entity_records: Array[String] = []
	for ent in world.track_generator.active_entities:
		var node_ent := ent as Node3D
		if node_ent == null or not is_instance_valid(node_ent):
			continue
		var scr: Script = node_ent.get_script()
		var scr_path: String = scr.resource_path if scr != null else node_ent.get_class()
		var p: Vector3 = node_ent.position
		var extra: String = str(node_ent.get_meta("weight_label", ""))
		if node_ent is AerialBlocker:
			extra += "|phase=%0.4f" % (node_ent as AerialBlocker).initial_phase
		entity_records.append("%s@(%0.3f,%0.3f,%0.3f)[%s]" % [scr_path, p.x, p.y, p.z, extra])

	return {
		"chunk_types": chunk_types,
		"entity_records": entity_records,
	}


func _capture_draft_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for def in choices:
		ids.append(String(def.id))
	return ids


func _test_vertical_gravity_zero_roll_and_slope_stability() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if main_packed == null:
		return

	var world = main_packed.instantiate()
	scene_tree.root.add_child(world)
	await scene_tree.physics_frame

	assert_true("thrust_controller" in world, "GameWorld3D replaces tilt_controller with thrust_controller")
	assert_false("tilt_controller" in world, "GameWorld3D removes legacy tilt_controller property")

	# Pick a deterministic multi-chunk level where both 500g crates and 20kg ShieldBrutes sit down-slope
	if world.has_method("restart_run_with_seed_text"):
		world.call("restart_run_with_seed_text", "SLOPE_CHECK_2026")
	world._start_level(3)
	await scene_tree.physics_frame

	var space_rid: RID = world.get_world_3d().space
	var g_vec: Vector3 = PhysicsServer3D.area_get_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR)
	var g_mag: float = float(PhysicsServer3D.area_get_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY))
	assert_approx(g_vec.x, 0.0, 0.001, "World space gravity vector X is strictly 0.0")
	assert_approx(g_vec.y, -1.0, 0.001, "World space gravity vector Y is strictly -1.0")
	assert_approx(g_vec.z, 0.0, 0.001, "World space gravity vector Z is strictly 0.0")
	assert_approx(g_mag, 22.0, 0.01, "World space gravity magnitude is 22.0 m/s^2")
	assert_approx(world.chase_camera.rotation_degrees.z, 0.0, 0.001, "ChaseCamera3D roll is strictly 0.0 at start")

	# Record unhit 500g and 20kg rigidbodies far down the -11° slope (local Z < -45m so ball won't reach them in 30 frames)
	var tracked_500g: Array[Dictionary] = []
	var tracked_20kg: Array[Dictionary] = []
	for ent in world.track_generator.active_entities:
		var node_ent := ent as Node3D
		if node_ent == null or not is_instance_valid(node_ent) or node_ent.position.z > -45.0:
			continue
		var w_lbl := str(node_ent.get_meta("weight_label", ""))
		if w_lbl == "500g" and node_ent is RigidBody3D:
			tracked_500g.append({"node": node_ent, "start_pos": node_ent.position})
		elif w_lbl == "20kg" and node_ent is RigidBody3D:
			tracked_20kg.append({"node": node_ent, "start_pos": node_ent.position})

	assert_gt(float(tracked_500g.size()), 0.0, "Found unhit 500g RigidBody3D obstacles on sloped track")
	assert_gt(float(tracked_20kg.size()), 0.0, "Found unhit 20kg RigidBody3D obstacles on sloped track")

	var ball_start_world: Vector3 = world.player_ball.global_position
	var ball_start_local: Vector3 = world.track_generator.world_to_track_local(ball_start_world)

	# Simulate 30 physics frames, including lateral input frames to verify gravity & camera never tilt!
	for f in range(30):
		if f >= 10 and f < 20:
			world.override_tilt_input = 1.0
		else:
			world.override_tilt_input = 0.0
		await scene_tree.physics_frame
		var step_g_vec: Vector3 = PhysicsServer3D.area_get_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR)
		assert_approx(step_g_vec.x, 0.0, 0.001, "Space gravity X stays 0.0 even under lateral thrust input")
		assert_approx(world.chase_camera.rotation_degrees.z, 0.0, 0.001, "Camera roll stays 0.0 under lateral thrust input")

	var ball_end_world: Vector3 = world.player_ball.global_position
	var ball_end_local: Vector3 = world.track_generator.world_to_track_local(ball_end_world)
	assert_lt(ball_end_local.z, ball_start_local.z - 2.0, "PlayerBall3D rolls downhill along sloped track -Z")
	assert_lt(ball_end_world.y, ball_start_world.y - 0.3, "PlayerBall3D descends in world Y along -11° sloped track")

	var max_disp_500g := 0.0
	for item in tracked_500g:
		var rb := item["node"] as Node3D
		if rb != null and is_instance_valid(rb):
			max_disp_500g = maxf(max_disp_500g, rb.position.distance_to(item["start_pos"] as Vector3))
	assert_lt(max_disp_500g, 0.15, "Unhit 500g rigidbodies stay stationary on -11° slope (< 0.15m over 30 frames)")

	var max_disp_20kg := 0.0
	for item in tracked_20kg:
		var rb := item["node"] as Node3D
		if rb != null and is_instance_valid(rb):
			max_disp_20kg = maxf(max_disp_20kg, rb.position.distance_to(item["start_pos"] as Vector3))
	assert_lt(max_disp_20kg, 0.15, "Unhit 20kg rigidbodies stay stationary on -11° slope (< 0.15m over 30 frames)")

	world.queue_free()
	await scene_tree.process_frame


func _test_deterministic_seed_across_levels_and_legendary_exclusion() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if main_packed == null:
		return

	var world_a = main_packed.instantiate()
	var world_b = main_packed.instantiate()
	scene_tree.root.add_child(world_a)
	scene_tree.root.add_child(world_b)
	await scene_tree.physics_frame

	var has_seed_restart: bool = world_a.has_method("restart_run_with_seed_text")
	assert_true(has_seed_restart, "GameWorld3D exposes restart_run_with_seed_text(raw_text)")
	if not has_seed_restart:
		world_a.queue_free()
		world_b.queue_free()
		await scene_tree.process_frame
		return

	# 1. Exact reproduction of "TABLETOP2026" across Level 1 & Level 2 even when picking different stackable cards
	world_a.call("restart_run_with_seed_text", "TABLETOP2026")
	world_b.call("restart_run_with_seed_text", "TABLETOP2026")
	assert_eq(world_a.run_state.seed_text, "TABLETOP2026", "RunState preserves custom seed_text 'TABLETOP2026'")
	assert_eq(world_a.run_state.run_seed, world_b.run_state.run_seed, "Both runs derive identical run_seed")

	var l1_track_a := _capture_world_track_state(world_a)
	var l1_track_b := _capture_world_track_state(world_b)
	assert_eq(l1_track_a["chunk_types"], l1_track_b["chunk_types"], "TABLETOP2026 Level 1 chunks match 100%")
	assert_eq(l1_track_a["entity_records"], l1_track_b["entity_records"], "TABLETOP2026 Level 1 entities match 100%")

	world_a.on_finish_line_crossed()
	world_b.on_finish_line_crossed()
	var l1_draft_a := _capture_draft_ids(world_a.current_draft_choices)
	var l1_draft_b := _capture_draft_ids(world_b.current_draft_choices)
	assert_eq(l1_draft_a, l1_draft_b, "TABLETOP2026 Level 1 3-card draft choices match 100%")

	# Pick two different stackable upgrades on Level 1 (e.g. first stackable vs second stackable)
	var stackable_indices: Array[int] = []
	for idx in range(world_a.current_draft_choices.size()):
		if world_a.current_draft_choices[idx].stackable:
			stackable_indices.append(idx)
	assert_true(stackable_indices.size() >= 2, "Level 1 draft offers at least 2 stackable cards")
	var pick_a := stackable_indices[0] if stackable_indices.size() >= 1 else 0
	var pick_b := stackable_indices[1] if stackable_indices.size() >= 2 else 0

	world_a.select_draft_upgrade(pick_a)
	world_b.select_draft_upgrade(pick_b)

	var l2_track_a := _capture_world_track_state(world_a)
	var l2_track_b := _capture_world_track_state(world_b)
	assert_eq(l2_track_a["chunk_types"], l2_track_b["chunk_types"], "TABLETOP2026 Level 2 chunks match 100% despite different Level 1 picks")
	assert_eq(l2_track_a["entity_records"], l2_track_b["entity_records"], "TABLETOP2026 Level 2 entities match 100% despite different Level 1 picks")

	world_a.on_finish_line_crossed()
	world_b.on_finish_line_crossed()
	var l2_draft_a := _capture_draft_ids(world_a.current_draft_choices)
	var l2_draft_b := _capture_draft_ids(world_b.current_draft_choices)
	assert_eq(l2_draft_a, l2_draft_b, "TABLETOP2026 Level 2 3-card draft choices match 100% when both picked stackable Level 1 cards")

	# 2. Find a deterministic seed where both Level 1 and unowned Level 2 roll the same non-stackable legendary card
	var chosen_seed_str := ""
	var legendary_l1_idx := -1
	var stackable_l1_idx := -1
	var target_legendary_id := ""

	for candidate_num in range(1, 400):
		var cand_str := "LEGEND_SEED_%d" % candidate_num
		var parsed: Dictionary = RunState.parse_seed_input(cand_str)
		var r_seed := int(parsed["seed"])
		var rng1 := RandomNumberGenerator.new()
		rng1.seed = RunState.derive_draft_seed(r_seed, 1)
		var empty_owned: Array[String] = []
		var c1: Array[UpgradeDefinition] = world_a.upgrade_catalog.roll_draft_choices(rng1, 3, empty_owned)

		var leg_i := -1
		var stk_i := -1
		for i in range(c1.size()):
			if not c1[i].stackable and leg_i == -1:
				leg_i = i
			elif c1[i].stackable and stk_i == -1:
				stk_i = i
		if leg_i == -1 or stk_i == -1:
			continue

		var rng2 := RandomNumberGenerator.new()
		rng2.seed = RunState.derive_draft_seed(r_seed, 2)
		var c2: Array[UpgradeDefinition] = world_a.upgrade_catalog.roll_draft_choices(rng2, 3, empty_owned)
		for def2 in c2:
			if def2.id == c1[leg_i].id:
				chosen_seed_str = cand_str
				legendary_l1_idx = leg_i
				stackable_l1_idx = stk_i
				target_legendary_id = c1[leg_i].id
				break
		if chosen_seed_str != "":
			break

	assert_true(chosen_seed_str != "", "Found deterministic seed rolling same legendary on Level 1 and unowned Level 2")
	if chosen_seed_str != "":
		world_a.call("restart_run_with_seed_text", chosen_seed_str)
		world_b.call("restart_run_with_seed_text", chosen_seed_str)

		world_a.on_finish_line_crossed()
		world_b.on_finish_line_crossed()
		world_a.select_draft_upgrade(legendary_l1_idx) # Picks non-stackable legendary
		world_b.select_draft_upgrade(stackable_l1_idx) # Picks stackable common/rare

		var leg_l2_track_a := _capture_world_track_state(world_a)
		var leg_l2_track_b := _capture_world_track_state(world_b)
		assert_eq(leg_l2_track_a["chunk_types"], leg_l2_track_b["chunk_types"], "Picking Level 1 legendary keeps Level 2 chunks 100% identical")
		assert_eq(leg_l2_track_a["entity_records"], leg_l2_track_b["entity_records"], "Picking Level 1 legendary keeps Level 2 entities 100% identical")

		world_a.on_finish_line_crossed()
		world_b.on_finish_line_crossed()
		var leg_l2_draft_a := _capture_draft_ids(world_a.current_draft_choices)
		var leg_l2_draft_b := _capture_draft_ids(world_b.current_draft_choices)
		assert_true(leg_l2_draft_b.has(target_legendary_id), "Control run (unowned legendary) rolls legendary on Level 2")
		assert_false(leg_l2_draft_a.has(target_legendary_id), "Picking non-stackable legendary on Level 1 excludes it from Level 2 draft")

	world_a.queue_free()
	world_b.queue_free()
	await scene_tree.process_frame


func _test_hud_seed_modal_pause_bonus_ring_and_summary_seed_actions() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if main_packed == null:
		return

	var world = main_packed.instantiate()
	scene_tree.root.add_child(world)
	await scene_tree.physics_frame

	assert_true(world.hud_overlay.has_signal("seed_submitted"), "HudOverlay defines signal seed_submitted")
	assert_true(world.hud_overlay.has_signal("seed_dialog_toggled"), "HudOverlay defines signal seed_dialog_toggled")
	assert_true(world.summary_panel.has_signal("restart_same_seed_requested"), "RunSummaryPanel defines signal restart_same_seed_requested")
	assert_true(world.summary_panel.has_signal("restart_custom_seed_requested"), "RunSummaryPanel defines signal restart_custom_seed_requested")

	if not world.has_method("restart_run_with_seed_text"):
		world.queue_free()
		await scene_tree.process_frame
		return

	world.call("restart_run_with_seed_text", "RING_AND_MODAL_88")
	await scene_tree.physics_frame

	# 1. Bonus ring signal adds +0.8s to RunState countdown
	world.run_state.time_remaining = 20.0
	world.track_generator.bonus_ring_collected.emit(0.8)
	assert_approx(world.run_state.time_remaining, 20.8, 0.01, "bonus_ring_collected adds +0.8s to RunState.time_remaining")

	# 2. Opening HUD seed modal pauses countdown and freezes ball; cancelling resumes cleanly
	if world.hud_overlay.has_method("open_seed_dialog") and world.hud_overlay.has_method("close_seed_dialog"):
		var pre_vel: Vector3 = Vector3(0.0, -1.5, -14.0)
		world.player_ball.linear_velocity = pre_vel
		var paused_time: float = world.run_state.time_remaining

		world.hud_overlay.call("open_seed_dialog")
		assert_eq(world.game_state, "SEED_INPUT", "Opening seed modal switches game_state to SEED_INPUT")
		assert_true(world.player_ball.freeze, "Opening seed modal freezes PlayerBall3D")

		for _f in range(10):
			await scene_tree.physics_frame
		assert_approx(world.run_state.time_remaining, paused_time, 0.001, "Countdown timer stays paused while SEED_INPUT modal is open")

		world.hud_overlay.call("close_seed_dialog")
		assert_eq(world.game_state, "RACING", "Cancelling seed modal resumes RACING state")
		assert_false(world.player_ball.freeze, "Cancelling seed modal unfreezes PlayerBall3D")
		assert_lt(world.player_ball.linear_velocity.z, -10.0, "Cancelling seed modal preserves PlayerBall3D forward velocity")

		# Submitting a new seed via HUD modal restarts run on Level 1 with that seed
		world.hud_overlay.call("open_seed_dialog")
		world.hud_overlay.emit_signal("seed_submitted", "WORKSHOP_777")
		assert_eq(world.game_state, "RACING", "Submitting seed from HUD modal restarts in RACING state")
		assert_eq(world.run_state.seed_text, "WORKSHOP_777", "HUD seed submission sets RunState.seed_text to WORKSHOP_777")

	# 3. Debris-triggered barrel blast boosts nearby ball without double-boosting ball-triggered blasts
	var barrel_ball = TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, -20.0))
	world.track_generator._spawn_entity(barrel_ball)
	world.player_ball.global_position = world.track_generator.track_local_to_world(Vector3(0.0, 0.7, -21.0))
	world.player_ball.linear_velocity = -world.track_generator.get_track_root().global_transform.basis.z.normalized() * 10.0
	barrel_ball._on_sensor_body_entered(world.player_ball)
	var speed_after_ball_blast: float = world.player_ball.linear_velocity.length()
	assert_gt(speed_after_ball_blast, 22.0, "Ball-triggered barrel blast boosts player_ball forward")
	assert_lt(speed_after_ball_blast, 30.0, "Ball-triggered barrel blast boosts player_ball exactly once (no double boost)")

	var barrel_debris = TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, -30.0))
	var fast_debris = TrackEntityFactory.create_crate(Vector3(0.0, 0.65, -29.0), "light")
	world.track_generator._spawn_entity(barrel_debris)
	world.track_generator._spawn_entity(fast_debris)
	world.player_ball.global_position = world.track_generator.track_local_to_world(Vector3(0.0, 0.7, -31.5))
	world.player_ball.linear_velocity = -world.track_generator.get_track_root().global_transform.basis.z.normalized() * 10.0
	fast_debris.linear_velocity = Vector3(0.0, 4.0, -15.0)
	barrel_debris._on_sensor_body_entered(fast_debris)
	assert_gt(world.player_ball.linear_velocity.length(), 20.0, "Debris-triggered barrel blast boosts nearby player_ball")

	# 4. RunSummaryPanel same-seed and custom-seed signals
	world.simulate_race_step(35.0)
	assert_eq(world.game_state, "GAME_OVER", "Timeout enters GAME_OVER")
	world.summary_panel.emit_signal("restart_same_seed_requested")
	assert_eq(world.game_state, "RACING", "restart_same_seed_requested restarts run in RACING")
	assert_eq(world.run_state.seed_text, "WORKSHOP_777", "restart_same_seed_requested preserves previous seed_text")

	world.simulate_race_step(35.0)
	world.summary_panel.emit_signal("restart_custom_seed_requested", "CUSTOM_SEED_999")
	assert_eq(world.game_state, "RACING", "restart_custom_seed_requested restarts run in RACING")
	assert_eq(world.run_state.seed_text, "CUSTOM_SEED_999", "restart_custom_seed_requested applies CUSTOM_SEED_999")

	world.queue_free()
	await scene_tree.process_frame
