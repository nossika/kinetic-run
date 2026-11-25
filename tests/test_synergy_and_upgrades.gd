extends TestBase


func run() -> void:
	_test_catalog_12_upgrades_and_unique_draft()
	_test_emergent_frog_slam_synergy()
	_test_emergent_wall_drift_and_overload_decay()
	_test_kinetic_furnace_twin_resonance_and_guardrails()


func _test_catalog_12_upgrades_and_unique_draft() -> void:
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	assert_true(catalog_script != null, "UpgradeCatalog script must exist")
	if catalog_script == null:
		return

	var catalog = catalog_script.new()
	var all_defs: Array = catalog.get_all_upgrades()
	assert_eq(all_defs.size(), 12, "Catalog registers all 12 initial atomic upgrades")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var owned: Array[String] = ["vector_refractor"]
	for _i in range(15):
		var picks: Array = catalog.roll_draft_choices(rng, 3, owned)
		assert_eq(picks.size(), 3, "Draft returns 3 choices")
		assert_true(picks[0].id != picks[1].id and picks[1].id != picks[2].id and picks[0].id != picks[2].id, "Draft choices are distinct")
		for p in picks:
			assert_true(p.id != "vector_refractor", "Non-stackable legendary already owned is excluded from draft")


func _test_emergent_frog_slam_synergy() -> void:
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var ctx_script: GDScript = load("res://src/core/physics_event_context.gd")
	assert_true(bus_script != null and ctx_script != null, "PhysicsSynergyBus and PhysicsEventContext must exist")
	if catalog_script == null or bus_script == null or ctx_script == null:
		return

	var catalog = catalog_script.new()

	# Baseline: Quake Refractor alone
	var bus_solo = bus_script.new()
	bus_solo.apply_upgrade(catalog.get_upgrade("quake_refractor"))
	var ctx_solo = ctx_script.create(
		12.0, 0.0, 0.0, bus_solo.stats.get_stat("mass"), 10.0, Vector3.UP, Vector3.ZERO, 0, 0
	)
	var res_solo: Dictionary = bus_solo.on_land(ctx_solo)

	# Combo: Tungsten Core (+65% mass) + Giant Field (+0.8 flat mass, +35% radius) + Quake Refractor
	var bus_combo = bus_script.new()
	bus_combo.apply_upgrade(catalog.get_upgrade("tungsten_core"))
	bus_combo.apply_upgrade(catalog.get_upgrade("giant_field"))
	bus_combo.apply_upgrade(catalog.get_upgrade("quake_refractor"))
	var ctx_combo = ctx_script.create(
		12.0, 0.0, 0.0, bus_combo.stats.get_stat("mass"), 10.0, Vector3.UP, Vector3.ZERO, 0, 0
	)
	var res_combo: Dictionary = bus_combo.on_land(ctx_combo)

	assert_gt(
		float(res_combo["forward_impulse"]),
		float(res_solo["forward_impulse"]) * 2.2,
		"Mass flat + mass mult + Quake Refractor produces >2.2x landing forward impulse (1+1>2)"
	)
	var waves_solo: Array = res_solo["shockwaves"]
	var waves_combo: Array = res_combo["shockwaves"]
	assert_eq(waves_combo.size(), 1, "Quake Refractor emits 1 landing shockwave")
	assert_gt(
		float(waves_combo[0]["radius"]),
		float(waves_solo[0]["radius"]) * 1.12,
		"Giant Field radius automatically scales shockwave radius"
	)


func _test_emergent_wall_drift_and_overload_decay() -> void:
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var ctx_script: GDScript = load("res://src/core/physics_event_context.gd")
	if catalog_script == null or bus_script == null or ctx_script == null:
		return

	var catalog = catalog_script.new()
	var bus = bus_script.new()
	bus.apply_upgrade(catalog.get_upgrade("vector_refractor"))
	bus.apply_upgrade(catalog.get_upgrade("momentum_overload"))

	var mass: float = bus.stats.get_stat("mass")
	var first_hit_ctx = ctx_script.create(16.0, 9.0, 30.0, mass, 0.0, Vector3.RIGHT, Vector3.ZERO, bus.combo_stacks, 0)
	var first_res: Dictionary = bus.on_wall_or_bumper_bounce(first_hit_ctx)
	assert_eq(bus.combo_stacks, 1, "First wall bounce builds 1 Overload stack")

	# Stack up to 20
	for _i in range(25):
		var c = ctx_script.create(16.0, 9.0, 30.0, mass, 0.0, Vector3.RIGHT, Vector3.ZERO, bus.combo_stacks, 0)
		bus.on_wall_or_bumper_bounce(c)

	assert_eq(bus.combo_stacks, 20, "Overload stacks cap at 20")
	var max_ctx = ctx_script.create(16.0, 9.0, 30.0, mass, 0.0, Vector3.RIGHT, Vector3.ZERO, bus.combo_stacks, 0)
	var max_res: Dictionary = bus.on_wall_or_bumper_bounce(max_ctx)
	assert_gt(
		float(max_res["forward_impulse"]),
		float(first_res["forward_impulse"]) * 2.8,
		"20 Overload stacks amplify Vector Refractor wall-bounce impulse by >2.8x"
	)

	# Decay after 2.5s idle
	var idle_ctx = ctx_script.create(10.0, 0.0, 0.0, mass, 0.0, Vector3.UP, Vector3.ZERO, bus.combo_stacks, 0)
	bus.on_physics_tick(idle_ctx, 2.0)
	assert_eq(bus.combo_stacks, 20, "Overload does not decay before 2.5s")
	bus.on_physics_tick(idle_ctx, 1.2)
	assert_lt(float(bus.combo_stacks), 20.0, "Overload decays after >2.5s without triggers")

	var bus_thrust = bus_script.new()
	bus_thrust.apply_upgrade(catalog.get_upgrade("tail_thruster"))
	assert_gt(bus_thrust.stats.get_stat("tilt_lateral_force_mult"), 1.30, "Tail thruster boosts lateral force mult")
	var active_thrust_ctx = ctx_script.create(14.0, 6.0, 1.0, 1.5, 0.0, Vector3.UP, Vector3.ZERO, 0, 0)
	var left_thrust_ctx = ctx_script.create(14.0, -6.0, -1.0, 1.5, 0.0, Vector3.UP, Vector3.ZERO, 0, 0)
	var idle_thrust_ctx = ctx_script.create(14.0, 6.0, 0.0, 1.5, 0.0, Vector3.UP, Vector3.ZERO, 0, 0)
	assert_gt(float(bus_thrust.on_physics_tick(active_thrust_ctx, 0.1)["forward_impulse"]), 0.1, "Holding lateral thrust converts lateral speed to forward impulse")
	assert_gt(float(bus_thrust.on_physics_tick(left_thrust_ctx, 0.1)["forward_impulse"]), 0.1, "Holding left lateral thrust also converts lateral speed to forward impulse")
	assert_approx(float(bus_thrust.on_physics_tick(idle_thrust_ctx, 0.1)["forward_impulse"]), 0.0, 0.001, "Releasing lateral thrust stops tail thruster conversion")


func _test_kinetic_furnace_twin_resonance_and_guardrails() -> void:
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var ctx_script: GDScript = load("res://src/core/physics_event_context.gd")
	if catalog_script == null or bus_script == null or ctx_script == null:
		return

	var catalog = catalog_script.new()
	var bus = bus_script.new()
	bus.apply_upgrade(catalog.get_upgrade("kinetic_furnace"))
	bus.apply_upgrade(catalog.get_upgrade("smash_chrono"))

	var mass: float = bus.stats.get_stat("mass")
	var ctx_slow = ctx_script.create(8.0, 0.0, 0.0, mass, 0.0, Vector3.BACK, Vector3.ZERO, 0, 0)
	var ctx_fast = ctx_script.create(28.0, 0.0, 0.0, mass, 0.0, Vector3.BACK, Vector3.ZERO, 0, 0)
	var res_slow: Dictionary = bus.on_smash_target(ctx_slow)
	var res_fast: Dictionary = bus.on_smash_target(ctx_fast)

	assert_gt(
		float(res_fast["shockwaves"][0]["force"]),
		float(res_slow["shockwaves"][0]["force"]) * 2.0,
		"Kinetic Furnace shockwave force scales strongly with kinetic energy (speed^2)"
	)

	# Add Twin Resonance -> converter triggers double, so 1 smash counts twice toward Smash Chrono (2 + 2 = 4 -> +1.5s!)
	bus.apply_upgrade(catalog.get_upgrade("twin_resonance"))
	var res_twin: Dictionary = bus.on_smash_target(ctx_fast)
	assert_eq((res_twin["shockwaves"] as Array).size(), 2, "Twin Resonance triggers Kinetic Furnace twice")
	assert_approx(float(res_twin["bonus_time"]), 1.5, 0.001, "4th cumulative smash trigger grants +1.5s bonus time")

	# Guardrail 1: chain_depth >= 3 stops emitting new shockwaves
	var deep_ctx = ctx_script.create(28.0, 0.0, 0.0, mass, 0.0, Vector3.BACK, Vector3.ZERO, 0, 3)
	var deep_res: Dictionary = bus.on_smash_target(deep_ctx)
	assert_eq((deep_res["shockwaves"] as Array).size(), 0, "chain_depth >= 3 prevents infinite shockwave recursion")

	# Guardrail 2: extreme speed impulse delta capped at 45.0 * mass
	var extreme_ctx = ctx_script.create(500.0, 0.0, 0.0, mass, 500.0, Vector3.BACK, Vector3.ZERO, 20, 0)
	var extreme_res: Dictionary = bus.on_smash_target(extreme_ctx)
	assert_approx(
		float(extreme_res["forward_impulse"]),
		45.0 * mass,
		0.01,
		"Single-dispatch forward impulse is safely capped at 45.0 * mass"
	)
