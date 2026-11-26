extends TestBase


func run() -> void:
	_test_lateral_thrust_controller_instant_start_stop_and_vertical_gravity()
	await _test_player_ball_stats_thrust_hud_and_sloped_respawn()
	_test_chase_camera_zero_roll_and_dynamic_fov()
	await _test_real_collision_mass_ratio_and_tungsten_synergy()
	await _test_sky_platform_landing_and_elevated_control()
	await _test_starter_ball_shapes_roll_smoothly_and_remove_halo()


func _test_lateral_thrust_controller_instant_start_stop_and_vertical_gravity() -> void:
	var ctrl_script: GDScript = load("res://src/gameplay/lateral_thrust_controller.gd")
	assert_true(ctrl_script != null, "LateralThrustController script must exist")
	if ctrl_script == null:
		return

	var ctrl = ctrl_script.new()
	assert_approx(ctrl.WORLD_GRAVITY.x, 0.0, 0.001, "World gravity X is strictly 0.0")
	assert_approx(ctrl.WORLD_GRAVITY.y, -22.0, 0.001, "World gravity Y is -22.0 m/s^2")
	assert_approx(ctrl.WORLD_GRAVITY.z, 0.0, 0.001, "World gravity Z is strictly 0.0")

	var accel_right: float = ctrl.compute_lateral_accel(1.0, 1.0, false)
	assert_approx(accel_right, 20.0, 0.001, "Full right ground input produces +20.0 m/s^2 lateral accel")
	assert_approx(ctrl.current_axis, 1.0, 0.001, "current_axis tracks active input")

	var accel_stop: float = ctrl.compute_lateral_accel(0.0, 1.0, false)
	assert_approx(accel_stop, 0.0, 0.001, "Releasing input immediately returns 0.0 accel with zero lag")
	assert_approx(ctrl.current_axis, 0.0, 0.001, "current_axis immediately resets to 0.0 on release")

	var accel_boosted_left: float = ctrl.compute_lateral_accel(-1.0, 1.35, false)
	assert_approx(accel_boosted_left, -27.0, 0.01, "Lateral mult scales thrust acceleration")

	var accel_air: float = ctrl.compute_lateral_accel(1.0, 1.0, true)
	assert_approx(accel_air, 13.0, 0.01, "Airborne state applies 0.65 lateral control factor")

	ctrl.reset()
	assert_approx(ctrl.current_axis, 0.0, 0.001, "reset() zeroes current_axis")

	var test_space := PhysicsServer3D.space_create()
	ctrl.apply_vertical_gravity_to_space(test_space)
	var g_dir: Vector3 = PhysicsServer3D.area_get_param(test_space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR)
	var g_mag: float = float(PhysicsServer3D.area_get_param(test_space, PhysicsServer3D.AREA_PARAM_GRAVITY))
	assert_approx(g_dir.x, 0.0, 0.001, "Space gravity vector X is 0")
	assert_approx(g_dir.y, -1.0, 0.001, "Space gravity vector Y is -1")
	assert_approx(g_dir.z, 0.0, 0.001, "Space gravity vector Z is 0")
	assert_approx(g_mag, 22.0, 0.001, "Space gravity magnitude is 22.0")
	PhysicsServer3D.free_rid(test_space)


func _test_player_ball_stats_thrust_hud_and_sloped_respawn() -> void:
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	assert_true(ball_script != null, "PlayerBall3D script must exist")
	if ball_script == null or bus_script == null or catalog_script == null:
		return

	var root_node := Node3D.new()
	scene_tree.root.add_child(root_node)

	var bus = bus_script.new()
	var catalog = catalog_script.new()
	var ball = ball_script.new()
	root_node.add_child(ball)
	ball.setup(bus)

	assert_true(ball.continuous_cd, "PlayerBall3D enables continuous_cd against tunneling")
	assert_approx(ball.mass, 1.5, 0.01, "Initial ball mass matches StatSheet 1.5 kg")
	assert_eq(str(ball.get_meta("weight_label", "")), "1.5kg", "Initial ball weight_label meta is 1.5kg")

	# Apply Tungsten Core + Giant Field + Vulcan Rubber and sync multiple times (no duplicate labels)
	bus.apply_upgrade(catalog.get_upgrade("tungsten_core"))
	bus.apply_upgrade(catalog.get_upgrade("giant_field"))
	bus.apply_upgrade(catalog.get_upgrade("vulcan_rubber"))
	ball.sync_from_stats()
	ball.sync_from_stats()

	assert_gt(ball.mass, 3.5, "Upgraded ball mass updates from StatSheet")
	assert_gt(ball.current_radius, 0.70, "Upgraded ball radius updates from StatSheet")
	assert_approx(ball.physics_material_override.bounce, 0.80, 0.01, "Upgraded bounce updates on PhysicsMaterial")
	assert_eq(str(ball.get_meta("weight_label", "")), "3.8kg", "Upgraded ball weight_label updates to 3.8kg")

	# Slime damp check
	ball.set_in_slime_zone(true)
	assert_gt(ball.linear_damp, 3.5, "Slime zone adds +3.5 linear damp without maglev")
	bus.apply_upgrade(catalog.get_upgrade("maglev_shell"))
	ball.sync_from_stats()
	assert_lt(ball.linear_damp, 0.5, "Maglev shell grants slime zone damp immunity")
	ball.set_in_slime_zone(false)

	# Speed clamp check
	ball.linear_velocity = Vector3(0.0, 0.0, -200.0)
	ball.step_ball(1.0 / 60.0, 0.0, 0.0)
	assert_approx(ball.linear_velocity.length(), 85.0, 0.1, "Ball speed clamps at 85.0 m/s max")

	# Hold-to-thrust force & non-rotating HUD ring indicator check
	ball.reset_for_track(Vector3(0.0, ball.current_radius, -5.0))
	ball.rotation_degrees = Vector3(47.0, 23.0, -68.0)
	ball.linear_velocity = Vector3(0.0, 0.0, -10.0)
	ball.step_ball(1.0 / 60.0, 1.0, 20.0)
	assert_true(ball._hud_ring_root != null, "PlayerBall3D builds non-rotating _hud_ring_root")
	if ball._hud_ring_root != null:
		assert_gt(ball._hud_ring_root.global_basis.y.dot(Vector3.UP), 0.99, "HUD ring stays upright despite ball spin")
		assert_true(ball._right_arrow_group.visible, "Right thrust illuminates right arrow indicator")
		assert_false(ball._left_arrow_group.visible, "Right thrust keeps left arrow hidden")

	await scene_tree.physics_frame
	assert_gt(ball.linear_velocity.x, 0.15, "Holding right thrust accelerates ball along +X")

	# Releasing thrust immediately hides directional arrows and applies zero new thrust
	ball.linear_velocity = Vector3(0.0, 0.0, -10.0)
	ball.step_ball(1.0 / 60.0, 0.0, 0.0)
	if ball._hud_ring_root != null:
		assert_false(ball._right_arrow_group.visible, "Releasing thrust immediately hides right arrow")
		assert_false(ball._left_arrow_group.visible, "Releasing thrust keeps left arrow hidden")
	await scene_tree.physics_frame
	assert_lt(absf(ball.linear_velocity.x), 0.02, "Zero thrust_axis applies no lateral acceleration")

	# Left thrust shows left arrow indicator; clear_thrust_indicators() + set_paused() encapsulate state cleanly
	ball.step_ball(1.0 / 60.0, -1.0, -20.0)
	if ball._hud_ring_root != null:
		assert_true(ball._left_arrow_group.visible, "Left thrust illuminates left arrow indicator")
		assert_false(ball._right_arrow_group.visible, "Left thrust keeps right arrow hidden")
	ball.clear_thrust_indicators()
	if ball._hud_ring_root != null:
		assert_false(ball._left_arrow_group.visible, "clear_thrust_indicators() hides left arrow")

	ball.linear_velocity = Vector3(1.5, 0.0, -12.0)
	ball.set_paused(true)
	assert_true(ball.freeze, "set_paused(true) freezes PlayerBall3D")
	ball.set_paused(false)
	assert_false(ball.freeze, "set_paused(false) restores unfrozen state")
	assert_approx(ball.linear_velocity.z, -12.0, 0.01, "set_paused(false) restores linear_velocity")

	# Legacy flat-world (track_reference == null) fall & respawn compatibility check
	ball.last_safe_pos = Vector3(0.0, 0.6, -20.0)
	ball.global_position = Vector3(4.0, -10.5, -25.0)
	ball.step_ball(0.1, 0.0, 0.0)
	assert_true(ball.is_respawning, "Dropping below y=-8 with null track_reference triggers respawn")
	ball.step_ball(1.3, 0.0, 0.0)
	assert_false(ball.is_respawning, "Flat respawn finishes after 1.2s")
	assert_approx(ball.global_position.z, -20.0, 0.1, "Flat respawn restores ball to last_safe_pos Z")

	# Sloped track_reference (-11 deg) local-space safe anchor, abyss fall detection, and pull-back respawn
	var sloped_track := Node3D.new()
	sloped_track.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	root_node.add_child(sloped_track)
	ball.track_reference = sloped_track
	ball.reset_for_track(sloped_track.to_global(Vector3(0.0, ball.current_radius, -2.0)))

	# At z=-55m along -11 deg slope, world Y is ~-9.8m (< -8m), yet ball is right on the track floor!
	ball.global_position = sloped_track.to_global(Vector3(0.0, ball.current_radius, -55.0))
	ball.rotation_degrees = Vector3(135.0, -42.0, 88.0)
	ball.linear_velocity = Vector3(6.0, 0.0, 0.0)
	ball.step_ball(1.0 / 60.0, 0.0, 0.0)
	assert_false(ball.is_respawning, "Ball on sloped floor at z=-55m does not falsely trigger world-Y fall")
	if ball._hud_ring_root != null:
		assert_gt(
			ball._hud_ring_root.global_basis.orthonormalized().y.dot(sloped_track.global_transform.basis.y),
			0.999,
			"HUD ring aligns with sloped track normal and ignores ball spin"
		)
	await scene_tree.physics_frame
	assert_lt(ball.linear_velocity.x, 5.85, "Gentle lateral stop damping slows lateral slip when thrust released near floor")
	assert_lt(ball.linear_velocity.z, -0.03, "Slope rolling compensation pushes ball forward along sloped -Z")

	# Dropping >8m below sloped floor in track-local Y triggers 1.2s pull-back respawn
	ball.global_position = sloped_track.to_global(Vector3(4.0, -9.5, -60.0))
	ball.step_ball(0.1, 0.0, 0.0)
	assert_true(ball.is_respawning, "Dropping below local safe_floor_y - 8.0 on sloped track triggers respawn")

	ball.step_ball(0.6, 0.0, 0.0)
	assert_true(ball.is_respawning, "Still respawning at 0.7s (< 1.2s)")
	ball.step_ball(0.7, 0.0, 0.0)
	assert_false(ball.is_respawning, "Respawn finishes after 1.2s")

	var restored_local := sloped_track.to_local(ball.global_position)
	assert_approx(restored_local.z, -55.0, 0.15, "Ball restored to last safe local Z on sloped track")
	assert_gt(restored_local.y, ball.current_radius + 1.0, "Ball restored ~1.2m above sloped track safe anchor")
	assert_lt(ball.linear_velocity.z, -5.0, "Respawned ball receives downhill -Z launch velocity")

	root_node.queue_free()
	await scene_tree.process_frame


func _test_chase_camera_zero_roll_and_dynamic_fov() -> void:
	var cam_script: GDScript = load("res://src/gameplay/chase_camera_3d.gd")
	assert_true(cam_script != null, "ChaseCamera3D script must exist")
	if cam_script == null:
		return

	var cam = cam_script.new()
	assert_approx(cam.ROLL_FACTOR, 0.0, 0.0001, "ChaseCamera3D ROLL_FACTOR is 0.0")
	assert_approx(cam.BASE_PITCH_DEG, -27.0, 0.01, "ChaseCamera3D BASE_PITCH_DEG is -27.0")
	assert_approx(cam.FOLLOW_OFFSET.y, 5.6, 0.01, "ChaseCamera3D FOLLOW_OFFSET.y is 5.6")
	assert_approx(cam.FOLLOW_OFFSET.z, 8.8, 0.01, "ChaseCamera3D FOLLOW_OFFSET.z is 8.8")

	cam.snap_to_target(Vector3.ZERO)
	for _i in range(30):
		cam.update_camera(Vector3(2.0, 0.55, -30.0), 35.0, 40.0, 1.0 / 30.0)

	assert_lt(absf(cam.rotation_degrees.z), 0.001, "ChaseCamera3D keeps zero roll under full right lateral input")
	assert_approx(cam.rotation_degrees.x, -27.0, 0.01, "ChaseCamera3D holds steady -27 deg pitch")
	assert_gt(cam.fov, 72.0, "High ball speed widens ChaseCamera3D FOV dynamically")

	for _i in range(30):
		cam.update_camera(Vector3(-2.0, 0.55, -60.0), -35.0, 45.0, 1.0 / 30.0)
	assert_lt(absf(cam.rotation_degrees.z), 0.001, "ChaseCamera3D keeps zero roll under full left lateral input")

	cam.free()


func _test_real_collision_mass_ratio_and_tungsten_synergy() -> void:
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	var ctrl_script: GDScript = load("res://src/gameplay/lateral_thrust_controller.gd")
	var mat_script: GDScript = load("res://src/core/material_library.gd")
	if ball_script == null or bus_script == null or catalog_script == null or factory_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)

	if ctrl_script != null:
		var ctrl = ctrl_script.new()
		ctrl.apply_vertical_gravity_to_space(root.get_world_3d().space)

	var floor_body := StaticBody3D.new()
	if mat_script != null:
		floor_body.physics_material_override = mat_script.high_friction_physics(0.88, 0.12)
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0, 0.6, 80.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.3, -20.0)
	floor_body.add_child(floor_col)
	root.add_child(floor_body)

	var catalog = catalog_script.new()

	# 0. Verify authoritative notify_obstacle_impact method & non-destructive notify_smash_target delegation
	var probe_bus = bus_script.new()
	var probe_ball = ball_script.new()
	root.add_child(probe_ball)
	probe_ball.setup(probe_bus)
	probe_ball.global_position = Vector3(-34.0, 0.55, -2.0)
	assert_true(
		probe_ball.has_method("notify_obstacle_impact"),
		"PlayerBall3D exposes notify_obstacle_impact(target_pos, chain_depth)"
	)
	probe_ball._saved_velocity_pre_step = Vector3(0.0, 0.0, -24.0)
	probe_ball.linear_velocity = Vector3(0.0, 0.0, -7.5)
	probe_ball.notify_smash_target(Vector3.ZERO, 0.5, 0)
	assert_approx(
		probe_ball.linear_velocity.z,
		-7.5,
		0.01,
		"notify_smash_target delegates without overwriting linear_velocity"
	)

	# 1 & 2. Real Jolt 3D head-on collisions across 500g crate, 2kg crate, 20kg weight, and 3.8kg Tungsten+Giant ball
	var bus_500g = bus_script.new()
	var ball_500g = ball_script.new()
	root.add_child(ball_500g)
	ball_500g.setup(bus_500g)
	var crate_500g = factory_script.create_crate(Vector3(-12.0, 0.48, -9.68), "light")
	root.add_child(crate_500g)

	var bus_2kg = bus_script.new()
	var ball_2kg = ball_script.new()
	root.add_child(ball_2kg)
	ball_2kg.setup(bus_2kg)
	var crate_2kg = factory_script.create_heavy_crate(Vector3(0.0, 0.60, -9.80))
	root.add_child(crate_2kg)

	var bus_20kg = bus_script.new()
	var ball_20kg = ball_script.new()
	root.add_child(ball_20kg)
	ball_20kg.setup(bus_20kg)
	var weight_20kg = factory_script.create_shield_brute(Vector3(12.0, 0.70, -9.92))
	root.add_child(weight_20kg)

	var bus_upg = bus_script.new()
	bus_upg.apply_upgrade(catalog.get_upgrade("tungsten_core"))
	bus_upg.apply_upgrade(catalog.get_upgrade("giant_field"))
	var ball_upg = ball_script.new()
	root.add_child(ball_upg)
	ball_upg.setup(bus_upg)
	var crate_2kg_upg = factory_script.create_heavy_crate(Vector3(24.0, 0.60, -9.80))
	root.add_child(crate_2kg_upg)

	await scene_tree.physics_frame

	ball_500g.global_position = Vector3(-12.0, 0.55, -8.0)
	ball_500g.linear_velocity = Vector3(0.0, 0.0, -14.0)
	ball_500g.angular_velocity = Vector3.ZERO

	ball_2kg.global_position = Vector3(0.0, 0.55, -8.0)
	ball_2kg.linear_velocity = Vector3(0.0, 0.0, -14.0)
	ball_2kg.angular_velocity = Vector3.ZERO

	ball_20kg.global_position = Vector3(12.0, 0.55, -8.0)
	ball_20kg.linear_velocity = Vector3(0.0, 0.0, -14.0)
	ball_20kg.angular_velocity = Vector3.ZERO

	ball_upg.global_position = Vector3(24.0, ball_upg.current_radius, -9.20 + ball_upg.current_radius + 0.65)
	ball_upg.linear_velocity = Vector3(0.0, 0.0, -14.0)
	ball_upg.angular_velocity = Vector3.ZERO

	var peak_rebound_back_20kg := -99.0
	for _f in range(8):
		await scene_tree.physics_frame
		peak_rebound_back_20kg = maxf(peak_rebound_back_20kg, ball_20kg.linear_velocity.z)

	var v_after_500g: float = -ball_500g.linear_velocity.z
	var v_after_2kg: float = -ball_2kg.linear_velocity.z
	var v_after_20kg: float = -ball_20kg.linear_velocity.z
	var v_after_tungsten_2kg: float = -ball_upg.linear_velocity.z

	assert_gt(
		v_after_500g,
		v_after_2kg + 2.0,
		"1.5kg ball post-impact forward speed is strictly higher against 500g crate than 2kg crate"
	)
	assert_gt(
		v_after_2kg,
		v_after_20kg + 2.0,
		"1.5kg ball post-impact forward speed is strictly higher against 2kg crate than 20kg weight"
	)
	assert_gt(
		peak_rebound_back_20kg,
		0.15,
		"1.5kg ball colliding head-on with 20kg ShieldBrute rebounds backward (+Z > 0)"
	)
	assert_lt(
		v_after_500g,
		13.0,
		"Un-upgraded 1.5kg ball uses pure Jolt Newtonian momentum transfer without artificial speed restore"
	)
	assert_gt(
		v_after_tungsten_2kg,
		v_after_2kg * 1.75,
		"3.8kg Tungsten Core + Giant Field ball retains dramatically higher forward speed against 2kg crate"
	)
	assert_lt(
		v_after_tungsten_2kg,
		14.05,
		"Tungsten Core speed-loss compensation never exceeds pre-impact speed"
	)

	# 3. Single-yield on_smash_target per persistent obstacle even when bumped twice
	var bus_smash = bus_script.new()
	bus_smash.apply_upgrade(catalog.get_upgrade("kinetic_furnace"))
	bus_smash.apply_upgrade(catalog.get_upgrade("smash_chrono"))
	bus_smash.apply_upgrade(catalog.get_upgrade("momentum_overload"))
	var ball_smash = ball_script.new()
	root.add_child(ball_smash)
	ball_smash.setup(bus_smash)
	var repeat_crate = factory_script.create_crate(Vector3(-24.0, 0.48, -9.68), "light")
	root.add_child(repeat_crate)
	await scene_tree.physics_frame

	var smash_stats := {"smashed": 0, "waves": 0, "first_wave_force": 0.0}
	ball_smash.target_smashed.connect(
		func(_p: Vector3) -> void:
			smash_stats["smashed"] = int(smash_stats["smashed"]) + 1
	)
	ball_smash.synergy_actions_requested.connect(
		func(act: Dictionary) -> void:
			var ws: Array = act.get("shockwaves", [])
			smash_stats["waves"] = int(smash_stats["waves"]) + ws.size()
			if ws.size() > 0 and float(smash_stats["first_wave_force"]) <= 0.0:
				smash_stats["first_wave_force"] = float(ws[0]["force"])
	)

	ball_smash.global_position = Vector3(-24.0, 0.55, -8.0)
	ball_smash.linear_velocity = Vector3(0.0, 0.0, -15.0)
	ball_smash.angular_velocity = Vector3.ZERO
	for _f in range(8):
		await scene_tree.physics_frame

	assert_eq(int(smash_stats["smashed"]), 1, "First collision with 500g crate emits target_smashed once")
	assert_eq(int(bus_smash.runtime_counters.get("smash_chrono_hits", 0)), 1, "First collision increments smash_chrono_hits once")
	assert_eq(int(smash_stats["waves"]), 1, "First collision triggers kinetic_furnace shockwave once")
	assert_gt(float(smash_stats["first_wave_force"]), 28.0, "kinetic_furnace uses pre-impact kinetic energy sqrt(Ek)")
	assert_eq(bus_smash.combo_stacks, 1, "Plowing through 500g crate grants 1 smash stack without false wall-bounce stack")

	assert_true(is_instance_valid(repeat_crate), "Hit 500g crate remains persistently in scene")
	if is_instance_valid(repeat_crate):
		repeat_crate.linear_velocity = Vector3.ZERO
		repeat_crate.angular_velocity = Vector3.ZERO
		var crate_pos_before_second: Vector3 = repeat_crate.global_position
		ball_smash.global_position = Vector3(crate_pos_before_second.x, 0.55, crate_pos_before_second.z + 1.55)
		ball_smash.linear_velocity = Vector3(0.0, 0.0, -15.0)
		ball_smash.angular_velocity = Vector3.ZERO
		for _f in range(8):
			await scene_tree.physics_frame

		assert_lt(
			repeat_crate.global_position.z,
			crate_pos_before_second.z - 0.5,
			"Second physical collision still pushes persistent crate along -Z"
		)
		assert_eq(int(smash_stats["smashed"]), 1, "Second collision with same persistent crate does NOT emit target_smashed again")
		assert_eq(int(bus_smash.runtime_counters.get("smash_chrono_hits", 0)), 1, "Second collision does NOT increment smash_chrono_hits again")
		assert_eq(int(smash_stats["waves"]), 1, "Second collision does NOT trigger kinetic_furnace again")

	# 4. Rebounding off 20kg ShieldBrute and 3kg BouncerSlime triggers on_wall_or_bumper_bounce
	var bus_refract_brute = bus_script.new()
	bus_refract_brute.apply_upgrade(catalog.get_upgrade("vector_refractor"))
	bus_refract_brute.apply_upgrade(catalog.get_upgrade("momentum_overload"))
	var ball_refract_brute = ball_script.new()
	root.add_child(ball_refract_brute)
	ball_refract_brute.setup(bus_refract_brute)
	var brute_rebound = factory_script.create_shield_brute(Vector3(-12.0, 0.70, -28.0))
	root.add_child(brute_rebound)

	var bus_refract_slime = bus_script.new()
	bus_refract_slime.apply_upgrade(catalog.get_upgrade("vector_refractor"))
	bus_refract_slime.apply_upgrade(catalog.get_upgrade("momentum_overload"))
	var ball_refract_slime = ball_script.new()
	root.add_child(ball_refract_slime)
	ball_refract_slime.setup(bus_refract_slime)
	var slime_rebound = factory_script.create_bouncer_slime(Vector3(12.0, 0.66, -28.0), 0.0)
	root.add_child(slime_rebound)

	await scene_tree.physics_frame

	ball_refract_brute.global_position = Vector3(-11.35, 0.55, -26.2)
	ball_refract_brute.linear_velocity = Vector3(0.0, 0.0, -15.0)
	ball_refract_brute.angular_velocity = Vector3.ZERO

	ball_refract_slime.global_position = Vector3(12.55, 0.55, -26.1)
	ball_refract_slime.linear_velocity = Vector3(0.0, 0.0, -15.0)
	ball_refract_slime.angular_velocity = Vector3.ZERO

	for _f in range(8):
		await scene_tree.physics_frame

	assert_eq(
		bus_refract_brute.combo_stacks,
		2,
		"Colliding with 20kg ShieldBrute grants smash stack + heavy rebound bounce stack"
	)
	assert_lt(
		ball_refract_brute.linear_velocity.z,
		-4.0,
		"Vector Refractor slingshots 20kg ShieldBrute rebound into strong forward -Z velocity"
	)

	assert_eq(
		bus_refract_slime.combo_stacks,
		2,
		"Bouncing off 3kg BouncerSlime grants smash stack + elastic rebound bounce stack"
	)
	assert_lt(
		ball_refract_slime.linear_velocity.z,
		-4.0,
		"Vector Refractor slingshots 3kg BouncerSlime rebound into strong forward -Z velocity"
	)

	# Second bounce off already-smashed 20kg ShieldBrute after 0.18s cooldown grants bounce stack only
	for _f in range(14):
		await scene_tree.physics_frame
	var brute_pos_now: Vector3 = brute_rebound.global_position
	ball_refract_brute.global_position = Vector3(brute_pos_now.x + 0.65, 0.55, brute_pos_now.z + 1.8)
	ball_refract_brute.linear_velocity = Vector3(0.0, 0.0, -15.0)
	ball_refract_brute.angular_velocity = Vector3.ZERO
	for _f in range(8):
		await scene_tree.physics_frame

	assert_eq(
		bus_refract_brute.combo_stacks,
		3,
		"Second rebound off persistent 20kg ShieldBrute adds 1 bounce stack (zero duplicate smash stack)"
	)

	root.queue_free()
	await scene_tree.process_frame


func _test_sky_platform_landing_and_elevated_control() -> void:
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var chunk_script: GDScript = load("res://src/track/track_chunk_base.gd")
	var ctrl_script: GDScript = load("res://src/gameplay/lateral_thrust_controller.gd")
	if ball_script == null or bus_script == null or catalog_script == null or chunk_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)

	var ctrl = null
	if ctrl_script != null:
		ctrl = ctrl_script.new()
		ctrl.apply_vertical_gravity_to_space(root.get_world_3d().space)

	var sloped_track := Node3D.new()
	sloped_track.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	root.add_child(sloped_track)

	var chunk = chunk_script.new()
	sloped_track.add_child(chunk)
	chunk.build_chunk("StraightWide", 0.0)
	chunk.add_sky_platform(Vector3(0.0, 5.0, -13.0), Vector3(4.0, 0.34, 14.0), false)

	var catalog = catalog_script.new()
	var bus = bus_script.new()
	bus.apply_upgrade(catalog.get_upgrade("quake_refractor"))
	bus.apply_upgrade(catalog.get_upgrade("momentum_overload"))

	var ball = ball_script.new()
	root.add_child(ball)
	ball.setup(bus)
	ball.track_reference = sloped_track
	ball.reset_for_track(sloped_track.to_global(Vector3(0.0, ball.current_radius + 0.1, -2.0)))
	await scene_tree.physics_frame

	assert_true(
		ball.has_method("has_ground_or_sky_support"),
		"PlayerBall3D exposes has_ground_or_sky_support()"
	)

	var land_waves := {"count": 0}
	ball.synergy_actions_requested.connect(
		func(actions: Dictionary) -> void:
			var ws: Array = actions.get("shockwaves", [])
			land_waves["count"] = int(land_waves["count"]) + ws.size()
	)

	# Drop ball from high air (Y = 8.4m) onto the Y = 5.0m SkyPlatform
	ball.global_position = sloped_track.to_global(Vector3(0.0, 8.4, -10.0))
	ball.linear_velocity = (-sloped_track.global_transform.basis.z.normalized()) * 6.0

	var landed_on_sky := false
	var sky_control_accel := 0.0
	for _f in range(40):
		ball.step_ball(1.0 / 60.0, 0.0, 0.0)
		await scene_tree.physics_frame
		var lpos: Vector3 = sloped_track.to_local(ball.global_position)
		if lpos.y > 4.8 and not ball.is_airborne():
			landed_on_sky = true
			if ctrl != null:
				sky_control_accel = ctrl.compute_lateral_accel(1.0, 1.0, ball.is_airborne())

	assert_true(landed_on_sky, "PlayerBall3D recognizes surface support (is_airborne() == false) while rolling on Y=5.0m SkyPlatform")
	assert_gt(float(land_waves["count"]), 0.0, "Landing on elevated SkyPlatform triggers on_land (Quake Refractor shockwave)")
	assert_gt(float(bus.combo_stacks), 0.0, "Landing on elevated SkyPlatform grants Momentum Overload stack")
	if ctrl != null:
		assert_approx(sky_control_accel, 20.0, 0.01, "Ball rolling on SkyPlatform receives full ground lateral thrust control (20.0 m/s^2)")

	# Rolling off the -Z end of SkyPlatform (z < -20.0) transitions back to airborne after SURFACE_SUPPORT_GRACE
	ball.global_position = sloped_track.to_global(Vector3(0.0, 5.0 + 0.17 + ball.current_radius, -19.2))
	ball.linear_velocity = (-sloped_track.global_transform.basis.z.normalized()) * 12.0
	ball.angular_velocity = Vector3.ZERO
	var supported_before_drop := false
	for _f in range(2):
		ball.step_ball(1.0 / 60.0, 0.0, 0.0)
		await scene_tree.physics_frame
		if not ball.is_airborne():
			supported_before_drop = true
	assert_true(supported_before_drop, "Ball maintains surface support near SkyPlatform exit edge before leaving deck")
	for _f in range(10):
		ball.step_ball(1.0 / 60.0, 0.0, 0.0)
		await scene_tree.physics_frame
	var off_deck_lpos: Vector3 = sloped_track.to_local(ball.global_position)
	assert_gt(off_deck_lpos.y, 2.5, "Ball is still well above main floor shortly after leaving SkyPlatform")
	assert_true(ball.is_airborne(), "Rolling off SkyPlatform transitions back to is_airborne() == true after SURFACE_SUPPORT_GRACE")

	# Widened safe respawn X window (|x| <= 3.0) on main deck
	ball.global_position = sloped_track.to_global(Vector3(2.8, ball.current_radius + 0.1, -22.0))
	ball.step_ball(1.0 / 60.0, 0.0, 0.0)
	assert_approx(ball.last_safe_pos.z, -22.0, 0.05, "Widened safe respawn X window (|x| <= 3.0) updates last_safe_pos at x=2.8m")
	ball.global_position = sloped_track.to_global(Vector3(3.2, ball.current_radius + 0.1, -24.0))
	ball.step_ball(1.0 / 60.0, 0.0, 0.0)
	assert_approx(ball.last_safe_pos.z, -22.0, 0.05, "Position outside safe respawn X window (|x| = 3.2 > 3.0) does not overwrite last_safe_pos")

	# High-bounce (vulcan_rubber, bounce = 0.80) drop onto SkyPlatform still fires on_land shockwave & stack
	var bouncy_bus = bus_script.new()
	bouncy_bus.apply_upgrade(catalog.get_upgrade("vulcan_rubber"))
	bouncy_bus.apply_upgrade(catalog.get_upgrade("quake_refractor"))
	bouncy_bus.apply_upgrade(catalog.get_upgrade("momentum_overload"))
	var bouncy_ball = ball_script.new()
	root.add_child(bouncy_ball)
	bouncy_ball.setup(bouncy_bus)
	bouncy_ball.track_reference = sloped_track
	bouncy_ball.reset_for_track(sloped_track.to_global(Vector3(0.0, bouncy_ball.current_radius + 0.1, -2.0)))
	await scene_tree.physics_frame

	var bouncy_land_waves := {"count": 0}
	bouncy_ball.synergy_actions_requested.connect(
		func(actions: Dictionary) -> void:
			var ws: Array = actions.get("shockwaves", [])
			bouncy_land_waves["count"] = int(bouncy_land_waves["count"]) + ws.size()
	)

	bouncy_ball.global_position = sloped_track.to_global(Vector3(0.0, 9.2, -9.5))
	bouncy_ball.linear_velocity = (-sloped_track.global_transform.basis.z.normalized()) * 5.0
	bouncy_ball.angular_velocity = Vector3.ZERO
	bouncy_ball._saved_velocity_pre_step = bouncy_ball.linear_velocity

	var peak_rebound_up := 0.0
	for _f in range(42):
		bouncy_ball.step_ball(1.0 / 60.0, 0.0, 0.0)
		await scene_tree.physics_frame
		peak_rebound_up = maxf(
			peak_rebound_up,
			bouncy_ball.linear_velocity.dot(sloped_track.global_transform.basis.y.normalized())
		)

	assert_gt(peak_rebound_up, 3.5, "Vulcan Rubber (bounce=0.80) drop onto SkyPlatform rebounds upward at > 3.5 m/s")
	assert_gt(float(bouncy_land_waves["count"]), 0.0, "High-bounce Vulcan Rubber drop onto SkyPlatform still triggers on_land shockwave")
	assert_gt(float(bouncy_bus.combo_stacks), 0.0, "High-bounce Vulcan Rubber drop onto SkyPlatform grants Momentum Overload stack")

	root.queue_free()
	await scene_tree.process_frame


func _test_starter_ball_shapes_roll_smoothly_and_remove_halo() -> void:
	var cat_script: GDScript = load("res://src/core/starter_ball_catalog.gd")
	assert_true(cat_script != null, "StarterBallCatalog script must exist for physics test")
	if cat_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var thrust_ctrl := LateralThrustController.new()
	thrust_ctrl.apply_vertical_gravity_to_space(root.get_world_3d().space)

	var sloped_track := Node3D.new()
	sloped_track.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	root.add_child(sloped_track)

	var floor_body := StaticBody3D.new()
	floor_body.physics_material_override = MaterialLibrary.high_friction_physics(0.88, 0.12)
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(14.0, 0.6, 80.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.3, -35.0)
	floor_body.add_child(floor_col)
	sloped_track.add_child(floor_body)

	var rolled_balls: Array = cat_script.roll_starter_balls(20261126, 3)
	for def in rolled_balls:
		var bus := PhysicsSynergyBus.new()
		var ball := PlayerBall3D.new()
		root.add_child(ball)
		ball.setup(bus)
		ball.track_reference = sloped_track
		ball.apply_starter_ball(def)

		assert_true(
			ball._hud_ring_root.get_node_or_null("EquatorialHalo") == null,
			"Redundant EquatorialHalo ring is removed from PlayerBall3D"
		)
		assert_approx(ball.mass, def.mass, 0.01, "Ball mass matches StarterBallDefinition (%s)" % def.shape_type)
		assert_approx(ball.current_radius, def.radius, 0.01, "Ball radius matches StarterBallDefinition (%s)" % def.shape_type)
		assert_approx(ball.physics_material_override.friction, def.friction, 0.01, "Ball friction matches StarterBallDefinition")
		assert_approx(ball.physics_material_override.bounce, def.bounce, 0.01, "Ball bounce matches StarterBallDefinition")

		var start_world := sloped_track.to_global(Vector3(0.0, ball.current_radius + 0.12, -2.0))
		ball.reset_for_track(start_world)
		await scene_tree.physics_frame

		for _f in range(48):
			ball.step_ball(1.0 / 60.0, 0.0, 0.0)
			await scene_tree.physics_frame

		var end_local := sloped_track.to_local(ball.global_position)
		assert_lt(
			end_local.z,
			-5.0,
			"Starter ball shape '%s' rolls smoothly downhill along -Z without stalling" % def.shape_type
		)
		assert_gt(
			ball.angular_velocity.length(),
			1.5,
			"Starter ball shape '%s' builds clear rolling angular velocity" % def.shape_type
		)

		ball.queue_free()
		await scene_tree.process_frame

	root.queue_free()
	await scene_tree.process_frame

