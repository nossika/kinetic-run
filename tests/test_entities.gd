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


func _has_area3d_child(node: Node) -> bool:
	if node == null:
		return false
	for child in node.get_children():
		if child is Area3D:
			return true
	return false


func _add_flat_floor(parent: Node3D, z_center: float = -15.0, z_len: float = 50.0) -> StaticBody3D:
	var mat_script: GDScript = load("res://src/core/material_library.gd")
	var floor_body := StaticBody3D.new()
	if mat_script != null:
		floor_body.physics_material_override = mat_script.high_friction_physics(0.88, 0.12)
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(16.0, 0.6, z_len)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.3, z_center)
	floor_body.add_child(floor_col)
	parent.add_child(floor_body)
	return floor_body


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
	_add_flat_floor(root, -15.0, 50.0)
	var ball = _create_ball_in(root)

	# 1a. Light CrateObstacle ("500g", mass=0.50, min_smash_impulse=1.6, zero Area3D)
	var light_crate = factory_script.create_crate(Vector3(0.0, 0.48, -10.0))
	root.add_child(light_crate)
	assert_true(light_crate is RigidBody3D, "Light CrateObstacle is a RigidBody3D")
	assert_approx(light_crate.mass, 0.50, 0.01, "Light crate mass is 0.5kg (500g)")
	assert_eq(str(light_crate.get_meta("weight_label", "")), "500g", "Light crate exposes 500g weight_label")
	assert_false(_has_area3d_child(light_crate), "Light CrateObstacle has zero Area3D child sensors")
	assert_approx(light_crate.linear_damp, 1.2, 0.02, "Resting light crate linear_damp is 1.2")
	assert_approx(light_crate.angular_damp, 1.8, 0.02, "Resting light crate angular_damp is 1.8")
	assert_true("min_smash_impulse" in light_crate, "CrateObstacle defines min_smash_impulse")
	if "min_smash_impulse" in light_crate:
		assert_approx(float(light_crate.min_smash_impulse), 1.6, 0.01, "500g crate min_smash_impulse is 1.6")

	var has_impact_api: bool = light_crate.has_method("on_ball_physical_impact") and light_crate.has_method("dislodge")
	assert_true(has_impact_api, "CrateObstacle exposes dislodge() and on_ball_physical_impact(impulse_mag)")
	if has_impact_api:
		var low_yield: bool = light_crate.on_ball_physical_impact(1.1)
		assert_false(low_yield, "Sub-threshold impulse (1.1 < 1.6) does not yield smash on 500g crate")
		assert_true(bool(light_crate.is_dislodged), "Impact dislodges 500g crate")
		assert_false(bool(light_crate.has_yielded_smash), "has_yielded_smash remains false below 1.6 impulse")
		assert_approx(light_crate.linear_damp, 0.12, 0.02, "Dislodged crate switches linear_damp to 0.12")
		assert_approx(light_crate.angular_damp, 0.22, 0.02, "Dislodged crate switches angular_damp to 0.22")

		var first_yield: bool = light_crate.on_ball_physical_impact(2.1)
		var second_yield: bool = light_crate.on_ball_physical_impact(3.5)
		assert_true(first_yield, "Impulse 2.1 >= 1.6 yields smash on 500g crate")
		assert_false(second_yield, "Second impact on same 500g crate does not yield smash twice")
		assert_true(bool(light_crate.has_yielded_smash), "500g crate sets has_yielded_smash == true")
		assert_eq(light_crate.collision_layer, 1, "Dislodged 500g crate keeps collision_layer == 1")
		assert_eq(light_crate.collision_mask, 1, "Dislodged 500g crate keeps collision_mask == 1")

	# 1b. Medium/Heavy CrateObstacle ("2kg", mass=2.00, 1.20m box, min_smash_impulse=2.6, yaw_deg support)
	var has_heavy := _script_has_method(factory_script, "create_heavy_crate")
	assert_true(has_heavy, "TrackEntityFactory exposes create_heavy_crate(pos, yaw_deg)")
	assert_eq(
		_script_method_arg_count(factory_script, "create_crate"),
		3,
		"TrackEntityFactory.create_crate accepts (pos, tier = 'light', yaw_deg = 0.0)"
	)
	assert_eq(
		_script_method_arg_count(factory_script, "create_heavy_crate"),
		2,
		"TrackEntityFactory.create_heavy_crate accepts (pos, yaw_deg = 0.0)"
	)
	if has_heavy:
		var med_crate = (
			factory_script.create_heavy_crate(Vector3(-2.5, 0.60, -12.0), 28.5)
			if _script_method_arg_count(factory_script, "create_heavy_crate") >= 2
			else factory_script.create_heavy_crate(Vector3(-2.5, 0.60, -12.0))
		)
		root.add_child(med_crate)
		assert_true(med_crate is RigidBody3D, "Medium CrateObstacle is a RigidBody3D")
		assert_eq(med_crate.weight_tier, "medium", "create_heavy_crate sets weight_tier to 'medium'")
		assert_approx(med_crate.mass, 2.00, 0.01, "Medium crate mass is 2.0kg")
		assert_eq(str(med_crate.get_meta("weight_label", "")), "2kg", "Medium crate exposes 2kg weight_label")
		assert_approx(med_crate.rotation_degrees.y, 28.5, 0.05, "create_heavy_crate applies yaw_deg rotation")
		assert_false(_has_area3d_child(med_crate), "Medium CrateObstacle has zero Area3D child sensors")
		if "min_smash_impulse" in med_crate:
			assert_approx(float(med_crate.min_smash_impulse), 2.6, 0.01, "2kg medium crate min_smash_impulse is 2.6")
		if med_crate.has_method("on_ball_physical_impact"):
			assert_false(med_crate.on_ball_physical_impact(2.0), "Impulse 2.0 (< 2.6) does not yield smash on 2kg crate")
			assert_true(med_crate.on_ball_physical_impact(3.1), "Impulse 3.1 (>= 2.6) yields smash on 2kg crate")
			assert_eq(med_crate.collision_layer, 1, "2kg crate keeps collision_layer == 1 after impact")
			assert_eq(med_crate.collision_mask, 1, "2kg crate keeps collision_mask == 1 after impact")

	if _script_method_arg_count(factory_script, "create_crate") >= 3:
		var med_via_tier = factory_script.create_crate(Vector3(2.5, 0.60, -12.0), "medium", -22.0)
		root.add_child(med_via_tier)
		assert_approx(med_via_tier.mass, 2.00, 0.01, "create_crate(pos, 'medium', yaw_deg) configures 2.0kg mass")
		assert_eq(str(med_via_tier.get_meta("weight_label", "")), "2kg", "create_crate(pos, 'medium', yaw_deg) sets 2kg label")
		assert_approx(med_via_tier.rotation_degrees.y, -22.0, 0.05, "create_crate applies yaw_deg rotation")

	# 1c. WoodenPin ("800g", mass=0.80, min_smash_impulse=1.6, zero Area3D)
	var has_pin := _script_has_method(factory_script, "create_wooden_pin")
	assert_true(has_pin, "TrackEntityFactory exposes create_wooden_pin(pos)")
	var pin: Node3D = null
	if has_pin:
		pin = factory_script.create_wooden_pin(Vector3(3.5, 0.78, -10.0))
		root.add_child(pin)
		assert_true(pin is RigidBody3D, "WoodenPin extends RigidBody3D")
		if pin is RigidBody3D:
			assert_approx((pin as RigidBody3D).mass, 0.80, 0.01, "WoodenPin mass is 0.80kg (800g)")
			assert_approx((pin as RigidBody3D).center_of_mass.y, -0.10, 0.01, "WoodenPin lowers center_of_mass.y to -0.10m")
		assert_eq(str(pin.get_meta("weight_label", "")), "800g", "WoodenPin exposes 800g weight_label")
		assert_false(_has_area3d_child(pin), "WoodenPin has zero Area3D child sensors")
		if "min_smash_impulse" in pin:
			assert_approx(float(pin.min_smash_impulse), 1.6, 0.01, "WoodenPin min_smash_impulse is 1.6")
		if pin.has_method("on_ball_physical_impact"):
			assert_true(pin.on_ball_physical_impact(2.0), "Impulse 2.0 (>= 1.6) yields smash on WoodenPin")
			assert_false(pin.on_ball_physical_impact(2.5), "WoodenPin yields smash at most once")
			assert_approx((pin as RigidBody3D).linear_damp, 0.10, 0.02, "Dislodged WoodenPin linear_damp is 0.10")
			assert_approx((pin as RigidBody3D).angular_damp, 0.18, 0.02, "Dislodged WoodenPin angular_damp is 0.18")
			assert_eq((pin as RigidBody3D).collision_layer, 1, "Dislodged WoodenPin keeps collision_layer == 1")
			assert_eq((pin as RigidBody3D).collision_mask, 1, "Dislodged WoodenPin keeps collision_mask == 1")

	# 1d. Pure Newtonian 1.5kg ball rolling into 500g light crate in real Jolt 3D physics
	var jolt_crate = factory_script.create_crate(Vector3(0.0, 0.48, -20.0), "light")
	root.add_child(jolt_crate)
	ball.global_position = Vector3(0.0, 0.55, -18.2)
	ball.linear_velocity = Vector3(0.0, 0.0, -12.0)
	ball.angular_velocity = Vector3.ZERO
	for _f in range(16):
		await scene_tree.physics_frame
	assert_lt(ball.linear_velocity.z, -2.5, "1.5kg ball retains strong forward -Z motion through 500g crate")
	assert_lt(jolt_crate.position.z, -21.0, "1.5kg ball launches 500g crate forward along -Z in Jolt 3D")
	assert_eq(jolt_crate.collision_layer, 1, "Hit 500g crate stays on collision_layer == 1")
	assert_eq(jolt_crate.collision_mask, 1, "Hit 500g crate stays on collision_mask == 1")

	# 2. BouncerSlime ("3kg", threshold P >= 22.0)
	var slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.5, -32.0), 3.0)
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
	_add_flat_floor(root, -18.0, 60.0)
	var ball = _create_ball_in(root)
	var catalog = catalog_script.new()

	# 1. ShieldBrute: 20kg cast-iron RigidBody3D, zero Area3D, pure Newtonian head-on rebound
	var brute = factory_script.create_shield_brute(Vector3(0.0, 0.70, -10.0))
	root.add_child(brute)
	assert_true(brute is RigidBody3D, "ShieldBrute extends RigidBody3D")
	if brute is RigidBody3D:
		assert_approx(brute.mass, 20.0, 0.01, "ShieldBrute mass is 20.0kg")
		assert_approx(brute.linear_damp, 1.2, 0.02, "Resting ShieldBrute linear_damp is 1.2")
		assert_approx(brute.angular_damp, 1.8, 0.02, "Resting ShieldBrute angular_damp is 1.8")
	assert_eq(str(brute.get_meta("weight_label", "")), "20kg", "ShieldBrute exposes 20kg weight_label")
	assert_false(_has_area3d_child(brute), "ShieldBrute has zero Area3D child sensors")
	assert_true("min_smash_impulse" in brute, "ShieldBrute defines min_smash_impulse")
	if "min_smash_impulse" in brute:
		assert_approx(float(brute.min_smash_impulse), 4.5, 0.01, "20kg ShieldBrute min_smash_impulse is 4.5")

	# Pure Newtonian Jolt 3D head-on collision: 1.5kg ball rebounds backward (+Z > 0.2) off 20kg ShieldBrute
	ball.global_position = Vector3(0.0, 0.55, -8.35)
	ball.linear_velocity = Vector3(0.0, 0.0, -15.0)
	ball.angular_velocity = Vector3.ZERO
	var peak_rebound_z := -99.0
	for _f in range(8):
		await scene_tree.physics_frame
		peak_rebound_z = maxf(peak_rebound_z, ball.linear_velocity.z)

	assert_gt(peak_rebound_z, 0.2, "1.5kg ball rolling head-on into 20kg ShieldBrute rebounds backward (+Z > 0.2)")
	assert_lt(absf(brute.position.z - (-10.0)), 0.45, "20kg ShieldBrute barely shifts when struck by 1.5kg ball")
	assert_eq(brute.collision_layer, 1, "20kg ShieldBrute stays on collision_layer == 1 after collision")
	assert_eq(brute.collision_mask, 1, "20kg ShieldBrute stays on collision_mask == 1 after collision")

	# 2. Shockwave + 90-frame (1.5s > 0.75s) persistence across CrateObstacle, WoodenPin, ShieldBrute
	var persist_light = factory_script.create_crate(Vector3(-3.5, 0.48, -20.0), "light")
	var persist_med = factory_script.create_heavy_crate(Vector3(-1.5, 0.60, -20.0))
	var persist_brute = factory_script.create_shield_brute(Vector3(1.5, 0.70, -20.0))
	var persist_pin: Node3D = (
		factory_script.create_wooden_pin(Vector3(3.5, 0.78, -20.0))
		if _script_has_method(factory_script, "create_wooden_pin")
		else null
	)
	root.add_child(persist_light)
	root.add_child(persist_med)
	root.add_child(persist_brute)
	if persist_pin != null:
		root.add_child(persist_pin)
	await scene_tree.physics_frame

	var smash_count := {"n": 0}
	ball.target_smashed.connect(func(_p: Vector3) -> void: smash_count["n"] = int(smash_count["n"]) + 1)

	persist_light.apply_shockwave(Vector3(-3.5, 0.4, -18.5), 6.5, 120.0, 1, ball)
	persist_light.apply_shockwave(Vector3(-3.5, 0.4, -18.5), 6.5, 120.0, 1, ball)
	assert_eq(int(smash_count["n"]), 1, "Repeated shockwaves notify ball smash at most once per obstacle")
	persist_med.apply_shockwave(Vector3(-1.5, 0.4, -18.5), 6.5, 25.0, 1, ball)
	persist_brute.apply_shockwave(Vector3(1.5, 0.4, -18.5), 6.5, 28.0, 1, ball)
	if persist_pin != null and persist_pin.has_method("apply_shockwave"):
		persist_pin.apply_shockwave(Vector3(3.5, 0.4, -18.5), 6.5, 25.0, 1, ball)

	assert_true(persist_brute.get("has_yielded_smash") == true, "Shockwave yields smash on 20kg ShieldBrute")
	assert_approx(persist_brute.linear_damp, 0.16, 0.02, "Dislodged ShieldBrute linear_damp is 0.16")
	assert_approx(persist_brute.angular_damp, 0.28, 0.02, "Dislodged ShieldBrute angular_damp is 0.28")

	await scene_tree.physics_frame
	assert_lt(persist_light.linear_velocity.length(), 32.5, "Shockwave clamps 500g crate launch speed to <= 32 m/s")

	for _f in range(90):
		await scene_tree.physics_frame

	assert_true(is_instance_valid(persist_light), "500g crate remains valid after 90 physics frames (no 0.75s TTL)")
	assert_true(is_instance_valid(persist_med), "2kg crate remains valid after 90 physics frames (no 0.75s TTL)")
	assert_true(is_instance_valid(persist_brute), "20kg ShieldBrute remains valid after 90 physics frames (no 0.75s TTL)")
	if is_instance_valid(persist_light):
		assert_eq(persist_light.collision_layer, 1, "500g crate keeps collision_layer == 1 after shockwave & 90 frames")
		assert_eq(persist_light.collision_mask, 1, "500g crate keeps collision_mask == 1 after shockwave & 90 frames")
	if is_instance_valid(persist_brute):
		assert_eq(persist_brute.collision_layer, 1, "ShieldBrute keeps collision_layer == 1 after shockwave & 90 frames")
		assert_eq(persist_brute.collision_mask, 1, "ShieldBrute keeps collision_mask == 1 after shockwave & 90 frames")
	if persist_pin != null:
		assert_true(is_instance_valid(persist_pin), "800g WoodenPin remains valid after 90 physics frames (no 0.75s TTL)")
		if is_instance_valid(persist_pin):
			assert_eq((persist_pin as RigidBody3D).collision_layer, 1, "WoodenPin keeps collision_layer == 1 after shockwave")
			assert_eq((persist_pin as RigidBody3D).collision_mask, 1, "WoodenPin keeps collision_mask == 1 after shockwave")

	# 3. Abyss cleanup (< -28.0 local Y) frees fallen ground obstacles silently
	var abyss_crate = factory_script.create_crate(Vector3(0.0, -29.5, -10.0), "light")
	var abyss_brute = factory_script.create_shield_brute(Vector3(2.0, -29.5, -10.0))
	var abyss_pin: Node3D = (
		factory_script.create_wooden_pin(Vector3(-2.0, -29.5, -10.0))
		if _script_has_method(factory_script, "create_wooden_pin")
		else null
	)
	root.add_child(abyss_crate)
	root.add_child(abyss_brute)
	if abyss_pin != null:
		root.add_child(abyss_pin)
	await scene_tree.physics_frame
	await scene_tree.process_frame
	assert_false(is_instance_valid(abyss_crate), "CrateObstacle below -28.0m abyss cleans itself up")
	assert_false(is_instance_valid(abyss_brute), "ShieldBrute below -28.0m abyss cleans itself up")
	if _script_has_method(factory_script, "create_wooden_pin"):
		assert_false(is_instance_valid(abyss_pin), "WoodenPin below -28.0m abyss cleans itself up")

	# 4. SlimeZone damp + Maglev immunity
	var zone = factory_script.create_slime_zone(Vector3(0.0, 0.05, -35.0), Vector2(4.0, 6.0))
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
	assert_true(near_crate.get("has_yielded_smash") == true, "Barrel blast shockwave yields smash on nearby CrateObstacle")
	assert_true(near_brute.get("has_yielded_smash") == true, "Barrel blast shockwave yields smash on nearby ShieldBrute")
	assert_eq(near_crate.collision_layer, 1, "Shockwaved CrateObstacle remains on collision_layer == 1")
	assert_eq(near_brute.collision_layer, 1, "Shockwaved ShieldBrute remains on collision_layer == 1")
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

	var c_light = factory_script.create_crate(Vector3(-3.2, 0.50, -8.0), "light")
	var c_med = factory_script.create_heavy_crate(Vector3(-1.4, 0.62, -8.0))
	var pin: Node3D = (
		factory_script.create_wooden_pin(Vector3(0.2, 0.79, -8.0))
		if _script_has_method(factory_script, "create_wooden_pin")
		else null
	)
	var brute = factory_script.create_shield_brute(Vector3(2.0, 0.72, -8.0))
	var barrel = factory_script.create_explosive_barrel(Vector3(4.2, 0.64, -8.0))
	sloped_root.add_child(c_light)
	sloped_root.add_child(c_med)
	if pin != null:
		sloped_root.add_child(pin)
	sloped_root.add_child(brute)
	sloped_root.add_child(barrel)

	for _f in range(35):
		await scene_tree.physics_frame

	assert_lt(absf(c_light.position.z - (-8.0)), 0.15, "500g light crate sits rock-solid on 11° sloped floor")
	assert_lt(absf(c_med.position.z - (-8.0)), 0.15, "2kg medium crate sits rock-solid on 11° sloped floor")
	assert_lt(absf(brute.position.z - (-8.0)), 0.15, "20kg ShieldBrute sits rock-solid on 11° sloped floor")
	assert_lt(absf(barrel.position.z - (-8.0)), 0.15, "1.5kg ExplosiveBarrel sits rock-solid on 11° sloped floor")
	assert_false(barrel.is_detonated, "ExplosiveBarrel never self-detonates while resting on sloped StaticBody3D floor")

	assert_true(pin != null, "WoodenPin spawned on -11° sloped floor")
	if pin != null:
		var rest_up_dot: float = pin.transform.basis.y.normalized().dot(Vector3.UP)
		assert_gt(rest_up_dot, 0.98, "800g WoodenPin stands upright on -11° sloped floor for 35 frames (up_dot > 0.98)")
		assert_lt(absf(pin.position.z - (-8.0)), 0.12, "800g WoodenPin does not slide on -11° sloped floor (|dz| < 0.12)")

	# Strike WoodenPin with a rolling 1.5kg PlayerBall3D on the -11° slope -> topples dramatically (up_dot < 0.75)
	var slope_ball = _create_ball_in(root)
	slope_ball.track_reference = sloped_root
	if pin != null:
		slope_ball.global_position = sloped_root.to_global(Vector3(0.2, 0.55, -6.2))
		slope_ball.linear_velocity = -sloped_root.global_transform.basis.z.normalized() * 14.0
		slope_ball.angular_velocity = Vector3.ZERO
		var min_pin_up_dot := 1.0
		for _f in range(45):
			await scene_tree.physics_frame
			var cur_dot: float = pin.transform.basis.y.normalized().dot(Vector3.UP)
			min_pin_up_dot = minf(min_pin_up_dot, cur_dot)
		assert_lt(min_pin_up_dot, 0.75, "800g WoodenPin topples dramatically (up_dot < 0.75) when struck by rolling 1.5kg ball")
		assert_true(is_instance_valid(pin), "Toppled WoodenPin remains persistently on the sloped track")

	var slope_slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.65, -18.0), 0.0)
	sloped_root.add_child(slope_slime)
	slope_ball.global_position = sloped_root.to_global(Vector3(0.0, 0.55, -17.2))
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

	# Launch a dislodged flying crate directly toward a target ExplosiveBarrel across physics frames
	var target_barrel = factory_script.create_explosive_barrel(Vector3(0.0, 2.5, -24.0))
	target_barrel.gravity_scale = 0.0
	var flying_crate = factory_script.create_crate(Vector3(0.0, 2.5, -21.5), "light")
	root.add_child(target_barrel)
	root.add_child(flying_crate)
	await scene_tree.physics_frame

	if flying_crate.has_method("dislodge"):
		flying_crate.dislodge()
	flying_crate.gravity_scale = 0.0
	flying_crate.linear_velocity = Vector3(0.0, 0.0, -20.0)

	for _f in range(15):
		await scene_tree.physics_frame
		if target_barrel.is_detonated:
			break

	assert_true(
		target_barrel.is_detonated,
		"Dislodged flying CrateObstacle triggers ExplosiveBarrel in real 3D physics"
	)

	root.queue_free()
	await scene_tree.process_frame
