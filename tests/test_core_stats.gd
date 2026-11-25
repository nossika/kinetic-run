extends TestBase


func run() -> void:
	_test_stat_sheet_defaults_and_clamping()
	_test_stat_sheet_dual_multiplier_synergy()
	_test_run_state_length_progression_and_timer()
	_test_deterministic_seed_parsing_and_subseeds()
	_test_material_library_metadata_and_friction()


func _test_stat_sheet_defaults_and_clamping() -> void:
	var stat_script: GDScript = load("res://src/core/stat_sheet.gd")
	assert_true(stat_script != null, "StatSheet script must exist")
	if stat_script == null:
		return

	var stats = stat_script.new()
	assert_approx(stats.get_stat("mass"), 1.5, 0.001, "Default mass is 1.5 kg")
	assert_approx(stats.get_stat("radius"), 0.55, 0.001, "Default radius is 0.55 m")
	assert_approx(stats.get_stat("bounce"), 0.25, 0.001, "Default bounce is 0.25")
	assert_approx(stats.get_stat("linear_damp"), 0.35, 0.001, "Default linear_damp is 0.35")
	assert_approx(stats.get_stat("max_tilt_deg"), 35.0, 0.001, "Default max_tilt_deg is 35.0")
	assert_approx(stats.get_stat("shockwave_radius_mult"), 1.0, 0.001, "Default shockwave radius mult is 1.0")

	stats.add_flat("bounce", 5.0)
	assert_approx(stats.get_stat("bounce"), 1.0, 0.001, "Bounce clamps at max 1.0")

	stats.add_flat("max_tilt_deg", 40.0)
	assert_approx(stats.get_stat("max_tilt_deg"), 55.0, 0.001, "Max tilt clamps at 55.0 deg")

	stats.add_mult("linear_damp", -0.999)
	assert_approx(stats.get_stat("linear_damp"), 0.02, 0.001, "Linear damp clamps at min 0.02")


func _test_stat_sheet_dual_multiplier_synergy() -> void:
	var stat_script: GDScript = load("res://src/core/stat_sheet.gd")
	if stat_script == null:
		return

	var stats = stat_script.new()
	# (1.5 + 0.8) * (1 + 0.65) * (1 + 0.20) = 2.3 * 1.65 * 1.2 = 4.554
	stats.add_flat("mass", 0.8)
	stats.add_mult("mass", 0.65)
	stats.add_mult("mass", 0.20)
	assert_approx(stats.get_stat("mass"), 4.554, 0.001, "Flat + multiplicative modifiers compound accurately")

	# Radius scaling automatically scales shockwave_radius_mult by sqrt(radius / 0.55)
	stats.add_mult("radius", 0.96) # 0.55 * 1.96 = 1.078 -> sqrt(1.96) = 1.4
	assert_approx(stats.get_stat("shockwave_radius_mult"), 1.4, 0.005, "Shockwave radius scales with sqrt(radius / base_radius)")

	stats.set_flag("immune_slime_damp", true)
	assert_true(stats.has_flag("immune_slime_damp"), "Flag immune_slime_damp enabled")

	stats.reset_modifiers()
	assert_approx(stats.get_stat("mass"), 1.5, 0.001, "reset_modifiers restores base mass")
	assert_false(stats.has_flag("immune_slime_damp"), "reset_modifiers clears flags")


func _test_run_state_length_progression_and_timer() -> void:
	var run_script: GDScript = load("res://src/core/run_state.gd")
	assert_true(run_script != null, "RunState script must exist")
	if run_script == null:
		return

	assert_approx(run_script.target_length_for_level(1), 130.0, 0.01, "Level 1 length is 130m")
	assert_approx(run_script.target_length_for_level(5), 375.0, 0.01, "Level 5 length is 375m")
	assert_approx(run_script.target_length_for_level(10), 700.0, 0.01, "Level 10 length is 700m")

	for lvl in range(1, 12):
		assert_gt(
			run_script.target_length_for_level(lvl + 1),
			run_script.target_length_for_level(lvl),
			"Track length strictly increases from level %d to %d" % [lvl, lvl + 1]
		)

	var state = run_script.new()
	state.start_new_run()
	assert_eq(state.current_level, 1, "New run starts at level 1")
	assert_approx(state.time_remaining, 30.0, 0.001, "Level starts with 30.0s")

	state.add_bonus_time(20.0)
	assert_approx(state.time_remaining, 45.0, 0.001, "Bonus time caps at 45.0s")

	var expired: bool = state.tick_timer(10.0)
	assert_false(expired, "Timer not expired with 35s left")
	expired = state.tick_timer(36.0)
	assert_true(expired, "Timer expires when reaching 0")
	assert_approx(state.time_remaining, 0.0, 0.001, "Timer clamps at 0.0")

	state.record_physics_sample(20.0, 600.0)
	assert_approx(state.peak_speed_kmh, 72.0, 0.01, "20 m/s recorded as 72 km/h")
	assert_approx(state.max_kinetic_energy, 600.0, 0.01, "Max kinetic energy recorded")


func _test_deterministic_seed_parsing_and_subseeds() -> void:
	var run_script: GDScript = load("res://src/core/run_state.gd")
	var state_a = run_script.new()
	var state_b = run_script.new()

	state_a.start_new_run_from_text("884866")
	state_b.start_new_run_from_text("  884866 ")
	assert_eq(state_a.run_seed, 884866, "Numeric seed string parses to exact integer")
	assert_eq(state_a.run_seed, state_b.run_seed, "Trimmed numeric seeds match")
	assert_eq(state_a.seed_text, "884866", "seed_text normalized")

	state_a.start_new_run_from_text("给我滚FLY")
	state_b.start_new_run_from_text("给我滚FLY")
	assert_gt(float(state_a.run_seed), 0.0, "Custom string seed hashes to positive int")
	assert_eq(state_a.run_seed, state_b.run_seed, "Identical string seed hashes deterministically")
	assert_eq(state_a.seed_text, "给我滚FLY", "Custom text preserved in seed_text")

	var t1_a: int = run_script.derive_track_seed(state_a.run_seed, 1)
	var t1_b: int = run_script.derive_track_seed(state_b.run_seed, 1)
	var t2_a: int = run_script.derive_track_seed(state_a.run_seed, 2)
	var d1_a: int = run_script.derive_draft_seed(state_a.run_seed, 1)
	var d1_b: int = run_script.derive_draft_seed(state_b.run_seed, 1)
	var d2_a: int = run_script.derive_draft_seed(state_a.run_seed, 2)
	assert_eq(t1_a, t1_b, "Same run_seed and level produce identical track sub-seed")
	assert_true(t1_a != t2_a, "Different levels produce distinct track sub-seeds")
	assert_true(t1_a != d1_a, "Track seed and draft seed streams are isolated")
	assert_eq(d1_a, d1_b, "Same run_seed and cleared_level produce identical draft sub-seed")
	assert_true(d1_a != d2_a, "Different cleared levels produce distinct draft sub-seeds")

	# Edge cases: empty/whitespace, zero, negative integers, huge integer strings
	state_a.start_new_run_from_text("   ")
	assert_true(state_a.run_seed >= 100000 and state_a.run_seed <= 999999, "Empty text generates 6-digit readable seed")
	assert_eq(state_a.seed_text, str(state_a.run_seed), "Auto seed sets matching seed_text")

	state_a.start_new_run_from_text("0")
	assert_eq(state_a.run_seed, 1, "Zero seed string clamps to positive 1")
	assert_eq(state_a.seed_text, "0", "Zero seed preserves trimmed text")

	state_a.start_new_run_from_text(" -884866 ")
	assert_eq(state_a.run_seed, 884866, "Negative integer seed folds to positive int")
	assert_eq(state_a.seed_text, "-884866", "Negative integer preserves trimmed text")

	state_a.start_new_run_from_text("999999999999999999999999999991")
	state_b.start_new_run_from_text("999999999999999999999999999992")
	assert_gt(float(state_a.run_seed), 0.0, "Huge numeric string hashes safely to positive int")
	assert_true(state_a.run_seed != state_b.run_seed, "Distinct huge numeric strings do not clamp to identical INT64_MAX")


func _test_material_library_metadata_and_friction() -> void:
	var lib_script: GDScript = load("res://src/core/material_library.gd")
	assert_true(lib_script != null, "MaterialLibrary script must exist")
	if lib_script == null:
		return

	var pmat: PhysicsMaterial = lib_script.high_friction_physics()
	assert_gt(pmat.friction, 0.80, "Tabletop resting physics material has high static friction (> tan 11 deg)")
	assert_approx(pmat.friction, 0.88, 0.001, "Default high_friction_physics friction is 0.88")
	assert_approx(pmat.bounce, 0.12, 0.001, "Default high_friction_physics bounce is 0.12")

	var custom_pmat: PhysicsMaterial = lib_script.high_friction_physics(0.92, 0.05)
	assert_approx(custom_pmat.friction, 0.92, 0.001, "Custom friction parameter respected")
	assert_approx(custom_pmat.bounce, 0.05, 0.001, "Custom bounce parameter respected")

	# Verify all 9 material builders return valid StandardMaterial3D with distinct hard vs soft PBR attributes
	var beech: StandardMaterial3D = lib_script.make_beechwood_material()
	var acrylic: StandardMaterial3D = lib_script.make_frosted_acrylic_material(Color(0.2, 0.8, 0.95))
	var light_crate: StandardMaterial3D = lib_script.make_wood_crate_material(false)
	var heavy_crate: StandardMaterial3D = lib_script.make_wood_crate_material(true)
	var iron: StandardMaterial3D = lib_script.make_cast_iron_material()
	var tungsten: StandardMaterial3D = lib_script.make_tungsten_ball_material()
	var barrel: StandardMaterial3D = lib_script.make_retro_barrel_material()
	var silicone: StandardMaterial3D = lib_script.make_silicone_soft_material(Color(1.0, 0.45, 0.65))
	var jelly_out: StandardMaterial3D = lib_script.make_jelly_outer_material(Color(0.35, 0.95, 0.50))
	var jelly_core: StandardMaterial3D = lib_script.make_jelly_core_material(Color(0.45, 1.0, 0.55))

	assert_true(beech != null and beech.uv1_triplanar, "Beechwood track material enables world/local triplanar tiling")
	assert_true(acrylic != null and acrylic.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Frosted acrylic uses alpha transparency")
	assert_true(light_crate != null and heavy_crate != null, "Both light and heavy wood crate materials created")
	assert_true(light_crate.albedo_color != heavy_crate.albedo_color, "Heavy wood crate has distinct darker reinforced tint")
	assert_gt(iron.metallic, 0.65, "Cast iron is metallic")
	assert_gt(tungsten.metallic, 0.75, "Tungsten ball is highly metallic")
	assert_lt(tungsten.roughness, 0.25, "Tungsten ball is polished")
	assert_true(barrel != null, "Retro barrel material created")
	assert_gt(silicone.roughness, 0.75, "Silicone soft material is matte high-roughness")
	assert_eq(jelly_out.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Jelly outer layer is translucent")
	assert_lt(jelly_out.roughness, 0.20, "Jelly outer layer is glossy")
	assert_true(jelly_core.emission_enabled, "Jelly core glows softly from within")

	var dummy := Node3D.new()
	lib_script.attach_weight_labels(dummy, "20kg", Vector3(1.4, 1.4, 1.4))
	assert_eq(String(dummy.get_meta("weight_label", "")), "20kg", "attach_weight_labels records weight_label metadata")

	var fixed_dummy := Node3D.new()
	lib_script.attach_anchored_flange_base(fixed_dummy, -0.6, 0.8, 0.8, true)
	assert_true(bool(fixed_dummy.get_meta("is_anchored_fixed", false)), "attach_anchored_flange_base marks node anchored")

	for tex_path in [
		lib_script.TEX_TRACK_BEECHWOOD,
		lib_script.TEX_CRATE_BALSA_WOOD,
		lib_script.TEX_METAL_CAST_IRON,
		lib_script.TEX_ANCHOR_HAZARD_STRIPE,
		lib_script.TEX_BARREL_RETRO_HAZARD,
		lib_script.TEX_JELLY_BUBBLE_SOFT,
		lib_script.BUNDLED_FONT_PATH,
	]:
		assert_true(ResourceLoader.exists(tex_path), "Imported asset exists: %s" % tex_path)

	dummy.free()
	fixed_dummy.free()
