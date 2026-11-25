extends TestBase


func run() -> void:
	_test_stat_sheet_defaults_and_clamping()
	_test_stat_sheet_dual_multiplier_synergy()
	_test_run_state_length_progression_and_timer()


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
