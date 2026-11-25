extends TestBase


func run() -> void:
	await _test_crate_tiers_and_slime_momentum_thresholds()
	await _test_shield_brute_rigidbody_and_slime_zone()
	await _test_boost_pad_anchored_bumper_and_barrel_rigidbody_chain()
	await _test_spring_pad_bonus_ring_and_aerial_blockers()
	await _test_sloped_floor_stability_and_flying_debris_barrel_hit()


func _script_has_method(scr: GDScript, method_name: String) -> bool:
	if scr == null:
		return false
	for m in scr.get_script_method_list():
		if str(m.get("name", "")) == method_name:
			return true
	return false


func _script_method_arg_count(scr: GDScript, method_name: String) -> int:
	if scr == null:
		return 0
	for m in scr.get_script_method_list():
		if str(m.get("name", "")) == method_name:
			var args: Array = m.get("args", [])
			return args.size()
	return 0


func _create_ball_in(parent: Node3D) -> Variant:
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus = bus_script.new()
	var ball = ball_script.new()
	parent.add_child(ball)
	ball.setup(bus)
	return ball


func _test_crate_tiers_and_slime_momentum_thresholds() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	assert_true(factory_script != null, "TrackEntityFactory script must exist")
	if factory_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var ball = _create_ball_in(root)

	# 1a. Light CrateObstacle ("500g", mass=0.5, smash_momentum=10.0)
	var light_crate = factory_script.create_crate(Vector3(0.0, 0.5, -10.0))
	root.add_child(light_crate)
	assert_true(light_crate is RigidBody3D, "Light CrateObstacle is a RigidBody3D")
	assert_approx(light_crate.mass, 0.5, 0.01, "Light crate mass is 0.5kg (500g)")
	assert_eq(str(light_crate.get_meta("weight_label", "")), "500g", "Light crate exposes 500g weight_label")

	ball.linear_velocity = Vector3(0.0, 0.0, -5.0) # P = 1.5 * 5 = 7.5 < 10.0
	ball.step_ball(0.016, 0.0)
	light_crate.interact_with_ball(ball)
	assert_false(light_crate.is_smashed, "Low momentum (P=7.5 < 10.0) does not smash 500g light crate")

	ball.linear_velocity = Vector3(0.0, 0.0, -8.0) # P = 1.5 * 8 = 12.0 >= 10.0
	ball.step_ball(0.016, 0.0)
	light_crate.interact_with_ball(ball)
	assert_true(light_crate.is_smashed, "Momentum P=12.0 >= 10.0 smashes 500g light crate")
	assert_lt(ball.linear_velocity.z, -7.4, "Smashing 500g light crate retains ~95% forward speed")
	assert_approx(light_crate.linear_damp, 0.1, 0.02, "Shattered light crate switches linear_damp to 0.1")

	# 1b. Medium/Heavy CrateObstacle ("2.5kg", mass=2.5, smash_momentum=18.0)
	var has_heavy := _script_has_method(factory_script, "create_heavy_crate")
	assert_true(has_heavy, "TrackEntityFactory exposes create_heavy_crate(pos)")
	assert_eq(
		_script_method_arg_count(factory_script, "create_crate"),
		2,
		"TrackEntityFactory.create_crate accepts (pos, tier = 'light')"
	)
	if has_heavy:
		var med_crate = factory_script.create_heavy_crate(Vector3(0.0, 0.65, -12.0))
		root.add_child(med_crate)
		assert_true(med_crate is RigidBody3D, "Medium CrateObstacle is a RigidBody3D")
		assert_eq(med_crate.weight_tier, "medium", "create_heavy_crate sets weight_tier to 'medium'")
		assert_approx(med_crate.mass, 2.5, 0.01, "Medium crate mass is 2.5kg")
		assert_eq(str(med_crate.get_meta("weight_label", "")), "2.5kg", "Medium crate exposes 2.5kg weight_label")
		assert_approx(med_crate.smash_momentum, 18.0, 0.01, "Medium crate smash_momentum is 18.0")

		ball.linear_velocity = Vector3(0.0, 0.0, -9.0) # P = 13.5 < 18.0 (smashes light, NOT medium!)
		ball.step_ball(0.016, 0.0)
		med_crate.interact_with_ball(ball)
		assert_false(med_crate.is_smashed, "Momentum P=13.5 (< 18.0) fails to smash 2.5kg medium crate")

		ball.linear_velocity = Vector3(0.0, 0.0, -14.0) # P = 21.0 >= 18.0
		ball.step_ball(0.016, 0.0)
		med_crate.interact_with_ball(ball)
		assert_true(med_crate.is_smashed, "Momentum P=21.0 >= 18.0 smashes 2.5kg medium crate")
		assert_lt(ball.linear_velocity.z, -12.5, "Smashing 2.5kg medium crate retains ~91% forward speed")

	if _script_method_arg_count(factory_script, "create_crate") >= 2:
		var med_via_tier = factory_script.create_crate(Vector3(1.5, 0.65, -12.0), "medium")
		root.add_child(med_via_tier)
		assert_approx(med_via_tier.mass, 2.5, 0.01, "create_crate(pos, 'medium') configures 2.5kg mass")
		assert_eq(str(med_via_tier.get_meta("weight_label", "")), "2.5kg", "create_crate(pos, 'medium') sets 2.5kg label")

	# 2. BouncerSlime ("3kg", threshold P >= 22.0)
	var slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.5, -15.0), 3.0)
	root.add_child(slime)
	assert_eq(str(slime.get_meta("weight_label", "")), "3kg", "BouncerSlime exposes 3kg weight_label")

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


func _test_shield_brute_rigidbody_and_slime_zone() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	if factory_script == null or catalog_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var ball = _create_ball_in(root)
	var catalog = catalog_script.new()

	# ShieldBrute: 20kg cast-iron RigidBody3D, threshold P >= 42.0
	var brute = factory_script.create_shield_brute(Vector3(0.0, 0.7, -20.0))
	root.add_child(brute)
	assert_true(brute is RigidBody3D, "ShieldBrute extends RigidBody3D")
	if brute is RigidBody3D:
		assert_approx(brute.mass, 20.0, 0.01, "ShieldBrute mass is 20.0kg")
	assert_eq(str(brute.get_meta("weight_label", "")), "20kg", "ShieldBrute exposes 20kg weight_label")

	ball.linear_velocity = Vector3(0.0, 0.0, -16.0) # P = 24.0 < 42.0
	ball.step_ball(0.016, 0.0)
	brute.interact_with_ball(ball)
	assert_false(brute.is_smashed, "Medium momentum (P=24 < 42) blocked by ShieldBrute")
	assert_gt(ball.linear_velocity.z, -6.5, "ShieldBrute cuts ball speed by ~65%")

	# High momentum direct smash on 20kg ShieldBrute
	var brute_direct = factory_script.create_shield_brute(Vector3(2.0, 0.7, -20.0))
	root.add_child(brute_direct)
	ball.linear_velocity = Vector3(0.0, 0.0, -32.0) # P = 48.0 >= 42.0
	ball.step_ball(0.016, 0.0)
	brute_direct.interact_with_ball(ball)
	assert_true(brute_direct.is_smashed, "High momentum (P=48 >= 42) smashes 20kg ShieldBrute")
	if brute_direct is RigidBody3D:
		assert_approx(brute_direct.linear_damp, 0.1, 0.02, "Smashed ShieldBrute switches linear_damp to 0.1")

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


func _test_boost_pad_anchored_bumper_and_barrel_rigidbody_chain() -> void:
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

	# PinballBumper (anchored fixed flange base)
	var bumper = factory_script.create_pinball_bumper(Vector3(1.0, 0.6, -20.0))
	root.add_child(bumper)
	assert_eq(
		bool(bumper.get_meta("is_anchored_fixed", false)),
		true,
		"PinballBumper exposes is_anchored_fixed == true"
	)
	ball.global_position = Vector3(0.0, 0.6, -19.5)
	ball.linear_velocity = Vector3(2.0, 0.0, -10.0)
	ball.step_ball(0.016, 0.0)
	bumper.interact_with_ball(ball)
	assert_lt(ball.linear_velocity.z, -30.0, "PinballBumper launches ball forward along -Z")

	# ExplosiveBarrel: 1.5kg RigidBody3D + fast RigidBody3D impact detonation + chain-smash
	var barrel = factory_script.create_explosive_barrel(Vector3(0.0, 0.6, -30.0))
	var near_crate = factory_script.create_crate(Vector3(1.5, 0.5, -32.0))
	var near_brute = factory_script.create_shield_brute(Vector3(-1.5, 0.7, -33.0))
	root.add_child(barrel)
	root.add_child(near_crate)
	root.add_child(near_brute)

	assert_true(barrel is RigidBody3D, "ExplosiveBarrel extends RigidBody3D")
	if barrel is RigidBody3D:
		assert_approx(barrel.mass, 1.5, 0.01, "ExplosiveBarrel mass is 1.5kg")
	assert_eq(str(barrel.get_meta("weight_label", "")), "1.5kg", "ExplosiveBarrel exposes 1.5kg weight_label")

	var entities: Array[Node3D] = [barrel, near_crate, near_brute]
	ball.global_position = Vector3(0.0, 0.6, -30.8) # slightly in front (-Z) of barrel
	ball.linear_velocity = Vector3(0.0, 0.0, -10.0)
	ball.step_ball(0.016, 0.0)
	barrel.detonate(ball, entities, 0)

	assert_true(barrel.is_detonated, "Barrel marks itself detonated")
	assert_true(near_crate.is_smashed, "Barrel blast chain-smashes nearby CrateObstacle")
	assert_true(near_brute.is_smashed, "Barrel blast chain-smashes nearby ShieldBrute")
	assert_lt(ball.linear_velocity.z, -25.0, "Barrel blast propels ball forward along -Z")

	# Secondary barrel: ignores static floor / slow RigidBody3D, detonates on fast flying RigidBody3D (> 2.8 m/s)
	var barrel_impact = factory_script.create_explosive_barrel(Vector3(3.0, 0.65, -35.0))
	var flying_crate = factory_script.create_crate(Vector3(3.0, 0.65, -33.0))
	root.add_child(barrel_impact)
	root.add_child(flying_crate)

	barrel_impact._on_sensor_body_entered(barrel_impact)
	assert_false(barrel_impact.is_detonated, "ExplosiveBarrel never self-detonates from own RigidBody3D")

	flying_crate.linear_velocity = Vector3(0.0, 0.0, -1.2) # <= 2.8 m/s
	barrel_impact._on_sensor_body_entered(flying_crate)
	assert_false(barrel_impact.is_detonated, "Slow RigidBody3D (<= 2.8 m/s) does not detonate ExplosiveBarrel")

	flying_crate.linear_velocity = Vector3(0.0, 5.0, -14.0) # > 2.8 m/s
	barrel_impact._on_sensor_body_entered(flying_crate)
	assert_true(barrel_impact.is_detonated, "Fast flying RigidBody3D (> 2.8 m/s) detonates ExplosiveBarrel")

	root.queue_free()
	await scene_tree.process_frame


func _test_spring_pad_bonus_ring_and_aerial_blockers() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	if factory_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var ball = _create_ball_in(root)

	# 1. SpringPad: anchored fixed flange + vertical launch (y > 10.0) + forward boost
	var has_spring := _script_has_method(factory_script, "create_spring_pad")
	assert_true(has_spring, "TrackEntityFactory exposes create_spring_pad(pos)")
	if has_spring:
		var spring = factory_script.create_spring_pad(Vector3(0.0, 0.0, -10.0))
		root.add_child(spring)
		assert_eq(
			bool(spring.get_meta("is_anchored_fixed", false)),
			true,
			"SpringPad exposes is_anchored_fixed == true"
		)
		ball.linear_velocity = Vector3(0.0, -2.0, -8.0)
		ball.step_ball(0.016, 0.0)
		spring.interact_with_ball(ball)
		assert_gt(ball.linear_velocity.y, 10.0, "SpringPad launches ball upward with vy > 10.0 m/s")
		assert_lt(ball.linear_velocity.z, -13.0, "SpringPad adds forward -Z boost")

	# 2. AerialBonusRing: emits ring_collected(0.8) once and boosts forward -Z speed
	var has_ring := _script_has_method(factory_script, "create_aerial_bonus_ring")
	assert_true(has_ring, "TrackEntityFactory exposes create_aerial_bonus_ring(pos)")
	if has_ring:
		var ring = factory_script.create_aerial_bonus_ring(Vector3(0.0, 4.5, -18.0))
		root.add_child(ring)
		var collected_state := {"count": 0, "seconds": 0.0}
		ring.ring_collected.connect(
			func(sec: float) -> void:
				collected_state["count"] = int(collected_state["count"]) + 1
				collected_state["seconds"] = sec
		)
		ball.linear_velocity = Vector3(0.0, 2.0, -10.0)
		ball.step_ball(0.016, 0.0)
		ring.interact_with_ball(ball)
		ring.interact_with_ball(ball)
		assert_true(ring.is_collected, "AerialBonusRing marks is_collected == true")
		assert_eq(int(collected_state["count"]), 1, "AerialBonusRing emits ring_collected exactly once")
		assert_approx(float(collected_state["seconds"]), 0.8, 0.001, "AerialBonusRing grants +0.8s bonus time")
		assert_lt(ball.linear_velocity.z, -22.0, "AerialBonusRing strongly boosts forward -Z speed")

	# 3. AerialBlocker: "soft_balloon" (2kg, P>=18) vs "mag_iron" (12kg, P>=36) + deterministic phase
	var has_blocker := _script_has_method(factory_script, "create_aerial_blocker")
	assert_true(has_blocker, "TrackEntityFactory exposes create_aerial_blocker(pos, blocker_type, initial_phase)")
	if has_blocker:
		var balloon = factory_script.create_aerial_blocker(Vector3(0.0, 4.0, -22.0), "soft_balloon", 0.6)
		var balloon_twin = factory_script.create_aerial_blocker(Vector3(0.0, 4.0, -22.0), "soft_balloon", 0.6)
		root.add_child(balloon)
		root.add_child(balloon_twin)
		assert_eq(str(balloon.get_meta("weight_label", "")), "2kg", "soft_balloon AerialBlocker exposes 2kg label")

		balloon._physics_process(0.25)
		balloon_twin._physics_process(0.25)
		assert_approx(
			balloon.position.distance_to(balloon_twin.position),
			0.0,
			0.0001,
			"AerialBlocker bobbing/swaying is 100% deterministic for identical initial_phase"
		)

		ball.global_position = Vector3(0.2, 4.0, -21.5)
		ball.linear_velocity = Vector3(0.0, 1.0, -8.0) # P = 12.0 < 18.0
		ball.step_ball(0.016, 0.0)
		balloon.interact_with_ball(ball)
		assert_false(balloon.is_smashed, "Low momentum (P=12 < 18) does not smash 2kg soft_balloon")
		assert_gt(ball.linear_velocity.z, 3.0, "soft_balloon bounces low-momentum ball back (+Z >= 3.5)")
		assert_gt(absf(ball.linear_velocity.x), 5.0, "soft_balloon pushes low-momentum ball sideways (±5.5)")

		ball.linear_velocity = Vector3(0.0, 0.0, -15.0) # P = 22.5 >= 18.0
		ball.step_ball(0.016, 0.0)
		balloon.interact_with_ball(ball)
		assert_true(balloon.is_smashed, "Momentum P=22.5 >= 18.0 smashes 2kg soft_balloon")
		assert_lt(ball.linear_velocity.z, -13.5, "Smashing soft_balloon loses only ~6% speed")

		var mag_iron = factory_script.create_aerial_blocker(Vector3(0.0, 4.2, -26.0), "mag_iron", 1.2)
		root.add_child(mag_iron)
		assert_eq(str(mag_iron.get_meta("weight_label", "")), "12kg", "mag_iron AerialBlocker exposes 12kg label")

		ball.linear_velocity = Vector3(0.0, 3.0, -16.0) # P ~ 24.4 < 36.0
		ball.step_ball(0.016, 0.0)
		mag_iron.interact_with_ball(ball)
		assert_false(mag_iron.is_smashed, "Medium momentum (P~24.4 < 36) blocked by 12kg mag_iron")
		assert_gt(ball.linear_velocity.z, -5.5, "mag_iron stalls aerial forward speed by ~70%")
		assert_lt(ball.linear_velocity.y, -2.4, "mag_iron forces aerial ball downward (vy <= -2.5)")

		ball.linear_velocity = Vector3(0.0, 0.0, -28.0) # P = 42.0 >= 36.0
		ball.step_ball(0.016, 0.0)
		mag_iron.interact_with_ball(ball)
		assert_true(mag_iron.is_smashed, "High momentum (P=42 >= 36) smashes 12kg mag_iron")

		var mag_iron_wave = factory_script.create_aerial_blocker(Vector3(1.5, 4.2, -27.0), "mag_iron", 0.0)
		root.add_child(mag_iron_wave)
		mag_iron_wave.apply_shockwave(Vector3(1.0, 4.0, -26.5), 6.5, 25.0, 1, ball)
		assert_true(mag_iron_wave.is_smashed, "Shockwave smashes mag_iron AerialBlocker")

	root.queue_free()
	await scene_tree.process_frame


func _test_sloped_floor_stability_and_flying_debris_barrel_hit() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	var mat_script: GDScript = load("res://src/core/material_library.gd")
	if factory_script == null or mat_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)

	var space_rid := root.get_world_3d().space
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.DOWN)
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, 22.0)

	# 11-degree sloped floor with high-friction physics
	var sloped_root := Node3D.new()
	sloped_root.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	root.add_child(sloped_root)

	var floor_body := StaticBody3D.new()
	floor_body.physics_material_override = mat_script.high_friction_physics(0.90, 0.10)
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(14.0, 0.6, 40.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.3, -15.0)
	floor_body.add_child(floor_col)
	sloped_root.add_child(floor_body)

	var c_light = factory_script.create_crate(Vector3(-3.0, 0.50, -8.0), "light")
	var c_med = factory_script.create_heavy_crate(Vector3(-1.0, 0.63, -8.0))
	var brute = factory_script.create_shield_brute(Vector3(1.5, 0.72, -8.0))
	var barrel = factory_script.create_explosive_barrel(Vector3(3.8, 0.64, -8.0))
	sloped_root.add_child(c_light)
	sloped_root.add_child(c_med)
	sloped_root.add_child(brute)
	sloped_root.add_child(barrel)

	for _f in range(35):
		await scene_tree.physics_frame

	assert_lt(absf(c_light.position.z - (-8.0)), 0.15, "500g light crate sits rock-solid on 11° sloped floor")
	assert_lt(absf(c_med.position.z - (-8.0)), 0.15, "2.5kg medium crate sits rock-solid on 11° sloped floor")
	assert_lt(absf(brute.position.z - (-8.0)), 0.15, "20kg ShieldBrute sits rock-solid on 11° sloped floor")
	assert_lt(absf(barrel.position.z - (-8.0)), 0.15, "1.5kg ExplosiveBarrel sits rock-solid on 11° sloped floor")
	assert_false(barrel.is_detonated, "ExplosiveBarrel never self-detonates while resting on sloped StaticBody3D floor")

	# Verify sloped track-basis knockback on ShieldBrute & BouncerSlime does not dip into -11° floor
	var slope_ball = _create_ball_in(root)
	slope_ball.track_reference = sloped_root
	slope_ball.global_position = sloped_root.to_global(Vector3(1.5, 0.55, -7.2))
	slope_ball.linear_velocity = -sloped_root.global_transform.basis.z.normalized() * 12.0
	slope_ball.step_ball(0.016, 0.0)
	var pre_local_y: float = sloped_root.to_local(slope_ball.global_position).y
	brute.interact_with_ball(slope_ball)
	var post_local_y: float = sloped_root.to_local(slope_ball.global_position).y
	assert_approx(post_local_y, pre_local_y, 0.01, "ShieldBrute uphill knockback stays parallel to -11° floor (0cm floor dip)")

	var slope_slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.65, -14.0), 0.0)
	sloped_root.add_child(slope_slime)
	slope_ball.global_position = sloped_root.to_global(Vector3(0.0, 0.55, -13.2))
	slope_ball.linear_velocity = (
		-sloped_root.global_transform.basis.z.normalized() * 6.0
		- sloped_root.global_transform.basis.y.normalized() * 2.0
	)
	slope_ball.step_ball(0.016, 0.0)
	slope_slime.interact_with_ball(slope_ball)
	assert_gt(
		slope_ball.linear_velocity.dot(sloped_root.global_transform.basis.z.normalized()),
		7.5,
		"BouncerSlime rebounds uphill along sloped track +Z"
	)
	assert_gt(
		slope_ball.linear_velocity.dot(sloped_root.global_transform.basis.y.normalized()),
		1.4,
		"BouncerSlime clears downward into-slope velocity and lifts cleanly along sloped +Y"
	)

	# Launch a smashed flying crate directly toward a target ExplosiveBarrel across physics frames
	var target_barrel = factory_script.create_explosive_barrel(Vector3(0.0, 2.5, -24.0))
	target_barrel.gravity_scale = 0.0
	var flying_crate = factory_script.create_crate(Vector3(0.0, 2.5, -21.5), "light")
	root.add_child(target_barrel)
	root.add_child(flying_crate)
	await scene_tree.physics_frame

	flying_crate._shatter(Vector3(0.0, 0.0, -20.0))
	flying_crate.gravity_scale = 0.0

	for _f in range(15):
		await scene_tree.physics_frame
		if target_barrel.is_detonated:
			break

	assert_true(
		target_barrel.is_detonated,
		"Smashed flying CrateObstacle triggers ExplosiveBarrel Area3D sensor in real 3D physics"
	)

	root.queue_free()
	await scene_tree.process_frame
