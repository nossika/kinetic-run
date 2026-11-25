extends TestBase


func run() -> void:
	_test_lateral_thrust_controller_instant_start_stop_and_vertical_gravity()
	await _test_player_ball_stats_thrust_hud_and_sloped_respawn()
	_test_chase_camera_zero_roll_and_dynamic_fov()


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

	# Left thrust shows left arrow indicator
	ball.step_ball(1.0 / 60.0, -1.0, -20.0)
	if ball._hud_ring_root != null:
		assert_true(ball._left_arrow_group.visible, "Left thrust illuminates left arrow indicator")
		assert_false(ball._right_arrow_group.visible, "Left thrust keeps right arrow hidden")

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
	assert_approx(cam.FOLLOW_OFFSET.y, 5.2, 0.01, "ChaseCamera3D FOLLOW_OFFSET.y is 5.2")
	assert_approx(cam.FOLLOW_OFFSET.z, 8.2, 0.01, "ChaseCamera3D FOLLOW_OFFSET.z is 8.2")

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
