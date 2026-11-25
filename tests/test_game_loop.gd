extends TestBase


func run() -> void:
	await _test_main_scene_boots_and_rolls_forward()
	await _test_finish_draft_next_level_and_timeout_restart()
	await _test_emergent_build_outpaces_baseline_in_3d_simulation()


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
