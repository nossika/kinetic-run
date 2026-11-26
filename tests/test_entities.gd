extends TestBase


func run() -> void:
	await _test_crate_tiers_and_slime_momentum_thresholds()
	await _test_shield_brute_rigidbody_and_slime_zone()
	await _test_boost_pad_anchored_bumper_and_barrel_rigidbody_chain()
	await _test_spring_pad_bonus_ring_and_aerial_blockers()
	await _test_sloped_floor_stability_and_flying_debris_barrel_hit()
	await _test_wind_zone_3d_vectors_synergy_and_indiscriminate_rigidbodies()


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

	# 2. BouncerSlime ("3kg" RigidBody3D, R=0.66, bounce=0.88, deterministic patrol, persistent after hit)
	var slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.66, -32.0), 2.8)
	var slime_twin = factory_script.create_bouncer_slime(Vector3(0.0, 0.66, -36.0), 2.8)
	root.add_child(slime)
	root.add_child(slime_twin)
	assert_true(slime is RigidBody3D, "BouncerSlime extends RigidBody3D")
	assert_false(_has_area3d_child(slime), "BouncerSlime has zero Area3D child sensors")
	assert_eq(str(slime.get_meta("weight_label", "")), "3kg", "BouncerSlime exposes 3kg weight_label")
	assert_true(bool(slime.get_meta("has_clay_eyes", false)), "BouncerSlime character sports cute clay eyes")
	if slime is RigidBody3D:
		var slime_rb := slime as RigidBody3D
		assert_approx(slime_rb.mass, 3.0, 0.01, "BouncerSlime mass is 3.0kg")
		assert_false(slime_rb.freeze, "BouncerSlime stays freeze == false while patrolling")
		assert_true(slime_rb.lock_rotation, "BouncerSlime locks rotation while patrolling")
		assert_approx(slime_rb.gravity_scale, 0.0, 0.01, "BouncerSlime gravity_scale is 0.0 while patrolling")
		assert_true(slime_rb.physics_material_override != null, "BouncerSlime has PhysicsMaterial")
		if slime_rb.physics_material_override != null:
			assert_true(slime_rb.physics_material_override.bounce >= 0.85, "BouncerSlime bounce >= 0.85 (0.88)")
			assert_approx(slime_rb.physics_material_override.friction, 0.45, 0.02, "BouncerSlime friction is 0.45")

	assert_true("is_patrolling" in slime and bool(slime.get("is_patrolling")), "BouncerSlime starts with is_patrolling == true")
	assert_true("is_dislodged" in slime and not bool(slime.get("is_dislodged")), "BouncerSlime starts with is_dislodged == false")
	assert_true("min_smash_impulse" in slime, "BouncerSlime defines min_smash_impulse")
	if "min_smash_impulse" in slime:
		assert_approx(float(slime.get("min_smash_impulse")), 3.2, 0.01, "BouncerSlime min_smash_impulse is 3.2")

	slime._physics_process(0.25)
	slime_twin._physics_process(0.25)
	assert_gt(slime.position.x, 0.5, "BouncerSlime patrols horizontally along +X before hit")
	assert_approx(slime.position.x, slime_twin.position.x, 0.0001, "BouncerSlime patrol is 100% deterministic")

	if slime_twin.has_method("on_ball_physical_impact"):
		assert_false(slime_twin.on_ball_physical_impact(1.4), "Gentle impulse (1.4 < 2.2) does not yield smash on BouncerSlime")
		assert_true(bool(slime_twin.get("is_patrolling")), "Gentle impulse (< 2.2) keeps BouncerSlime patrolling")
		assert_false(slime_twin.on_ball_physical_impact(2.5), "Medium impulse (2.5 < 3.2) dislodges BouncerSlime without smash")
		assert_false(bool(slime_twin.get("is_patrolling")), "Impulse >= 2.2 stops BouncerSlime patrolling")
		assert_true(bool(slime_twin.get("is_dislodged")), "Impulse >= 2.2 marks BouncerSlime is_dislodged == true")
		assert_true(slime_twin.on_ball_physical_impact(3.6), "Strong impulse (3.6 >= 3.2) yields smash on BouncerSlime")
		assert_false(slime_twin.on_ball_physical_impact(4.2), "BouncerSlime yields smash at most once")

	slime_twin.queue_free()

	# Real Jolt 3D collision between 1.5kg PlayerBall3D and 3.0kg BouncerSlime + 90-frame persistence
	var live_slime = factory_script.create_bouncer_slime(Vector3(0.0, 0.66, -32.0), 0.0)
	root.add_child(live_slime)
	await scene_tree.physics_frame

	ball.global_position = Vector3(0.0, 0.55, -30.1)
	ball.linear_velocity = Vector3(0.0, 0.0, -16.0)
	ball.angular_velocity = Vector3.ZERO
	ball._saved_velocity_pre_step = ball.linear_velocity

	for _f in range(12):
		await scene_tree.physics_frame

	assert_true(live_slime.get("is_dislodged") == true, "Ball collision transitions BouncerSlime to is_dislodged == true")
	assert_true(live_slime.get("is_patrolling") == false, "Ball collision stops BouncerSlime patrol")
	if live_slime is RigidBody3D:
		assert_approx((live_slime as RigidBody3D).gravity_scale, 1.0, 0.01, "Dislodged BouncerSlime restores gravity_scale == 1.0")
		assert_approx((live_slime as RigidBody3D).linear_damp, 0.12, 0.02, "Dislodged BouncerSlime linear_damp is 0.12")
		assert_approx((live_slime as RigidBody3D).angular_damp, 0.20, 0.02, "Dislodged BouncerSlime angular_damp is 0.20")

	for _f in range(90):
		await scene_tree.physics_frame

	assert_true(is_instance_valid(live_slime), "Dislodged BouncerSlime remains valid after 90 physics frames (no TTL)")
	if is_instance_valid(live_slime) and live_slime is RigidBody3D:
		assert_true(live_slime.visible, "Dislodged BouncerSlime stays visible")
		assert_eq((live_slime as RigidBody3D).collision_layer, 1, "Dislodged BouncerSlime keeps collision_layer == 1")
		assert_eq((live_slime as RigidBody3D).collision_mask, 1, "Dislodged BouncerSlime keeps collision_mask == 1")

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
	assert_true(bool(brute.get_meta("has_clay_eyes", false)), "ShieldBrute character sports cute clay eyes")
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

	# PinballBumper (anchored fixed StaticBody3D, zero Area3D, group "pinball_bumper", bounce >= 0.90)
	var bumper = factory_script.create_pinball_bumper(Vector3(1.0, 0.6, -20.0))
	root.add_child(bumper)
	assert_true(bumper is StaticBody3D, "PinballBumper extends StaticBody3D")
	assert_false(_has_area3d_child(bumper), "PinballBumper has zero Area3D child sensors")
	assert_true(bumper.is_in_group("pinball_bumper"), "PinballBumper belongs to group 'pinball_bumper'")
	assert_eq(
		bool(bumper.get_meta("is_anchored_fixed", false)),
		true,
		"PinballBumper exposes is_anchored_fixed == true"
	)
	assert_true(
		bumper.get_node_or_null("BumperTopFixedStencil") == null,
		"PinballBumper removes cluttered FIXED top stencil text"
	)
	assert_true(bumper.physics_material_override != null, "PinballBumper defines PhysicsMaterial")
	if bumper.physics_material_override != null:
		assert_true(bumper.physics_material_override.bounce >= 0.90, "PinballBumper bounce >= 0.90 (0.95)")
		assert_approx(bumper.physics_material_override.friction, 0.05, 0.02, "PinballBumper friction is 0.05")

	assert_true(bumper.has_method("trigger_bumper_bounce"), "PinballBumper exposes trigger_bumper_bounce(ball, contact_normal)")
	ball.global_position = Vector3(0.0, 0.6, -20.0)
	ball.linear_velocity = Vector3(2.0, 0.0, -10.0)
	ball.step_ball(0.016, 0.0)
	if bumper.has_method("trigger_bumper_bounce"):
		bumper.trigger_bumper_bounce(ball, Vector3(-1.0, 0.0, 0.0))
		assert_true(ball.linear_velocity.x <= -8.49, "trigger_bumper_bounce kicks ball radially along contact_normal (>= 8.5 m/s)")
		assert_lt(ball.linear_velocity.z, -30.0, "trigger_bumper_bounce + Tailwind Sail strongly boosts ball along -Z")
		var post_first_vz: float = ball.linear_velocity.z
		bumper.trigger_bumper_bounce(ball, Vector3(-1.0, 0.0, 0.0))
		assert_approx(ball.linear_velocity.z, post_first_vz, 0.01, "trigger_bumper_bounce respects 0.16s cooldown")

	# ExplosiveBarrel: 1.5kg RigidBody3D, zero Area3D -> 0.45kg "EMPTY" persistent husk on detonate + shockwave blast
	var barrel = factory_script.create_explosive_barrel(Vector3(0.0, 0.6, -30.0))
	var near_crate = factory_script.create_crate(Vector3(1.5, 0.5, -32.0))
	var near_brute = factory_script.create_shield_brute(Vector3(-1.5, 0.7, -33.0))
	root.add_child(barrel)
	root.add_child(near_crate)
	root.add_child(near_brute)

	assert_true(barrel is RigidBody3D, "ExplosiveBarrel extends RigidBody3D")
	assert_false(_has_area3d_child(barrel), "ExplosiveBarrel has zero Area3D child sensors")
	if barrel is RigidBody3D:
		assert_approx(barrel.mass, 1.5, 0.01, "ExplosiveBarrel pre-detonation mass is 1.5kg")
		assert_true(barrel.contact_monitor, "ExplosiveBarrel enables contact_monitor")
		assert_true(barrel.max_contacts_reported >= 6, "ExplosiveBarrel max_contacts_reported >= 6")
	assert_eq(str(barrel.get_meta("weight_label", "")), "1.5kg", "ExplosiveBarrel exposes 1.5kg weight_label")

	var exploded_count := {"n": 0}
	barrel.barrel_exploded.connect(func(_o: Vector3, _r: float, _f: float, _d: int) -> void: exploded_count["n"] = int(exploded_count["n"]) + 1)

	var entities: Array[Node3D] = [barrel, near_crate, near_brute]
	await scene_tree.physics_frame
	ball.global_position = Vector3(0.0, 0.6, -30.8) # slightly in front (-Z) of barrel
	ball.linear_velocity = Vector3(0.0, 0.0, -10.0)
	ball.step_ball(0.016, 0.0)
	barrel.detonate(ball, entities, 0)
	barrel.detonate(ball, entities, 0)
	var post_blast_ball_vz: float = ball.linear_velocity.z
	await scene_tree.physics_frame

	assert_true(is_instance_valid(barrel), "Detonated ExplosiveBarrel husk is not freed")
	if is_instance_valid(barrel):
		assert_true(barrel.is_detonated, "Barrel marks itself detonated")
		assert_true(barrel.visible, "Detonated ExplosiveBarrel husk remains visible == true")
		assert_eq(barrel.collision_layer, 1, "Detonated ExplosiveBarrel husk keeps collision_layer == 1")
		assert_eq(barrel.collision_mask, 1, "Detonated ExplosiveBarrel husk keeps collision_mask == 1")
		assert_approx(barrel.mass, 0.45, 0.01, "Detonated ExplosiveBarrel husk switches to mass == 0.45kg")
		assert_eq(str(barrel.get_meta("weight_label", "")), "EMPTY", "Detonated ExplosiveBarrel husk updates weight_label to 'EMPTY'")
		assert_approx(barrel.linear_damp, 0.14, 0.02, "Detonated ExplosiveBarrel husk linear_damp is 0.14")
		assert_approx(barrel.angular_damp, 0.24, 0.02, "Detonated ExplosiveBarrel husk angular_damp is 0.24")
		assert_gt(barrel.linear_velocity.length(), 4.0, "Detonated ExplosiveBarrel husk launches itself with spin/velocity")
	assert_eq(int(exploded_count["n"]), 1, "ExplosiveBarrel detonates at most once")
	assert_true(near_crate.get("has_yielded_smash") == true, "Barrel blast shockwave yields smash on nearby CrateObstacle")
	assert_true(near_brute.get("has_yielded_smash") == true, "Barrel blast shockwave yields smash on nearby ShieldBrute")
	assert_gt(near_crate.linear_velocity.length(), 2.0, "Barrel shockwave physically blasts nearby CrateObstacle")
	assert_gt(near_brute.linear_velocity.length(), 0.5, "Barrel shockwave physically blasts nearby ShieldBrute")
	assert_eq(near_crate.collision_layer, 1, "Shockwaved CrateObstacle remains on collision_layer == 1")
	assert_eq(near_brute.collision_layer, 1, "Shockwaved ShieldBrute remains on collision_layer == 1")
	assert_lt(post_blast_ball_vz, -25.0, "Barrel blast propels ball forward along -Z")

	# Secondary barrel: ignores self, static floor, and slow RigidBody3D (<= 2.6 m/s); detonates on > 2.6 m/s or ball contact
	var barrel_impact = factory_script.create_explosive_barrel(Vector3(3.0, 0.65, -35.0))
	var flying_crate = factory_script.create_crate(Vector3(3.0, 0.65, -33.0))
	var dummy_static := StaticBody3D.new()
	root.add_child(barrel_impact)
	root.add_child(flying_crate)
	root.add_child(dummy_static)

	barrel_impact._on_sensor_body_entered(barrel_impact)
	assert_false(barrel_impact.is_detonated, "ExplosiveBarrel never self-detonates from own RigidBody3D")
	barrel_impact._on_sensor_body_entered(dummy_static)
	assert_false(barrel_impact.is_detonated, "StaticBody3D floor contact never detonates ExplosiveBarrel")

	flying_crate.linear_velocity = Vector3(0.0, 0.0, -2.5) # <= 2.6 m/s
	barrel_impact._on_sensor_body_entered(flying_crate)
	assert_false(barrel_impact.is_detonated, "Slow RigidBody3D (<= 2.6 m/s) does not detonate ExplosiveBarrel")

	flying_crate.linear_velocity = Vector3(0.0, 0.0, -3.2) # > 2.6 m/s
	barrel_impact._on_sensor_body_entered(flying_crate)
	assert_true(barrel_impact.is_detonated, "Fast flying RigidBody3D (> 2.6 m/s) detonates ExplosiveBarrel")
	assert_approx(barrel_impact.mass, 0.45, 0.01, "Debris-detonated barrel becomes 0.45kg EMPTY husk")

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
		assert_true(ring.with_ground_stem, "create_aerial_bonus_ring(pos) defaults with_ground_stem to true")
		var stemless_ring = factory_script.create_aerial_bonus_ring(Vector3(0.0, 6.0, -18.0), false)
		root.add_child(stemless_ring)
		assert_false(stemless_ring.with_ground_stem, "create_aerial_bonus_ring(pos, false) sets with_ground_stem == false")
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

	# 3. AerialBlocker: "soft_balloon" (0.25kg "250g", bounce>=0.90) vs "mag_iron" (12kg "12kg") RigidBody3D + deterministic phase
	var has_blocker := _script_has_method(factory_script, "create_aerial_blocker")
	assert_true(has_blocker, "TrackEntityFactory exposes create_aerial_blocker(pos, blocker_type, initial_phase)")
	if has_blocker:
		var balloon = factory_script.create_aerial_blocker(Vector3(0.0, 4.0, -22.0), "soft_balloon", 0.6)
		var balloon_twin = factory_script.create_aerial_blocker(Vector3(0.0, 4.0, -22.0), "soft_balloon", 0.6)
		root.add_child(balloon)
		root.add_child(balloon_twin)

		assert_true(balloon is RigidBody3D, "soft_balloon AerialBlocker extends RigidBody3D")
		assert_false(_has_area3d_child(balloon), "soft_balloon AerialBlocker has zero Area3D child sensors")
		assert_eq(str(balloon.get_meta("weight_label", "")), "250g", "soft_balloon AerialBlocker exposes 250g label")
		assert_true(bool(balloon.get_meta("has_clay_eyes", false)), "soft_balloon AerialBlocker sports cute clay eyes")
		if balloon is RigidBody3D:
			var b_rb := balloon as RigidBody3D
			assert_approx(b_rb.mass, 0.25, 0.01, "soft_balloon mass is 0.25kg")
			assert_false(b_rb.freeze, "soft_balloon stays freeze == false while tethered")
			assert_approx(b_rb.gravity_scale, 0.0, 0.01, "soft_balloon gravity_scale is 0.0 while tethered")
			assert_true(b_rb.physics_material_override != null, "soft_balloon has PhysicsMaterial")
			if b_rb.physics_material_override != null:
				assert_true(b_rb.physics_material_override.bounce >= 0.90, "soft_balloon bounce >= 0.90 (0.92)")
				assert_approx(b_rb.physics_material_override.friction, 0.35, 0.02, "soft_balloon friction is 0.35")

		assert_true("is_tethered" in balloon and bool(balloon.get("is_tethered")), "soft_balloon starts tethered")
		if "min_smash_impulse" in balloon:
			assert_approx(float(balloon.get("min_smash_impulse")), 0.8, 0.01, "soft_balloon min_smash_impulse is 0.8")

		balloon._physics_process(0.25)
		balloon_twin._physics_process(0.25)
		assert_approx(
			balloon.position.distance_to(balloon_twin.position),
			0.0,
			0.0001,
			"AerialBlocker bobbing/swaying is 100% deterministic for identical initial_phase"
		)

		if balloon.has_method("on_ball_physical_impact"):
			assert_false(balloon.on_ball_physical_impact(0.6), "Impulse 0.6 (< 0.8) untethers balloon without yielding smash")
			assert_false(bool(balloon.get("is_tethered")), "Impulse >= 0.5 untethers soft_balloon")
			if balloon is RigidBody3D:
				assert_approx((balloon as RigidBody3D).gravity_scale, 0.28, 0.02, "Untethered soft_balloon floats at gravity_scale ~ 0.28")
				assert_approx((balloon as RigidBody3D).linear_damp, 0.48, 0.02, "Untethered soft_balloon linear_damp is 0.48")
			assert_true(balloon.on_ball_physical_impact(1.1), "Impulse 1.1 (>= 0.8) yields smash on soft_balloon")
			assert_false(balloon.on_ball_physical_impact(1.5), "soft_balloon yields smash at most once")

		var mag_iron = factory_script.create_aerial_blocker(Vector3(0.0, 4.2, -26.0), "mag_iron", 1.2)
		root.add_child(mag_iron)
		assert_true(mag_iron is RigidBody3D, "mag_iron AerialBlocker extends RigidBody3D")
		assert_false(_has_area3d_child(mag_iron), "mag_iron AerialBlocker has zero Area3D child sensors")
		assert_eq(str(mag_iron.get_meta("weight_label", "")), "12kg", "mag_iron AerialBlocker exposes 12kg label")
		assert_true(bool(mag_iron.get_meta("has_clay_eyes", false)), "mag_iron AerialBlocker sports cute clay eyes")
		if mag_iron is RigidBody3D:
			var m_rb := mag_iron as RigidBody3D
			assert_approx(m_rb.mass, 12.0, 0.01, "mag_iron mass is 12.0kg")
			assert_false(m_rb.freeze, "mag_iron stays freeze == false while tethered")
			assert_approx(m_rb.gravity_scale, 0.0, 0.01, "mag_iron gravity_scale is 0.0 while tethered")

		if "min_smash_impulse" in mag_iron:
			assert_approx(float(mag_iron.get("min_smash_impulse")), 4.5, 0.01, "mag_iron min_smash_impulse is 4.5")

		if mag_iron.has_method("on_ball_physical_impact"):
			assert_false(mag_iron.on_ball_physical_impact(3.0), "Impulse 3.0 (< 4.5) does not untether or smash 12kg mag_iron")
			assert_true(bool(mag_iron.get("is_tethered")), "mag_iron stays tethered below 4.5 impulse")
			assert_true(mag_iron.on_ball_physical_impact(5.2), "Impulse 5.2 (>= 4.5) untethers and smashes 12kg mag_iron")
			assert_false(bool(mag_iron.get("is_tethered")), "mag_iron untethers at >= 4.5 impulse")
			if mag_iron is RigidBody3D:
				assert_approx((mag_iron as RigidBody3D).gravity_scale, 1.0, 0.01, "Untethered mag_iron restores gravity_scale == 1.0")
				assert_approx((mag_iron as RigidBody3D).linear_damp, 0.14, 0.02, "Untethered mag_iron linear_damp is 0.14")
			if "_mag_ring" in mag_iron and mag_iron.get("_mag_ring") != null:
				assert_false((mag_iron.get("_mag_ring") as Node3D).visible, "Untethered mag_iron hides _mag_ring")

		var mag_iron_wave = factory_script.create_aerial_blocker(Vector3(1.5, 4.2, -27.0), "mag_iron", 0.0)
		root.add_child(mag_iron_wave)
		mag_iron_wave.apply_shockwave(Vector3(1.0, 4.0, -26.5), 6.5, 25.0, 1, ball)
		assert_true(mag_iron_wave.get("is_tethered") == false, "Shockwave untethers mag_iron AerialBlocker")
		assert_true(mag_iron_wave.get("has_yielded_smash") == true, "Shockwave yields smash on mag_iron AerialBlocker")

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
	floor_box.size = Vector3(16.0, 0.6, 70.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.3, -30.0)
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

	# Real Jolt 3D collision on sloped floor: untethered soft_balloon floats gently while mag_iron drops onto floor,
	# and fast CrateObstacle detonates ExplosiveBarrel into a persistent 0.45kg EMPTY husk across 90 physics frames!
	var drop_balloon = factory_script.create_aerial_blocker(Vector3(-4.2, 3.2, -16.0), "soft_balloon", 0.0)
	var drop_iron = factory_script.create_aerial_blocker(Vector3(4.2, 3.2, -16.0), "mag_iron", 0.0)
	var husk_barrel = factory_script.create_explosive_barrel(Vector3(0.0, 0.65, -20.0))
	var fast_crate = factory_script.create_crate(Vector3(0.0, 0.55, -17.5), "light")
	sloped_root.add_child(drop_balloon)
	sloped_root.add_child(drop_iron)
	sloped_root.add_child(husk_barrel)
	sloped_root.add_child(fast_crate)
	await scene_tree.physics_frame

	if drop_balloon.has_method("untether"):
		drop_balloon.untether()
	if drop_iron.has_method("untether"):
		drop_iron.untether()
	if fast_crate.has_method("dislodge"):
		fast_crate.dislodge()
	fast_crate.linear_velocity = -sloped_root.global_transform.basis.z.normalized() * 22.0

	for _f in range(18):
		await scene_tree.physics_frame

	assert_gt(
		drop_balloon.position.y,
		drop_iron.position.y + 0.45,
		"Untethered 250g soft_balloon floats gently while 12kg mag_iron drops rapidly under full gravity"
	)
	assert_true(is_instance_valid(husk_barrel), "Detonated ExplosiveBarrel husk stays alive in scene")
	if is_instance_valid(husk_barrel):
		assert_true(
			husk_barrel.is_detonated,
			"Dislodged flying CrateObstacle (> 2.6 m/s) detonates ExplosiveBarrel on real 3D contact"
		)
		assert_approx(husk_barrel.mass, 0.45, 0.01, "Detonated barrel on slope switches to 0.45kg")
		assert_eq(str(husk_barrel.get_meta("weight_label", "")), "EMPTY", "Detonated barrel on slope switches label to EMPTY")

	# Also verify real PlayerBall3D contact detonates a second ExplosiveBarrel
	var ball_contact_barrel = factory_script.create_explosive_barrel(Vector3(-2.5, 0.65, -26.0))
	sloped_root.add_child(ball_contact_barrel)
	await scene_tree.physics_frame
	slope_ball.global_position = sloped_root.to_global(Vector3(-2.5, 0.55, -24.2))
	slope_ball.linear_velocity = -sloped_root.global_transform.basis.z.normalized() * 14.0
	slope_ball._saved_velocity_pre_step = slope_ball.linear_velocity

	for _f in range(72):
		await scene_tree.physics_frame

	assert_true(is_instance_valid(ball_contact_barrel), "Ball-detonated ExplosiveBarrel husk persists after 72 frames")
	if is_instance_valid(ball_contact_barrel):
		assert_true(ball_contact_barrel.is_detonated, "Real PlayerBall3D contact detonates ExplosiveBarrel")
		var reexplode_count := {"n": 0}
		ball_contact_barrel.barrel_exploded.connect(
			func(_o: Vector3, _r: float, _f: float, _d: int) -> void:
				reexplode_count["n"] = int(reexplode_count["n"]) + 1
		)
		ball_contact_barrel.linear_velocity = Vector3.ZERO
		var husk_local_pos: Vector3 = ball_contact_barrel.position
		slope_ball.global_position = sloped_root.to_global(husk_local_pos + Vector3(0.0, 0.0, 1.45))
		slope_ball.linear_velocity = -sloped_root.global_transform.basis.z.normalized() * 11.0
		for _f in range(8):
			await scene_tree.physics_frame
		assert_eq(int(reexplode_count["n"]), 0, "0.45kg EMPTY barrel husk never re-detonates on subsequent ball contact")
		assert_lt(slope_ball.linear_velocity.length(), 18.0, "0.45kg EMPTY barrel husk does not grant a second explosion boost")

	# Also verify real Jolt 3D contact with PinballBumper triggers radial kick + bumper bounce synergy
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	if catalog_script != null:
		var catalog = catalog_script.new()
		slope_ball.synergy_bus.apply_upgrade(catalog.get_upgrade("momentum_overload"))
		slope_ball.synergy_bus.reset_level_transient()
		var live_bumper = factory_script.create_pinball_bumper(Vector3(2.8, 0.65, -36.0))
		sloped_root.add_child(live_bumper)
		await scene_tree.physics_frame
		slope_ball.global_position = sloped_root.to_global(Vector3(1.15, 0.55, -36.0))
		slope_ball.linear_velocity = sloped_root.global_transform.basis.x.normalized() * 9.0 - sloped_root.global_transform.basis.z.normalized() * 6.0
		for _f in range(8):
			await scene_tree.physics_frame
		assert_eq(slope_ball.synergy_bus.combo_stacks, 1, "Real Jolt contact with PinballBumper triggers on_wall_or_bumper_bounce")
		assert_gt(
			(-sloped_root.global_transform.basis.z.normalized()).dot(slope_ball.linear_velocity),
			15.0,
			"Real Jolt contact with PinballBumper grants forward -Z bumper boost"
		)
	assert_true(is_instance_valid(drop_balloon), "Untethered soft_balloon persists after 90 physics frames")
	assert_true(is_instance_valid(drop_iron), "Untethered 12kg mag_iron persists on sloped floor after 90 physics frames")
	if is_instance_valid(drop_iron):
		assert_gt(drop_iron.position.y, 0.30, "12kg mag_iron collides with sloped floor without falling through")
		assert_lt(drop_iron.position.y, 1.35, "12kg mag_iron rests/slides on sloped floor surface")
	assert_true(is_instance_valid(husk_barrel), "0.45kg EMPTY ExplosiveBarrel husk persists after 90 physics frames")
	if is_instance_valid(husk_barrel):
		assert_true(husk_barrel.visible, "0.45kg EMPTY barrel husk stays visible after 90 physics frames")
		assert_eq(husk_barrel.collision_layer, 1, "0.45kg EMPTY barrel husk keeps collision_layer == 1")
		assert_eq(husk_barrel.collision_mask, 1, "0.45kg EMPTY barrel husk keeps collision_mask == 1")
		assert_gt(husk_barrel.position.y, 0.25, "0.45kg EMPTY barrel husk collides with sloped floor across 90 frames")

	root.queue_free()
	await scene_tree.process_frame


func _test_wind_zone_3d_vectors_synergy_and_indiscriminate_rigidbodies() -> void:
	var factory_script: GDScript = load("res://src/track/entities/track_entity_factory.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var mat_script: GDScript = load("res://src/core/material_library.gd")
	if factory_script == null or catalog_script == null or mat_script == null:
		return

	assert_true(
		_script_has_method(factory_script, "create_wind_zone"),
		"TrackEntityFactory exposes create_wind_zone(pos, zone_size, preset, force_newtons)"
	)
	if not _script_has_method(factory_script, "create_wind_zone"):
		return

	var default_slime = factory_script.create_bouncer_slime(Vector3.ZERO)
	assert_approx(default_slime.patrol_half_width, 3.5, 0.01, "create_bouncer_slime defaults patrol_half_w to 3.5m")
	default_slime.free()

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var space_rid := root.get_world_3d().space
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.DOWN)
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, 22.0)

	_add_flat_floor(root, -20.0, 70.0)
	var catalog = catalog_script.new()
	var sail_def = catalog.get_upgrade("tailwind_sail")
	assert_true(
		sail_def != null and sail_def.description.contains("顺风/上升风场"),
		"tailwind_sail description documents tailwind/updraft wind zone synergy"
	)

	# 1. Crosswind (+X) pushes PlayerBall3D laterally along +X, checks bounds & _visual_phase advancement
	var cross_wind = factory_script.create_wind_zone(Vector3(0.0, 2.0, -8.0), Vector3(12.0, 4.0, 12.0), "cross_right", 28.0)
	root.add_child(cross_wind)
	assert_true(cross_wind.is_in_group("wind_zone"), "WindZone joins group 'wind_zone'")
	assert_eq(cross_wind.collision_layer, 0, "WindZone collision_layer is 0")
	assert_eq(cross_wind.collision_mask, 1, "WindZone collision_mask is 1")
	assert_true(cross_wind.contains_local_point(Vector3(0.0, 2.0, -8.0)), "contains_local_point is true inside WindZone")
	assert_true(cross_wind.contains_local_point(Vector3(6.2, 2.0, -8.0), 0.25), "contains_local_point includes margin")
	assert_false(cross_wind.contains_local_point(Vector3(6.5, 2.0, -8.0), 0.25), "contains_local_point is false outside margin")

	var ball_cross = _create_ball_in(root)
	ball_cross.global_position = Vector3(0.0, 0.55, -8.0)
	ball_cross.linear_velocity = Vector3.ZERO

	for _f in range(18):
		await scene_tree.physics_frame
	assert_gt(ball_cross.linear_velocity.x, 2.5, "cross_right WindZone accelerates PlayerBall3D along +X")
	assert_gt(float(cross_wind.get("_visual_phase")), 0.0, "WindZone advances _visual_phase deterministically in headless mode")
	ball_cross.queue_free()
	cross_wind.queue_free()
	await scene_tree.physics_frame

	# 2a. Updraft (+Y/-Z) lifts 1.5kg PlayerBall3D into upper air, and Tailwind Sail amplifies tailwind/updraft!
	var updraft_base = factory_script.create_wind_zone(Vector3(-4.0, 3.5, -18.0), Vector3(5.0, 7.0, 12.0), "updraft", 46.0)
	var updraft_sail = factory_script.create_wind_zone(Vector3(4.0, 3.5, -18.0), Vector3(5.0, 7.0, 12.0), "updraft", 46.0)
	root.add_child(updraft_base)
	root.add_child(updraft_sail)

	var ball_base = _create_ball_in(root)
	ball_base.global_position = Vector3(-4.0, 0.55, -15.0)
	ball_base.linear_velocity = Vector3(0.0, 0.0, -4.0)

	var ball_sail = _create_ball_in(root)
	ball_sail.synergy_bus.apply_upgrade(catalog.get_upgrade("tailwind_sail"))
	ball_sail.sync_from_stats()
	ball_sail.global_position = Vector3(4.0, 0.55, -15.0)
	ball_sail.linear_velocity = Vector3(0.0, 0.0, -4.0)

	for _f in range(28):
		await scene_tree.physics_frame

	assert_gt(ball_base.global_position.y, 2.6, "Updraft WindZone physically lifts 1.5kg PlayerBall3D off the ground")
	assert_gt(
		ball_sail.global_position.y,
		ball_base.global_position.y + 0.8,
		"Tailwind Sail (external_boost_mult) significantly amplifies updraft lift height"
	)
	assert_lt(
		ball_sail.linear_velocity.z,
		ball_base.linear_velocity.z - 1.2,
		"Tailwind Sail amplifies favorable forward -Z component of WindZone"
	)

	ball_base.queue_free()
	ball_sail.queue_free()
	updraft_base.queue_free()
	updraft_sail.queue_free()
	await scene_tree.physics_frame

	# 2b. Pure tailwind (-Z) preset + Tailwind Sail synergy
	var tw_base = factory_script.create_wind_zone(Vector3(-4.0, 2.0, -18.0), Vector3(5.0, 4.0, 16.0), "tailwind", 28.0)
	var tw_sail = factory_script.create_wind_zone(Vector3(4.0, 2.0, -18.0), Vector3(5.0, 4.0, 16.0), "tailwind", 28.0)
	root.add_child(tw_base)
	root.add_child(tw_sail)

	var ball_tw_base = _create_ball_in(root)
	ball_tw_base.global_position = Vector3(-4.0, 0.55, -12.0)
	ball_tw_base.linear_velocity = Vector3.ZERO

	var ball_tw_sail = _create_ball_in(root)
	ball_tw_sail.synergy_bus.apply_upgrade(catalog.get_upgrade("tailwind_sail"))
	ball_tw_sail.sync_from_stats()
	ball_tw_sail.global_position = Vector3(4.0, 0.55, -12.0)
	ball_tw_sail.linear_velocity = Vector3.ZERO

	for _f in range(20):
		await scene_tree.physics_frame

	assert_lt(ball_tw_base.linear_velocity.z, -3.5, "tailwind WindZone accelerates PlayerBall3D along -Z")
	assert_lt(
		ball_tw_sail.linear_velocity.z,
		ball_tw_base.linear_velocity.z - 2.2,
		"Tailwind Sail strongly amplifies pure tailwind (-Z) WindZone acceleration"
	)

	ball_tw_base.queue_free()
	ball_tw_sail.queue_free()
	tw_base.queue_free()
	tw_sail.queue_free()
	await scene_tree.physics_frame

	# 3. Indiscriminate rigidbody wind physics: blows 500g crate, topples 800g pin, untethers & blows 250g balloon,
	#    rolls 0.45kg EMPTY barrel husk, while 12kg mag_iron & 20kg ShieldBrute stand rock-solid!
	var gale_zone = factory_script.create_wind_zone(Vector3(0.0, 2.5, -34.0), Vector3(14.0, 5.5, 14.0), "cross_right", 28.0)
	var wind_crate = factory_script.create_crate(Vector3(-3.0, 0.48, -31.0), "light")
	var wind_pin = factory_script.create_wooden_pin(Vector3(-3.0, 0.78, -34.0))
	var wind_balloon = factory_script.create_aerial_blocker(Vector3(-3.0, 3.0, -36.5), "soft_balloon", 0.0)
	var wind_iron = factory_script.create_aerial_blocker(Vector3(2.0, 3.2, -36.5), "mag_iron", 0.0)
	var wind_brute = factory_script.create_shield_brute(Vector3(2.0, 0.70, -32.0))
	var wind_husk = factory_script.create_explosive_barrel(Vector3(-3.0, 0.65, -39.0))
	root.add_child(gale_zone)
	root.add_child(wind_crate)
	root.add_child(wind_pin)
	root.add_child(wind_balloon)
	root.add_child(wind_iron)
	root.add_child(wind_brute)
	root.add_child(wind_husk)
	var empty_entities: Array[Node3D] = []
	wind_husk.detonate(null, empty_entities, 0)
	wind_husk.position = Vector3(-3.0, 0.65, -39.0)
	wind_husk.linear_velocity = Vector3.ZERO
	wind_husk.angular_velocity = Vector3.ZERO

	var min_pin_up := 1.0
	for _f in range(36):
		await scene_tree.physics_frame
		min_pin_up = minf(min_pin_up, wind_pin.transform.basis.y.normalized().dot(Vector3.UP))

	assert_lt(gale_zone.wind_tint.a, 0.50, "WindZone uses softened storybook translucent alpha (< 0.50)")
	assert_false(bool(wind_crate.get_meta("has_clay_eyes", false)), "Wooden crate remains pure craft prop without eyes")
	assert_false(bool(wind_pin.get_meta("has_clay_eyes", false)), "WoodenPin remains pure craft prop without eyes")
	assert_false(bool(wind_husk.get_meta("has_clay_eyes", false)), "ExplosiveBarrel remains pure craft prop without eyes")
	assert_gt(wind_crate.position.x - (-3.0), 0.8, "WindZone blows 500g light crate substantially along +X")
	assert_lt(min_pin_up, 0.78, "WindZone topples 800g WoodenPin via aerodynamic torque (up_dot < 0.78)")
	assert_gt(wind_pin.position.x - (-3.0), 0.4, "WindZone pushes toppled 800g WoodenPin along +X")
	assert_false(bool(wind_balloon.get("is_tethered")), "Strong WindZone untethers 250g soft_balloon")
	assert_gt(wind_balloon.position.x - (-3.0), 1.5, "WindZone blows 250g soft_balloon briskly along +X")
	assert_gt(wind_husk.position.x - (-3.0), 0.8, "WindZone blows/rolls 0.45kg EMPTY barrel husk along +X")
	assert_true(bool(wind_iron.get("is_tethered")), "12kg mag_iron magnetic lock resists wind untethering")
	assert_lt(absf(wind_brute.position.x - 2.0), 0.08, "20kg ShieldBrute stands rock-solid in WindZone via pure Newtonian static friction")

	gale_zone.queue_free()
	wind_crate.queue_free()
	wind_pin.queue_free()
	wind_balloon.queue_free()
	wind_iron.queue_free()
	wind_brute.queue_free()
	wind_husk.queue_free()
	await scene_tree.physics_frame

	# 4. 60m player-proximity obstacle wind activation: holds obstacle wind at 100m (> 60m), activates within 60m
	var prox_zone = factory_script.create_wind_zone(Vector3(0.0, 2.0, -45.0), Vector3(10.0, 4.0, 10.0), "cross_right", 28.0)
	var prox_crate = factory_script.create_crate(Vector3(0.0, 0.48, -45.0), "light")
	var prox_ball = _create_ball_in(root)
	prox_ball.freeze = true
	prox_ball.global_position = Vector3(0.0, 1.0, 55.0) # 100m away from prox_zone at z = -45.0
	root.add_child(prox_zone)
	root.add_child(prox_crate)
	assert_true(prox_ball.is_in_group("player_ball"), "PlayerBall3D joins group 'player_ball' in _ready()")

	for _f in range(20):
		await scene_tree.physics_frame
	assert_lt(
		absf(prox_crate.position.x),
		0.05,
		"WindZone holds obstacle wind when PlayerBall3D is 100m away (> 60m)"
	)

	prox_ball.global_position = Vector3(0.0, 1.0, -10.0) # 35m away (<= 60m)
	for _f in range(24):
		await scene_tree.physics_frame
	assert_gt(
		prox_crate.position.x,
		0.6,
		"WindZone activates obstacle wind once PlayerBall3D moves within 60m"
	)

	root.queue_free()
	await scene_tree.process_frame

