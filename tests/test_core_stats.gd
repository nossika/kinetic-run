extends TestBase


func run() -> void:
	_test_stat_sheet_defaults_and_clamping()
	_test_stat_sheet_dual_multiplier_synergy()
	_test_run_state_length_progression_and_timer()
	_test_deterministic_seed_parsing_and_subseeds()
	_test_upgrade_catalog_persistent_impact_copy()
	_test_material_library_metadata_and_friction()
	_test_clay_mesh_builder_shapes_and_caching()


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
	assert_eq(state_b.seed_text, "884866", "Trimmed numeric seed_text normalized")

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


func _test_upgrade_catalog_persistent_impact_copy() -> void:
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	assert_true(catalog_script != null, "UpgradeCatalog script must exist")
	if catalog_script == null:
		return

	var catalog = catalog_script.new()
	assert_eq(
		catalog.get_upgrade("tungsten_core").description,
		"质量 ×1.65，冲撞障碍时的前向减速损耗降低 50%（直接放大动量 P 与碾压优势）。",
		"tungsten_core copy reflects persistent physical impacts"
	)
	assert_eq(
		catalog.get_upgrade("kinetic_furnace").description,
		"强力撞飞路障时按实时动能 √Ek 释放物理爆炸气浪，掀翻周围障碍并顺风推射自身。",
		"kinetic_furnace copy reflects persistent physical impacts"
	)
	assert_eq(
		catalog.get_upgrade("smash_chrono").description,
		"每累计触发 4 次有效破障冲撞，倒计时立即 +1.5 秒并爆发一次前向提速脉冲。",
		"smash_chrono copy reflects persistent physical impacts"
	)
	assert_eq(
		catalog.get_upgrade("momentum_overload").description,
		"【唯一】每次有效撞飞、落地或反弹叠 1 层过载（最高 20 层），每层使所有词条冲量输出 +12%。",
		"momentum_overload copy reflects persistent physical impacts"
	)


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

	var charred: StandardMaterial3D = lib_script.make_charred_husk_material()
	var pin_stripe: StandardMaterial3D = lib_script.make_pin_stripe_material()
	var custom_pin_stripe: StandardMaterial3D = lib_script.make_pin_stripe_material(Color(0.15, 0.55, 0.90))
	assert_true(charred != null, "Charred barrel husk material created")
	assert_gt(charred.roughness, 0.72, "Charred husk is soot-matte high roughness")
	assert_lt(charred.albedo_color.r, 0.35, "Charred husk has dark scorched tint")
	assert_true(pin_stripe != null, "WoodenPin lacquer stripe material created")
	assert_lt(pin_stripe.roughness, 0.35, "WoodenPin stripe has glossy painted finish")
	assert_eq(custom_pin_stripe.albedo_color, Color(0.15, 0.55, 0.90), "WoodenPin stripe respects custom lacquer color")

	var dummy := Node3D.new()
	var old_front := Node3D.new()
	old_front.name = "WeightLabelFront"
	dummy.add_child(old_front)
	lib_script.attach_weight_labels(dummy, "20kg", Vector3(1.4, 1.4, 1.4))
	lib_script.attach_weight_labels(dummy, "25kg", Vector3(1.4, 1.4, 1.4))
	assert_eq(String(dummy.get_meta("weight_label", "")), "25kg", "attach_weight_labels records updated weight_label metadata")
	assert_true(dummy.get_node_or_null("WeightLabelFront") == null, "attach_weight_labels cleans pre-existing WeightLabelFront idempotently")

	var fixed_dummy := Node3D.new()
	var old_flange := Node3D.new()
	old_flange.name = "AnchoredFlangeBase"
	fixed_dummy.add_child(old_flange)
	lib_script.attach_anchored_flange_base(fixed_dummy, -0.6, 0.8, 0.8, true)
	lib_script.attach_anchored_flange_base(fixed_dummy, -0.6, 0.8, 0.8, true)
	assert_true(bool(fixed_dummy.get_meta("is_anchored_fixed", false)), "attach_anchored_flange_base marks node anchored")
	assert_true(fixed_dummy.get_node_or_null("AnchoredFlangeBase") == null, "attach_anchored_flange_base cleans pre-existing AnchoredFlangeBase idempotently")

	for tex_path in [
		lib_script.TEX_TRACK_BEECHWOOD,
		lib_script.TEX_CRATE_BALSA_WOOD,
		lib_script.TEX_METAL_CAST_IRON,
		lib_script.TEX_ANCHOR_HAZARD_STRIPE,
		lib_script.TEX_BARREL_RETRO_HAZARD,
		lib_script.TEX_JELLY_BUBBLE_SOFT,
		lib_script.TEX_STORYBOOK_SKY_CLOUDS,
		lib_script.BUNDLED_FONT_PATH,
	]:
		assert_true(ResourceLoader.exists(tex_path), "Imported asset exists: %s" % tex_path)

	dummy.free()
	fixed_dummy.free()


func _test_clay_mesh_builder_shapes_and_caching() -> void:
	var builder: GDScript = load("res://src/core/clay_mesh_builder.gd")
	assert_true(builder != null, "ClayMeshBuilder script must exist")
	if builder == null:
		return

	if DisplayServer.get_name() == "headless":
		assert_true(builder.make_rounded_box(Vector3.ONE, 0.14, 3, false) == null, "Headless default skips GPU mesh")

	var ref_bm := BoxMesh.new()
	var ref_arr := ref_bm.get_mesh_arrays()
	var rv: PackedVector3Array = ref_arr[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = ref_arr[Mesh.ARRAY_NORMAL]
	var ri: PackedInt32Array = ref_arr[Mesh.ARRAY_INDEX]
	var expected_wind_sign := signf((rv[ri[1]] - rv[ri[0]]).cross(rv[ri[2]] - rv[ri[0]]).dot(rn[ri[0]]))

	var rbox: ArrayMesh = builder.make_rounded_box(Vector3(1.2, 1.0, 2.0), 0.16, 3, true)
	var rbox_cached: ArrayMesh = builder.make_rounded_box(Vector3(1.2, 1.0, 2.0), 0.16, 3, true)
	assert_true(rbox != null and rbox.get_surface_count() == 1, "RoundedBox builds 1-surface ArrayMesh")
	assert_eq(rbox, rbox_cached, "RoundedBox reuses cached ArrayMesh instance for identical dimensions")

	var rb_arr := rbox.surface_get_arrays(0)
	var verts: PackedVector3Array = rb_arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = rb_arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = rb_arr[Mesh.ARRAY_TEX_UV]
	var idxs: PackedInt32Array = rb_arr[Mesh.ARRAY_INDEX]
	assert_gt(verts.size(), 60.0, "RoundedBox has subdivided bevel vertices")
	assert_eq(verts.size(), norms.size(), "RoundedBox normal count matches vertex count")
	assert_eq(verts.size(), uvs.size(), "RoundedBox UV count matches vertex count")

	var aabb := rbox.get_aabb()
	assert_approx(aabb.size.x, 1.2, 0.02, "RoundedBox AABB width matches requested X")
	assert_approx(aabb.size.y, 1.0, 0.02, "RoundedBox AABB height matches requested Y")
	assert_approx(aabb.size.z, 2.0, 0.02, "RoundedBox AABB depth matches requested Z")

	var tri_wind_sign := signf((verts[idxs[1]] - verts[idxs[0]]).cross(verts[idxs[2]] - verts[idxs[0]]).dot(norms[idxs[0]]))
	assert_eq(tri_wind_sign, expected_wind_sign, "RoundedBox triangle winding matches Godot BoxMesh front-face convention")

	var ccyl: ArrayMesh = builder.make_chamfered_cylinder(0.5, 0.5, 1.2, 0.10, 24, true)
	assert_true(ccyl != null and ccyl.get_surface_count() == 1, "ChamferedCylinder builds valid ArrayMesh")
	assert_approx(ccyl.get_aabb().size.y, 1.2, 0.02, "ChamferedCylinder height matches 1.2m")

	var pebble: ArrayMesh = builder.make_pebble_pad(Vector2(4.0, 6.0), 0.12, 20, true)
	assert_true(pebble != null and pebble.get_surface_count() == 1, "PebblePad builds valid ArrayMesh")
	assert_approx(pebble.get_aabb().size.x, 4.0, 0.05, "PebblePad X span matches 4.0m")
	assert_approx(pebble.get_aabb().size.z, 6.0, 0.05, "PebblePad Z span matches 6.0m")

	var host := Node3D.new()
	var eyes_root: Node3D = builder.attach_clay_eyes(host, Vector3(0.0, 0.2, 0.5), 0.24, 0.065, true, true)
	assert_true(eyes_root != null and host.get_node_or_null("ClayEyes") != null, "attach_clay_eyes mounts ClayEyes child node")
	assert_true(eyes_root.get_child_count() >= 4, "ClayEyes includes left/right pupils, highlights, and blush")
	host.free()

