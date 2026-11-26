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

	assert_eq(world.game_state, "START_SCREEN", "Game boots into START_SCREEN with pre-generated seed and 3 starter balls")
	assert_true(world.run_state.seed_text != "", "Boot automatically generates non-empty random seed")
	assert_eq(world.current_starter_balls.size(), 3, "Start screen rolls 3 starter ball options from seed")
	assert_true(world.start_screen_panel != null and world.start_screen_panel.visible, "StartScreenPanel is visible on boot")
	assert_false(world.hud_overlay.visible, "HudOverlay is hidden while on START_SCREEN")

	var boot_z: float = world.player_ball.global_position.z
	for _i in range(10):
		await scene_tree.physics_frame
	assert_approx(world.player_ball.global_position.z, boot_z, 0.01, "Ball stays paused at start gate while on START_SCREEN")

	# Changing seed on START_SCREEN deterministically regenerates starter balls & track
	world.set_start_screen_seed_text("STORY_START_101")
	var snap_101_names: Array[String] = [
		world.current_starter_balls[0].display_name,
		world.current_starter_balls[1].display_name,
		world.current_starter_balls[2].display_name,
	]
	world.set_start_screen_seed_text("STORY_START_202")
	var snap_202_names: Array[String] = [
		world.current_starter_balls[0].display_name,
		world.current_starter_balls[1].display_name,
		world.current_starter_balls[2].display_name,
	]
	assert_true(snap_101_names != snap_202_names, "Changing seed on StartScreen regenerates the 3 starter balls")
	world.set_start_screen_seed_text("STORY_START_101")
	assert_eq(
		world.current_starter_balls[1].display_name,
		snap_101_names[1],
		"Re-entering same seed on StartScreen reproduces identical starter balls"
	)

	# Verify StartScreenPanel renders real-time 3D SubViewport previews for all 3 starter balls
	var has_3d_previews: bool = world.start_screen_panel.has_method("get_preview_widgets")
	assert_true(has_3d_previews, "StartScreenPanel exposes get_preview_widgets() for real 3D starter ball previews")
	var previews: Array = world.start_screen_panel.call("get_preview_widgets") if has_3d_previews else []
	assert_eq(previews.size(), 3, "StartScreenPanel creates 3 real-time 3D starter ball preview viewports")
	for idx in range(previews.size()):
		var prev := previews[idx] as SubViewportContainer
		var ball_def: StarterBallDefinition = world.current_starter_balls[idx]
		assert_true(prev != null, "Card %d preview is a SubViewportContainer" % idx)
		if prev != null:
			var sub_vp := prev.get_node_or_null("PreviewViewport") as SubViewport
			assert_true(sub_vp != null and sub_vp.own_world_3d, "Card %d preview uses isolated own_world_3d SubViewport" % idx)
			var mesh_inst: MeshInstance3D = prev.call("get_ball_mesh_instance")
			assert_true(mesh_inst != null and mesh_inst.mesh != null, "Card %d preview builds real 3D ball Mesh" % idx)
			if mesh_inst != null and mesh_inst.mesh != null:
				if ball_def.shape_type == "sphere":
					assert_true(mesh_inst.mesh is SphereMesh, "Sphere starter ball preview uses SphereMesh")
				elif ball_def.shape_type == "rugby":
					assert_true(mesh_inst.mesh is ArrayMesh, "Rugby starter ball preview uses ellipsoid ArrayMesh")
				elif ball_def.shape_type == "capsule_roller":
					assert_true(mesh_inst.mesh is CapsuleMesh, "Capsule roller starter ball preview uses CapsuleMesh")
			var expected_scale := ball_def.radius / StatSheet.BASE_RADIUS
			assert_approx(float(prev.call("get_ball_scale_ratio")), expected_scale, 0.01, "Card %d 3D preview scales proportionally to ball radius" % idx)
			assert_true(bool(prev.call("is_preview_active")), "Card %d 3D preview is active while StartScreenPanel is visible" % idx)
			var roll_before: float = float(prev.call("get_roll_angle"))
			prev.call("_advance_preview_anim", 0.30)
			var roll_after: float = float(prev.call("get_roll_angle"))
			assert_true(absf(roll_after - roll_before) > 0.3, "Card %d 3D preview continuously rolls forward" % idx)

	# Selecting starter ball 1 launches RACING with that ball's physical attributes
	var picked_ball = world.current_starter_balls[1]
	world.select_starter_ball(1)
	assert_eq(world.game_state, "RACING", "Selecting a starter ball enters RACING state")
	assert_false(world.start_screen_panel.visible, "StartScreenPanel hides once RACING begins")
	for idx in range(previews.size()):
		var prev := previews[idx] as SubViewportContainer
		if prev != null and is_instance_valid(prev):
			assert_false(bool(prev.call("is_preview_active")), "Card %d 3D preview suspends rendering once RACING begins" % idx)
	assert_true(world.hud_overlay.visible, "HudOverlay becomes visible in RACING")
	assert_approx(world.player_ball.mass, picked_ball.mass, 0.01, "Selected starter ball mass applied to PlayerBall3D")
	assert_approx(world.run_state.time_remaining, 30.0, 0.2, "RACING starts with ~30.0s countdown")
	assert_true(
		world.get_node_or_null("WorkbenchBackdrop") == null,
		"Cluttered gridded WorkbenchBackdrop is removed in storybook environment"
	)
	var wenv := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_true(wenv != null and wenv.environment != null, "WorldEnvironment configured")
	if wenv != null and wenv.environment != null:
		assert_true(wenv.environment.fog_enabled, "Horizon depth fog is enabled")

	var z_start: float = world.player_ball.global_position.z
	for _i in range(28):
		await scene_tree.physics_frame

	assert_lt(
		world.player_ball.global_position.z,
		z_start - 1.5,
		"Selected starter ball rolls forward along -Z under sloped gravity"
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
	world.select_starter_ball(0)

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
		var rot_y: float = node_ent.rotation_degrees.y
		var extra: String = str(node_ent.get_meta("weight_label", ""))
		if node_ent is AerialBlocker:
			extra += "|phase=%0.4f" % (node_ent as AerialBlocker).initial_phase
		elif node_ent is WindZone:
			var wz := node_ent as WindZone
			extra += "|wind=%s:%0.2f@(%0.2f,%0.2f,%0.2f)" % [
				wz.wind_preset,
				wz.wind_force_newtons,
				wz.zone_size.x,
				wz.zone_size.y,
				wz.zone_size.z,
			]
		entity_records.append("%s@(%0.3f,%0.3f,%0.3f)rotY=%0.3f[%s]" % [scr_path, p.x, p.y, p.z, rot_y, extra])

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

	# Record unhit 500g, 800g WoodenPin, and 20kg rigidbodies far down the -11° slope (local Z < -45m so ball won't reach them in 30 frames)
	# Exclude light 500g/800g obstacles inside active WindZones (since WindZone intentionally blows light crates and pins!),
	# while keeping 20kg ShieldBrutes stationary everywhere.
	var active_wind_zones: Array[WindZone] = []
	for ent in world.track_generator.active_entities:
		if ent is WindZone and is_instance_valid(ent):
			active_wind_zones.append(ent as WindZone)
		elif ent is AerialBonusRing and is_instance_valid(ent):
			var abr := ent as AerialBonusRing
			if abr.position.y >= 4.4:
				assert_false(
					abr.with_ground_stem,
					"World upper-air AerialBonusRing (Y >= 4.4m) suppresses floor stem"
				)

	var tracked_500g: Array[Dictionary] = []
	var tracked_800g: Array[Dictionary] = []
	var tracked_20kg: Array[Dictionary] = []
	for ent in world.track_generator.active_entities:
		var node_ent := ent as Node3D
		if node_ent == null or not is_instance_valid(node_ent) or node_ent.position.z > -45.0:
			continue
		var in_wind := false
		for wz in active_wind_zones:
			if wz.contains_local_point(node_ent.position, 0.5):
				in_wind = true
				break
		var w_lbl := str(node_ent.get_meta("weight_label", ""))
		if w_lbl == "500g" and node_ent is RigidBody3D and not in_wind:
			tracked_500g.append({"node": node_ent, "start_pos": node_ent.position})
		elif w_lbl == "800g" and node_ent is WoodenPin and not in_wind:
			tracked_800g.append({"node": node_ent, "start_pos": node_ent.position})
		elif w_lbl == "20kg" and node_ent is RigidBody3D:
			tracked_20kg.append({"node": node_ent, "start_pos": node_ent.position})

	assert_gt(float(tracked_500g.size()), 0.0, "Found unhit 500g RigidBody3D obstacles on sloped track")
	assert_gt(float(tracked_800g.size()), 0.0, "Found unhit 800g WoodenPin obstacles on sloped track")
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

	var max_disp_800g := 0.0
	for item in tracked_800g:
		var rb := item["node"] as Node3D
		if rb != null and is_instance_valid(rb):
			max_disp_800g = maxf(max_disp_800g, rb.position.distance_to(item["start_pos"] as Vector3))
	assert_lt(max_disp_800g, 0.15, "Unhit 800g WoodenPins stay stationary upright on -11° slope (< 0.15m over 30 frames)")

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

	assert_true(
		world.hud_overlay.get_node_or_null("SeedModal") == null,
		"Mid-run SeedModal is removed from HudOverlay (seed lives on StartScreen)"
	)
	assert_false(
		world.hud_overlay.has_method("open_seed_dialog"),
		"HudOverlay no longer exposes mid-run open_seed_dialog"
	)
	assert_true(world.summary_panel.has_signal("restart_same_seed_requested"), "RunSummaryPanel defines signal restart_same_seed_requested")

	world.set_start_screen_seed_text("RING_AND_SUMMARY_88")
	world.select_starter_ball(0)
	await scene_tree.physics_frame

	# 1. Bonus ring signal adds +0.8s to RunState countdown
	world.run_state.time_remaining = 20.0
	world.track_generator.bonus_ring_collected.emit(0.8)
	assert_approx(world.run_state.time_remaining, 20.8, 0.01, "bonus_ring_collected adds +0.8s to RunState.time_remaining")

	# 2. Debris-triggered barrel blast boosts nearby ball without double-boosting ball-triggered blasts
	var barrel_ball = TrackEntityFactory.create_explosive_barrel(Vector3(0.0, 0.65, -20.0))
	world.track_generator._spawn_entity(barrel_ball)
	world.player_ball.global_position = world.track_generator.track_local_to_world(Vector3(0.0, 0.7, -21.0))
	world.player_ball.linear_velocity = -world.track_generator.get_track_root().global_transform.basis.z.normalized() * 10.0
	barrel_ball.on_body_contact(world.player_ball)
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
	barrel_debris.on_body_contact(fast_debris)
	assert_gt(world.player_ball.linear_velocity.length(), 20.0, "Debris-triggered barrel blast boosts nearby player_ball")

	# Distant barrel detonation (> 42m away) does not shake ChaseCamera3D
	world.chase_camera._shake_trauma = 0.0
	var far_origin: Vector3 = world.player_ball.global_position + Vector3(0.0, 0.0, -100.0)
	world._on_barrel_detonated(far_origin, 6.5, 25.0, 0)
	assert_approx(world.chase_camera._shake_trauma, 0.0, 0.0001, "Barrel detonation 100m away (> 42m) adds zero camera shake")
	var near_origin: Vector3 = world.player_ball.global_position + Vector3(0.0, 0.0, -10.5)
	world._on_barrel_detonated(near_origin, 6.5, 25.0, 0)
	assert_gt(world.chase_camera._shake_trauma, 0.25, "Nearby barrel detonation (10.5m) adds distance-attenuated camera shake")

	# 3. RunSummaryPanel returns to START_SCREEN (both same-seed and fresh random seed)
	world.simulate_race_step(35.0)
	assert_eq(world.game_state, "GAME_OVER", "Timeout enters GAME_OVER")
	world.summary_panel.emit_signal("restart_same_seed_requested")
	assert_eq(world.game_state, "START_SCREEN", "restart_same_seed_requested returns to START_SCREEN")
	assert_eq(world.run_state.seed_text, "RING_AND_SUMMARY_88", "restart_same_seed_requested preserves previous seed_text on START_SCREEN")
	assert_true(world.start_screen_panel.visible, "StartScreenPanel becomes visible for ball re-selection")

	world.select_starter_ball(0)
	world.simulate_race_step(35.0)
	assert_eq(world.game_state, "GAME_OVER", "Second timeout enters GAME_OVER")
	world.summary_panel.emit_signal("restart_requested")
	assert_eq(world.game_state, "START_SCREEN", "restart_requested returns to START_SCREEN with fresh random seed")
	assert_true(world.run_state.seed_text != "RING_AND_SUMMARY_88", "Fresh restart rolls a new random seed")

	world.queue_free()
	await scene_tree.process_frame
