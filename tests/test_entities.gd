extends TestBase


func run() -> void:
	await _test_crate_and_slime_momentum_thresholds()
	await _test_shield_brute_and_slime_zone()
	await _test_boost_pad_bumper_and_barrel_chain()


func _create_ball_in(parent: Node3D) -> Variant:
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus = bus_script.new()
	var ball = ball_script.new()
	parent.add_child(ball)
	ball.setup(bus)
	return ball


func _test_crate_and_slime_momentum_thresholds() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	assert_true(factory_script != null, "TrackEntityFactory script must exist")
	if factory_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var ball = _create_ball_in(root)

	# 1. CrateObstacle: threshold P >= 14.0 (with mass=1.5, v=5 -> P=7.5 fails; v=12 -> P=18.0 smashes)
	var crate = factory_script.create_crate(Vector3(0.0, 0.5, -10.0))
	root.add_child(crate)
	ball.linear_velocity = Vector3(0.0, 0.0, -5.0)
	ball.step_ball(0.016, 0.0)
	crate.interact_with_ball(ball)
	assert_false(crate.is_smashed, "Low momentum (P=7.5 < 14.0) does not smash CrateObstacle")

	ball.linear_velocity = Vector3(0.0, 0.0, -12.0)
	ball.step_ball(0.016, 0.0)
	crate.interact_with_ball(ball)
	assert_true(crate.is_smashed, "High momentum (P=18.0 >= 14.0) smashes CrateObstacle")
	assert_lt(ball.linear_velocity.z, -10.5, "Smashing crate retains ~92% forward speed")

	# 2. BouncerSlime: threshold P >= 22.0 (v=6 -> P=9.0 bounces ball back +Z; v=18 -> P=27.0 smashes)
	var slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.5, -15.0), 3.0)
	root.add_child(slime)
	ball.linear_velocity = Vector3(0.0, 0.0, -6.0)
	ball.step_ball(0.016, 0.0)
	slime.interact_with_ball(ball)
	assert_false(slime.is_smashed, "Low momentum (P=9.0 < 22.0) fails to smash BouncerSlime")
	assert_gt(ball.linear_velocity.z, 2.0, "BouncerSlime knocks low-momentum ball backward (+Z)")

	ball.linear_velocity = Vector3(0.0, 0.0, -18.0)
	ball.step_ball(0.016, 0.0)
	slime.interact_with_ball(ball)
	assert_true(slime.is_smashed, "High momentum (P=27.0 >= 22.0) smashes BouncerSlime")

	root.queue_free()
	await scene_tree.process_frame


func _test_shield_brute_and_slime_zone() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	if factory_script == null or catalog_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var ball = _create_ball_in(root)
	var catalog = catalog_script.new()

	# ShieldBrute: threshold P >= 42.0
	var brute = factory_script.create_shield_brute(Vector3(0.0, 0.7, -20.0))
	root.add_child(brute)
	ball.linear_velocity = Vector3(0.0, 0.0, -16.0) # P = 24.0 < 42.0
	ball.step_ball(0.016, 0.0)
	brute.interact_with_ball(ball)
	assert_false(brute.is_smashed, "Medium momentum (P=24 < 42) blocked by ShieldBrute")
	assert_gt(ball.linear_velocity.z, -6.5, "ShieldBrute cuts ball speed by ~65%")

	# Shockwave immediately breaks ShieldBrute!
	brute.apply_shockwave(Vector3(0.0, 0.7, -18.0), 6.5, 25.0, 1, ball)
	assert_true(brute.is_smashed, "Explosion/shockwave directly breaks ShieldBrute")

	# SlimeZone damp + Maglev immunity
	var zone = factory_script.create_slime_zone(Vector3(0.0, 0.05, -25.0), Vector2(4.0, 6.0))
	root.add_child(zone)
	zone.on_ball_entered(ball)
	assert_gt(ball.linear_damp, 3.5, "SlimeZone raises ball linear_damp")
	ball.synergy_bus.apply_upgrade(catalog.get_upgrade("maglev_shell"))
	ball.sync_from_stats()
	assert_lt(ball.linear_damp, 0.4, "Maglev shell ignores SlimeZone damp")
	zone.on_ball_exited(ball)

	root.queue_free()
	await scene_tree.process_frame


func _test_boost_pad_bumper_and_barrel_chain() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	if factory_script == null or catalog_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var ball = _create_ball_in(root)
	var catalog = catalog_script.new()
	ball.synergy_bus.apply_upgrade(catalog.get_upgrade("tailwind_sail")) # external_boost_mult * 1.75
	ball.sync_from_stats()

	# BoostPad
	var pad = factory_script.create_boost_pad(Vector3(0.0, 0.05, -10.0))
	root.add_child(pad)
	ball.linear_velocity = Vector3(0.0, 0.0, -8.0)
	ball.step_ball(0.016, 0.0)
	pad.interact_with_ball(ball)
	assert_lt(ball.linear_velocity.z, -35.0, "BoostPad + Tailwind Sail strongly accelerates ball along -Z")

	# PinballBumper
	var bumper = factory_script.create_pinball_bumper(Vector3(1.0, 0.6, -20.0))
	root.add_child(bumper)
	ball.global_position = Vector3(0.0, 0.6, -19.5)
	ball.linear_velocity = Vector3(2.0, 0.0, -10.0)
	ball.step_ball(0.016, 0.0)
	bumper.interact_with_ball(ball)
	assert_lt(ball.linear_velocity.z, -30.0, "PinballBumper launches ball forward along -Z")

	# ExplosiveBarrel chain-smashes nearby CrateObstacle & ShieldBrute and propels ball forward
	var barrel = factory_script.create_explosive_barrel(Vector3(0.0, 0.6, -30.0))
	var near_crate = factory_script.create_crate(Vector3(1.5, 0.5, -32.0))
	var near_brute = factory_script.create_shield_brute(Vector3(-1.5, 0.7, -33.0))
	root.add_child(barrel)
	root.add_child(near_crate)
	root.add_child(near_brute)

	var entities: Array[Node3D] = [barrel, near_crate, near_brute]
	ball.global_position = Vector3(0.0, 0.6, -30.8) # slightly in front (-Z) of barrel
	ball.linear_velocity = Vector3(0.0, 0.0, -10.0)
	ball.step_ball(0.016, 0.0)
	barrel.detonate(ball, entities, 0)

	assert_true(barrel.is_detonated, "Barrel marks itself detonated")
	assert_true(near_crate.is_smashed, "Barrel blast chain-smashes nearby CrateObstacle")
	assert_true(near_brute.is_smashed, "Barrel blast chain-smashes nearby ShieldBrute")
	assert_lt(ball.linear_velocity.z, -25.0, "Barrel blast propels ball forward along -Z")

	root.queue_free()
	await scene_tree.process_frame
