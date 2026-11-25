extends TestBase


func run() -> void:
	_test_gravity_tilt_controller_math_and_clamping()
	await _test_player_ball_stats_respawn_and_speed_cap()
	_test_chase_camera_roll_and_dynamic_fov()


func _test_gravity_tilt_controller_math_and_clamping() -> void:
	var ctrl_script: GDScript = load("res://src/gameplay/gravity_tilt_controller.gd")
	assert_true(ctrl_script != null, "GravityTiltController script must exist")
	if ctrl_script == null:
		return

	var ctrl = ctrl_script.new()
	var g0: Vector3 = ctrl.compute_gravity_vector(0.0, 1.0)
	assert_approx(g0.length(), 22.0, 0.01, "Gravity magnitude at 0 tilt is 22.0 m/s^2")
	assert_approx(g0.x, 0.0, 0.001, "Zero lateral gravity at 0 tilt")
	assert_lt(g0.y, -20.0, "Strong downward -Y gravity")
	assert_lt(g0.z, -4.0, "Forward -Z slope gravity component drives ball toward finish")

	# Hold right (+1.0) for several seconds -> clamps at +35 deg
	var g_right := Vector3.ZERO
	for _i in range(60):
		g_right = ctrl.update_tilt(1.0, 35.0, 1.0 / 60.0)
	assert_approx(ctrl.current_tilt_deg, 35.0, 0.05, "Right tilt clamps at +35.0 deg")
	assert_gt(g_right.x, 11.0, "Right tilt creates +X lateral gravity")
	assert_approx(g_right.length(), 22.0, 0.01, "Gravity vector norm remains constant under tilt")

	# Release input -> smoothly returns to 0 deg
	for _i in range(90):
		ctrl.update_tilt(0.0, 35.0, 1.0 / 60.0)
	assert_approx(ctrl.current_tilt_deg, 0.0, 0.05, "Releasing input returns tilt to 0 deg")


func _test_player_ball_stats_respawn_and_speed_cap() -> void:
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

	# Apply Tungsten Core + Giant Field + Vulcan Rubber and sync
	bus.apply_upgrade(catalog.get_upgrade("tungsten_core"))
	bus.apply_upgrade(catalog.get_upgrade("giant_field"))
	bus.apply_upgrade(catalog.get_upgrade("vulcan_rubber"))
	ball.sync_from_stats()

	assert_gt(ball.mass, 3.5, "Upgraded ball mass updates from StatSheet")
	assert_gt(ball.current_radius, 0.70, "Upgraded ball radius updates from StatSheet")
	assert_approx(ball.physics_material_override.bounce, 0.80, 0.01, "Upgraded bounce updates on PhysicsMaterial")

	# Slime damp check
	ball.set_in_slime_zone(true)
	assert_gt(ball.linear_damp, 3.5, "Slime zone adds +3.5 linear damp without maglev")
	bus.apply_upgrade(catalog.get_upgrade("maglev_shell"))
	ball.sync_from_stats()
	assert_lt(ball.linear_damp, 0.5, "Maglev shell grants slime zone damp immunity")
	ball.set_in_slime_zone(false)

	# Speed clamp check
	ball.linear_velocity = Vector3(0.0, 0.0, -200.0)
	ball.step_ball(1.0 / 60.0, 0.0)
	assert_approx(ball.linear_velocity.length(), 85.0, 0.1, "Ball speed clamps at 85.0 m/s max")

	# Fall detection and 1.2s pull-back respawn
	ball.last_safe_pos = Vector3(0.0, 0.6, -20.0)
	ball.global_position = Vector3(4.0, -10.5, -25.0)
	ball.step_ball(0.1, 0.0)
	assert_true(ball.is_respawning, "Dropping below y=-8 triggers pull-back respawn state")

	ball.step_ball(0.6, 0.0)
	assert_true(ball.is_respawning, "Still respawning at 0.7s (< 1.2s)")
	ball.step_ball(0.7, 0.0)
	assert_false(ball.is_respawning, "Respawn finishes after 1.2s")
	assert_approx(ball.global_position.z, -20.0, 0.1, "Ball restored to last_safe_pos Z")
	assert_lt(ball.linear_velocity.z, -5.0, "Respawned ball receives forward -Z launch velocity")

	root_node.queue_free()
	await scene_tree.process_frame


func _test_chase_camera_roll_and_dynamic_fov() -> void:
	var cam_script: GDScript = load("res://src/gameplay/chase_camera_3d.gd")
	assert_true(cam_script != null, "ChaseCamera3D script must exist")
	if cam_script == null:
		return

	var cam = cam_script.new()
	cam.snap_to_target(Vector3.ZERO)
	for _i in range(30):
		cam.update_camera(Vector3(0.0, 0.55, -30.0), 30.0, 40.0, 1.0 / 30.0)

	assert_lt(cam.rotation_degrees.z, -10.0, "Positive right tilt rolls camera counter-clockwise for horizon feel")
	assert_gt(cam.fov, 72.0, "High ball speed widens ChaseCamera3D FOV dynamically")
	cam.free()
