# Wide Track (+25%), Upper-Air Sky Platforms, and 3D Wind Zones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Widen all track geometry and lateral layouts by +25%, populate the upper-air altitude band (`Y = 4.4m ~ 6.8m`) with low-density translucent frosted-acrylic sky platforms and falling-debris obstacles, and add visually clear regional 3D wind zones on both ground and air that apply indiscriminate aerodynamic forces to all rigidbodies while synergizing with `tailwind_sail`.

**Architecture:** `TrackChunkBase` scales its deck/rail/ramp dimensions by `1.25×` (`STANDARD_WIDTH = 12.5m`), adds `add_sky_platform()` for elevated translucent decks, and pairs with widened `ChaseCamera3D` framing (`FOLLOW_OFFSET = Vector3(0.0, 5.6, 8.8)`). `PlayerBall3D` adds contact-normal surface support tracking (`_surface_support_timer`) in `_integrate_forces` so landing on elevated `SkyPlatform` decks triggers `on_land` shockwaves and full ground lateral control. A new `WindZone` (`Area3D`) applies real 3D aerodynamic forces (with terminal wind-speed drag scaling, `WoodenPin` toppling torque, `AerialBlocker` balloon untethering, and `tailwind_sail` amplification) while rendering 12 scrolling translucent wind ribbons and 3D directional chevrons; `TrackGenerator3D` deterministically orchestrates all three layers using seeded `RandomNumberGenerator` rolls.

**Tech Stack:** Godot 4.6 (`gl_compatibility` renderer, Jolt Physics 3D, GDScript), headless test runner `./scripts/test.sh` (`res://tests/run_tests.gd`), Web HTML5 exporter `./scripts/build-web.sh`.

## Global Constraints

- **Headless Safety**: Guard GPU mesh/material/label visuals with `DisplayServer.get_name() == "headless"` (or `RenderHelper.attach_mesh` / `MaterialLibrary`), while always building real `CollisionShape3D` shapes, physics materials, groups, and metadata (`weight_label`, `is_anchored_fixed`) in headless mode.
- **100% Determinism**: Zero unseeded global `randf()` / `randi()` calls anywhere in `src/`. Every random roll must draw from `RandomNumberGenerator` seeded via `RunState.derive_track_seed(run_seed, level)`.
- **Zero-Dizzy Camera & Sloped Physics**: Global gravity remains strictly vertical `Vector3(0.0, -22.0, 0.0)`, `GeneratedTrack` pitches at `TRACK_SLOPE_PITCH_DEG = -11.0`, and `ChaseCamera3D` keeps `ROLL_FACTOR = 0.0` (`rotation_degrees.z == 0.0`).
- **Pure Real Rigidbody Wind**: `WindZone` applies aerodynamic forces indiscriminately to overlapping `RigidBody3D` bodies (`PlayerBall3D`, crates, pins, barrels/husks, slimes, aerial blockers, heavy weights) so mass and friction naturally separate light blown debris from rock-solid `20kg` `ShieldBrute` weights.

---

### Task 1: Track +25% Widening, `SkyPlatform` Builder, and Camera Framing

**Files:**
- Modify: `src/track/track_chunk_base.gd`
- Modify: `src/gameplay/chase_camera_3d.gd`
- Test: `tests/test_track_generator.gd`
- Test: `tests/test_ball_and_gravity.gd`

**Interfaces:**
- Consumes: `MaterialLibrary.make_frosted_acrylic_material(tint)`, `MaterialLibrary.high_friction_physics(friction, bounce)`, `RenderHelper.attach_mesh(inst, mesh)`
- Produces:
  - `TrackChunkBase.STANDARD_WIDTH == 12.5`
  - `TrackChunkBase.add_side_launch_ramp(local_pos: Vector3, width: float = 3.0) -> StaticBody3D`
  - `TrackChunkBase.add_sky_platform(local_pos: Vector3, size: Vector3 = Vector3(3.8, 0.34, 11.5), with_end_kick: bool = false) -> StaticBody3D` (in group `"sky_platform"`, `is_anchored_fixed == true`)
  - `ChaseCamera3D.FOLLOW_OFFSET == Vector3(0.0, 5.6, 8.8)`

- [ ] **Step 1: Write the failing tests for +25% chunk widths, `add_sky_platform`, and camera framing**

In `tests/test_ball_and_gravity.gd`, update `_test_chase_camera_zero_roll_and_dynamic_fov()` (`FOLLOW_OFFSET.y` -> `5.6`, `FOLLOW_OFFSET.z` -> `8.8`):

```gdscript
	assert_approx(cam.ROLL_FACTOR, 0.0, 0.0001, "ChaseCamera3D ROLL_FACTOR is 0.0")
	assert_approx(cam.BASE_PITCH_DEG, -27.0, 0.01, "ChaseCamera3D BASE_PITCH_DEG is -27.0")
	assert_approx(cam.FOLLOW_OFFSET.y, 5.6, 0.01, "ChaseCamera3D FOLLOW_OFFSET.y is 5.6")
	assert_approx(cam.FOLLOW_OFFSET.z, 8.8, 0.01, "ChaseCamera3D FOLLOW_OFFSET.z is 8.8")
```

In `tests/test_track_generator.gd`, add chunk width & `add_sky_platform` assertions inside `_test_wave_hills_side_launch_ramp_and_vertical_entities()` right after the `add_side_launch_ramp` check:

```gdscript
	assert_approx(float(chunk_script.STANDARD_WIDTH), 12.5, 0.01, "TrackChunkBase.STANDARD_WIDTH widened +25% to 12.5m")

	var nb_chunk = chunk_script.new()
	root.add_child(nb_chunk)
	nb_chunk.build_chunk("NarrowBridge", -10.0)
	var found_nb_span := false
	for child in nb_chunk.get_children():
		if child is StaticBody3D and not child.is_in_group("track_rail"):
			for gc in child.get_children():
				if gc is CollisionShape3D and gc.shape is BoxShape3D:
					var bsz: Vector3 = (gc.shape as BoxShape3D).size
					if absf(bsz.z - 16.0) < 0.1:
						assert_approx(bsz.x, 5.25, 0.02, "NarrowBridge central span widened +25% to 5.25m")
						found_nb_span = true
	assert_true(found_nb_span, "NarrowBridge builds 16m central bridge slab")

	var sp_chunk = chunk_script.new()
	root.add_child(sp_chunk)
	sp_chunk.build_chunk("SplitPath", -10.0)
	var found_sp_floor := false
	for child in sp_chunk.get_children():
		if child is StaticBody3D and not child.is_in_group("track_rail"):
			for gc in child.get_children():
				if gc is CollisionShape3D and gc.shape is BoxShape3D:
					assert_approx((gc.shape as BoxShape3D).size.x, 14.0, 0.02, "SplitPath total width widened +25% to 14.0m")
					found_sp_floor = true
	assert_true(found_sp_floor, "SplitPath builds 14.0m wide floor slab")

	assert_true(wave_chunk.has_method("add_sky_platform"), "TrackChunkBase exposes add_sky_platform()")
	if wave_chunk.has_method("add_sky_platform"):
		var sky_deck = wave_chunk.add_sky_platform(Vector3(0.0, 5.0, -15.0), Vector3(3.8, 0.34, 11.5), true)
		assert_true(sky_deck is StaticBody3D, "add_sky_platform returns StaticBody3D")
		if sky_deck is StaticBody3D:
			assert_true(sky_deck.is_in_group("sky_platform"), "SkyPlatform belongs to group 'sky_platform'")
			assert_eq(bool(sky_deck.get_meta("is_anchored_fixed", false)), true, "SkyPlatform sets is_anchored_fixed meta")
			var col_count := 0
			for sc in sky_deck.get_children():
				if sc is CollisionShape3D:
					col_count += 1
			assert_eq(col_count, 2, "SkyPlatform with_end_kick attaches main deck + angled kick lip CollisionShape3D")
```

- [ ] **Step 2: Run test suite to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL on `STANDARD_WIDTH` (`10.0` vs `12.5`), `NarrowBridge` (`4.2` vs `5.25`), `SplitPath` (`11.2` vs `14.0`), missing `add_sky_platform`, and `ChaseCamera3D.FOLLOW_OFFSET`.

- [ ] **Step 3: Implement +25% widened chunk builders, `add_sky_platform`, and `ChaseCamera3D` offset**

Update `src/gameplay/chase_camera_3d.gd`:

```gdscript
const FOLLOW_OFFSET := Vector3(0.0, 5.6, 8.8)
```

Update `src/track/track_chunk_base.gd`:
- Change `const STANDARD_WIDTH: float = 12.5`
- Update `add_side_launch_ramp(local_pos: Vector3, width: float = 3.0) -> StaticBody3D`
- Add `add_sky_platform`:

```gdscript
func add_sky_platform(
	local_pos: Vector3,
	size: Vector3 = Vector3(3.8, 0.34, 11.5),
	with_end_kick: bool = false
) -> StaticBody3D:
	var deck := StaticBody3D.new()
	deck.name = "SkyPlatform"
	deck.add_to_group("sky_platform")
	deck.position = local_pos
	deck.physics_material_override = MaterialLibrary.high_friction_physics(0.80, 0.14)
	deck.set_meta("is_anchored_fixed", true)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	deck.add_child(col)

	var kick_len := 2.6
	var kick_pitch_deg := 12.0
	var kick_rad := deg_to_rad(kick_pitch_deg)
	var kick_offset := Vector3(
		0.0,
		(kick_len * 0.5) * sin(kick_rad),
		-size.z * 0.5 - (kick_len * 0.5) * cos(kick_rad) + 0.08
	)
	if with_end_kick:
		var kick_col := CollisionShape3D.new()
		var kick_shape := BoxShape3D.new()
		kick_shape.size = Vector3(size.x, size.y, kick_len)
		kick_col.shape = kick_shape
		kick_col.position = kick_offset
		kick_col.rotation_degrees = Vector3(kick_pitch_deg, 0.0, 0.0)
		deck.add_child(kick_col)

	if DisplayServer.get_name() != "headless":
		var deck_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.32, 0.90, 1.0, 0.64))
		var trim_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.76, 0.98, 1.0, 0.86))
		var strut_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.98, 0.80, 0.36, 0.52))

		var deck_mesh := MeshInstance3D.new()
		var deck_box := BoxMesh.new()
		deck_box.size = size
		deck_box.material = deck_mat
		RenderHelper.attach_mesh(deck_mesh, deck_box)
		deck.add_child(deck_mesh)

		for side_sign in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			var curb_box := BoxMesh.new()
			curb_box.size = Vector3(0.09, 0.10, size.z)
			curb_box.material = trim_mat
			RenderHelper.attach_mesh(curb, curb_box)
			curb.position = Vector3(side_sign * (size.x * 0.5 - 0.045), size.y * 0.5 + 0.05, 0.0)
			deck.add_child(curb)

			# Slender angled side-stay cables (visual only, leaving ground lane 100% clear)
			var stay := MeshInstance3D.new()
			var stay_cyl := CylinderMesh.new()
			stay_cyl.top_radius = 0.035
			stay_cyl.bottom_radius = 0.035
			stay_cyl.height = 1.85
			stay_cyl.radial_segments = 8
			stay_cyl.material = strut_mat
			RenderHelper.attach_mesh(stay, stay_cyl)
			stay.position = Vector3(side_sign * (size.x * 0.5 + 0.28), -0.78, 0.0)
			stay.rotation_degrees = Vector3(0.0, 0.0, side_sign * 22.0)
			deck.add_child(stay)

		if with_end_kick:
			var kick_mesh := MeshInstance3D.new()
			var kick_box := BoxMesh.new()
			kick_box.size = Vector3(size.x, size.y, kick_len)
			kick_box.material = trim_mat
			RenderHelper.attach_mesh(kick_mesh, kick_box)
			kick_mesh.position = kick_offset
			kick_mesh.rotation_degrees = Vector3(kick_pitch_deg, 0.0, 0.0)
			deck.add_child(kick_mesh)

	add_child(deck)
	return deck
```

- Scale all 7 chunk builders in `src/track/track_chunk_base.gd` by `1.25×`:
  - `_build_straight_wide()`: `_add_speed_stripes(length, 5.25)`, outer rails at `±6.45` (`Vector3(±6.45, 0.55, -length * 0.5)`).
  - `_build_wave_hills()`: outer rails at `±6.45` (`Vector3(±6.45, 1.2, -length * 0.5)`).
  - `_build_narrow_bridge()`: entry/exit aprons `Vector3(10.0, FLOOR_THICKNESS, 4.0)`, central bridge `Vector3(5.25, FLOOR_THICKNESS, 16.0)`, hazard edge trims at `[-2.55, 2.55]`.
  - `_build_split_path()`: floor `Vector3(STANDARD_WIDTH + 1.5, FLOOR_THICKNESS, length)` (`14.0m`), outer rails at `±7.2`, central divider `Vector3(1.6, 1.3, 20.0)`.
  - `_build_ramp_gap()`: central launch ramp `_add_sloped_wave_segment(6.5, 0.46, 0.0, -8.0, 1.85, -14.0, ...)`, auxiliary side bridges at `±5.125` with size `Vector3(2.25, FLOOR_THICKNESS, 12.0)`, outer rails at `±6.45`.
  - `_build_pinball_alley()`: `_add_speed_stripes(length, 5.0)`, outer rails at `±6.45`.
  - `_build_funnel_gauntlet()`: outer rails at `±6.45`, inner angled funnel walls at `±4.75` (`Vector3(±4.75, 0.55, -10.0)`).

- [ ] **Step 4: Run test suite to verify green**

Run: `./scripts/test.sh`
Expected: PASS (`0 failed`).

- [ ] **Step 5: Commit Task 1**

```bash
git add src/track/track_chunk_base.gd src/gameplay/chase_camera_3d.gd tests/test_track_generator.gd tests/test_ball_and_gravity.gd
git commit -m "feat: widen track chunks by 25%, add SkyPlatform builder, and widen camera offset"
```

---

### Task 2: Surface-Aware Multi-Elevation Landing & Control on `PlayerBall3D`

**Files:**
- Modify: `src/gameplay/player_ball_3d.gd`
- Test: `tests/test_ball_and_gravity.gd`

**Interfaces:**
- Consumes: `TrackChunkBase.add_sky_platform(...)`, `PhysicsSynergyBus.on_land(ctx)`
- Produces:
  - `PlayerBall3D.has_ground_or_sky_support() -> bool`
  - `PlayerBall3D.is_airborne() -> bool` (returns `false` both near ground floor `y <= safe_floor_y + current_radius + 0.38` AND when supported on an elevated static deck such as `SkyPlatform`)
  - Widened safe respawn X window `absf(local_pos.x) <= 3.0` on main deck

- [ ] **Step 1: Write the failing test for `SkyPlatform` landing (`on_land` + `quake_refractor`) and elevated ground control**

Add `_test_sky_platform_landing_and_elevated_control()` to `tests/test_ball_and_gravity.gd` and call it in `run()`:

```gdscript
func _test_sky_platform_landing_and_elevated_control() -> void:
	var ball_script: GDScript = load("res://src/gameplay/player_ball_3d.gd")
	var bus_script: GDScript = load("res://src/core/physics_synergy_bus.gd")
	var catalog_script: GDScript = load("res://src/upgrades/upgrade_catalog.gd")
	var chunk_script: GDScript = load("res://src/track/track_chunk_base.gd")
	var ctrl_script: GDScript = load("res://src/gameplay/lateral_thrust_controller.gd")
	if ball_script == null or bus_script == null or catalog_script == null or chunk_script == null:
		return

	var root := Node3D.new()
	scene_tree.root.add_child(root)

	if ctrl_script != null:
		var ctrl = ctrl_script.new()
		ctrl.apply_vertical_gravity_to_space(root.get_world_3d().space)

	var sloped_track := Node3D.new()
	sloped_track.rotation_degrees = Vector3(-11.0, 0.0, 0.0)
	root.add_child(sloped_track)

	var chunk = chunk_script.new()
	sloped_track.add_child(chunk)
	chunk.build_chunk("StraightWide", 0.0)
	chunk.add_sky_platform(Vector3(0.0, 5.0, -13.0), Vector3(4.0, 0.34, 14.0), false)

	var catalog = catalog_script.new()
	var bus = bus_script.new()
	bus.apply_upgrade(catalog.get_upgrade("quake_refractor"))
	bus.apply_upgrade(catalog.get_upgrade("momentum_overload"))

	var ball = ball_script.new()
	root.add_child(ball)
	ball.setup(bus)
	ball.track_reference = sloped_track
	ball.reset_for_track(sloped_track.to_global(Vector3(0.0, ball.current_radius + 0.1, -2.0)))
	await scene_tree.physics_frame

	var land_waves := {"count": 0}
	ball.synergy_actions_requested.connect(
		func(actions: Dictionary) -> void:
			var ws: Array = actions.get("shockwaves", [])
			land_waves["count"] = int(land_waves["count"]) + ws.size()
	)

	# Drop ball from high air (Y = 8.4m) onto the Y = 5.0m SkyPlatform
	ball.global_position = sloped_track.to_global(Vector3(0.0, 8.4, -10.0))
	ball.linear_velocity = (-sloped_track.global_transform.basis.z.normalized()) * 6.0

	var landed_on_sky := false
	for _f in range(40):
		ball.step_ball(1.0 / 60.0, 0.0, 0.0)
		await scene_tree.physics_frame
		var lpos: Vector3 = sloped_track.to_local(ball.global_position)
		if lpos.y > 4.8 and not ball.is_airborne():
			landed_on_sky = true

	assert_true(landed_on_sky, "PlayerBall3D recognizes surface support (is_airborne() == false) while rolling on Y=5.0m SkyPlatform")
	assert_gt(float(land_waves["count"]), 0.0, "Landing on elevated SkyPlatform triggers on_land (Quake Refractor shockwave)")
	assert_gt(float(bus.combo_stacks), 0.0, "Landing on elevated SkyPlatform grants Momentum Overload stack")

	root.queue_free()
	await scene_tree.process_frame
```

- [ ] **Step 2: Run test suite to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL because `PlayerBall3D.is_airborne()` stays `true` at `Y = 5.7m` and `on_land` never fires on the `SkyPlatform`.

- [ ] **Step 3: Implement `_surface_support_timer` and `has_ground_or_sky_support()` in `PlayerBall3D`**

In `src/gameplay/player_ball_3d.gd`:
1. Add constant and state variable:

```gdscript
const SURFACE_SUPPORT_GRACE: float = 0.08
```
```gdscript
var _surface_support_timer: float = 0.0
```

2. Reset `_surface_support_timer = 0.0` in `reset_for_track()` and when entering respawn (`is_respawning = true`).
3. Add `has_ground_or_sky_support()` and update `is_airborne()`:

```gdscript
func has_ground_or_sky_support() -> bool:
	var local_pos := _to_track_local(_get_ball_world_pos())
	if (local_pos.y - (safe_floor_y + current_radius)) <= 0.38:
		return true
	if _surface_support_timer > 0.0:
		var up_speed := linear_velocity.dot(_get_track_basis().y)
		if up_speed <= 3.5:
			return true
	return false


func is_airborne() -> bool:
	return not has_ground_or_sky_support()
```

4. In `_integrate_forces(state: PhysicsDirectBodyState3D)`, detect upward-facing static deck contacts (`StaticBody3D` not in `"track_rail"` and not in `"pinball_bumper"`, with `contact_normal.dot(track_up) >= 0.62`):

```gdscript
	var track_up := get_track_basis().y.normalized()
```
Inside the `for cid in by_collider.keys():` loop, after computing `contact_normal`:
```gdscript
		if (
			col_node is StaticBody3D
			and not col_node.is_in_group("track_rail")
			and not col_node.is_in_group("pinball_bumper")
			and contact_normal.dot(track_up) >= 0.62
		):
			_surface_support_timer = SURFACE_SUPPORT_GRACE
```

5. In `step_ball(delta, thrust_axis, lateral_accel)`:
   - Widen safe respawn X window from `2.4` to `3.0`:
     ```gdscript
     	if local_pos.y >= safe_floor_y - 0.5 and local_pos.y <= safe_floor_y + current_radius + 0.6:
     		if absf(local_pos.x) <= 3.0:
     			last_safe_pos = Vector3(0.0, safe_floor_y + current_radius + 0.2, local_pos.z)
     ```
   - Use `var currently_supported := has_ground_or_sky_support()` and decrement `_surface_support_timer = maxf(0.0, _surface_support_timer - delta)` for airborne/landing tracking AND lateral release damping (`elif absf(thrust_axis) < 0.05 and currently_supported:`).

- [ ] **Step 4: Run test suite to verify green**

Run: `./scripts/test.sh`
Expected: PASS (`0 failed`).

- [ ] **Step 5: Commit Task 2**

```bash
git add src/gameplay/player_ball_3d.gd tests/test_ball_and_gravity.gd
git commit -m "feat: support multi-elevation landing and ground control on SkyPlatforms"
```

---

### Task 3: Regional 3D `WindZone` Entity (Indiscriminate Rigidbody Physics, Synergy, & Visuals)

**Files:**
- Create: `src/track/entities/wind_zone.gd`
- Modify: `src/track/entities/track_entity_factory.gd`
- Modify: `src/upgrades/upgrade_catalog.gd`
- Test: `tests/test_entities.gd`

**Interfaces:**
- Consumes: `PlayerBall3D`, `CrateObstacle`, `WoodenPin`, `AerialBlocker`, `ExplosiveBarrel`, `BouncerSlime`, `ShieldBrute`, `MaterialLibrary.make_frosted_acrylic_material`, `RenderHelper.attach_mesh`
- Produces:
  - `WindZone` (`class_name WindZone extends Area3D`):
    - `zone_size: Vector3`, `wind_preset: String`, `wind_dir_local: Vector3`, `wind_force_newtons: float`
    - `configure_wind(p_size: Vector3, p_preset: String, p_force: float = -1.0) -> void`
    - `contains_local_point(pt_in_parent_space: Vector3, margin: float = 0.25) -> bool`
  - `TrackEntityFactory.create_wind_zone(pos: Vector3, zone_size: Vector3 = Vector3(6.0, 3.6, 12.0), preset: String = "cross_right", force_newtons: float = -1.0) -> WindZone`
  - `TrackEntityFactory.create_bouncer_slime(pos: Vector3, patrol_half_w: float = 3.5) -> BouncerSlime`

- [ ] **Step 1: Write the failing `WindZone` tests in `tests/test_entities.gd`**

Add `_test_wind_zone_3d_vectors_synergy_and_indiscriminate_rigidbodies()` to `tests/test_entities.gd` and call it in `run()`:

```gdscript
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

	var root := Node3D.new()
	scene_tree.root.add_child(root)
	var space_rid := root.get_world_3d().space
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.DOWN)
	PhysicsServer3D.area_set_param(space_rid, PhysicsServer3D.AREA_PARAM_GRAVITY, 22.0)

	_add_flat_floor(root, -20.0, 70.0)
	var catalog = catalog_script.new()

	# 1. Crosswind (+X) pushes PlayerBall3D laterally along +X
	var cross_wind = factory_script.create_wind_zone(Vector3(0.0, 2.0, -8.0), Vector3(12.0, 4.0, 12.0), "cross_right", 28.0)
	root.add_child(cross_wind)
	var ball_cross = _create_ball_in(root)
	ball_cross.global_position = Vector3(0.0, 0.55, -8.0)
	ball_cross.linear_velocity = Vector3.ZERO

	for _f in range(18):
		await scene_tree.physics_frame
	assert_gt(ball_cross.linear_velocity.x, 2.5, "cross_right WindZone accelerates PlayerBall3D along +X")
	ball_cross.queue_free()
	cross_wind.queue_free()
	await scene_tree.physics_frame

	# 2. Updraft (+Y/-Z) lifts 1.5kg PlayerBall3D into upper air, and Tailwind Sail amplifies tailwind/updraft!
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

	# 3. Indiscriminate rigidbody wind physics: blows 500g crate, topples 800g pin, untethers & blows 250g balloon,
	#    while 20kg ShieldBrute stands rock-solid!
	var gale_zone = factory_script.create_wind_zone(Vector3(0.0, 2.5, -34.0), Vector3(14.0, 5.5, 14.0), "cross_right", 28.0)
	var wind_crate = factory_script.create_crate(Vector3(-3.0, 0.48, -31.0), "light")
	var wind_pin = factory_script.create_wooden_pin(Vector3(-3.0, 0.78, -34.0))
	var wind_balloon = factory_script.create_aerial_blocker(Vector3(-3.0, 3.0, -36.5), "soft_balloon", 0.0)
	var wind_iron = factory_script.create_aerial_blocker(Vector3(2.0, 3.2, -36.5), "mag_iron", 0.0)
	var wind_brute = factory_script.create_shield_brute(Vector3(2.0, 0.70, -32.0))
	root.add_child(gale_zone)
	root.add_child(wind_crate)
	root.add_child(wind_pin)
	root.add_child(wind_balloon)
	root.add_child(wind_iron)
	root.add_child(wind_brute)

	var min_pin_up := 1.0
	for _f in range(36):
		await scene_tree.physics_frame
		min_pin_up = minf(min_pin_up, wind_pin.transform.basis.y.normalized().dot(Vector3.UP))

	assert_gt(wind_crate.position.x - (-3.0), 0.8, "WindZone blows 500g light crate substantially along +X")
	assert_lt(min_pin_up, 0.78, "WindZone topples 800g WoodenPin via aerodynamic torque (up_dot < 0.78)")
	assert_gt(wind_pin.position.x - (-3.0), 0.4, "WindZone pushes toppled 800g WoodenPin along +X")
	assert_false(bool(wind_balloon.get("is_tethered")), "Strong WindZone untethers 250g soft_balloon")
	assert_gt(wind_balloon.position.x - (-3.0), 1.5, "WindZone blows 250g soft_balloon briskly along +X")
	assert_true(bool(wind_iron.get("is_tethered")), "12kg mag_iron magnetic lock resists wind untethering")
	assert_lt(absf(wind_brute.position.x - 2.0), 0.08, "20kg ShieldBrute stands rock-solid in WindZone via pure Newtonian static friction")

	root.queue_free()
	await scene_tree.process_frame
```

- [ ] **Step 2: Run test suite to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL because `TrackEntityFactory.create_wind_zone` does not exist yet.

- [ ] **Step 3: Create `src/track/entities/wind_zone.gd`, wire `TrackEntityFactory`, and update `UpgradeCatalog`**

Create `src/track/entities/wind_zone.gd`:

```gdscript
class_name WindZone
extends Area3D

const RIBBON_COUNT: int = 12

var zone_size: Vector3 = Vector3(6.0, 3.6, 12.0)
var wind_preset: String = "cross_right"
var wind_dir_local: Vector3 = Vector3.RIGHT
var wind_force_newtons: float = 26.0
var wind_tint: Color = Color(0.36, 0.90, 1.0, 0.58)

var _bodies_in_zone: Array[RigidBody3D] = []
var _initial_scan_done: bool = false
var _visual_phase: float = 0.0
var _flow_root: Node3D = null
var _ribbon_items: Array[Dictionary] = []


func _init() -> void:
	configure_wind(zone_size, wind_preset, -1.0)


func configure_wind(p_size: Vector3, p_preset: String, p_force: float = -1.0) -> void:
	zone_size = Vector3(maxf(1.5, p_size.x), maxf(1.5, p_size.y), maxf(1.5, p_size.z))
	wind_preset = p_preset

	var default_force := 26.0
	match wind_preset:
		"cross_left":
			wind_dir_local = Vector3(-1.0, 0.0, 0.0)
			default_force = 26.0
			wind_tint = Color(0.36, 0.90, 1.0, 0.58)
		"cross_right":
			wind_dir_local = Vector3(1.0, 0.0, 0.0)
			default_force = 26.0
			wind_tint = Color(0.36, 0.90, 1.0, 0.58)
		"tailwind":
			wind_dir_local = Vector3(0.0, 0.0, -1.0)
			default_force = 28.0
			wind_tint = Color(0.24, 0.98, 0.68, 0.60)
		"headwind":
			wind_dir_local = Vector3(0.0, 0.0, 1.0)
			default_force = 21.0
			wind_tint = Color(1.0, 0.58, 0.22, 0.56)
		"updraft":
			wind_dir_local = Vector3(0.0, 0.94, -0.34).normalized()
			default_force = 44.0
			wind_tint = Color(0.24, 1.0, 0.72, 0.64)
		"high_downdraft_left":
			wind_dir_local = Vector3(-0.45, -0.89, 0.0).normalized()
			default_force = 22.0
			wind_tint = Color(1.0, 0.56, 0.24, 0.56)
		"high_downdraft_right":
			wind_dir_local = Vector3(0.45, -0.89, 0.0).normalized()
			default_force = 22.0
			wind_tint = Color(1.0, 0.56, 0.24, 0.56)
		_:
			wind_dir_local = Vector3(1.0, 0.0, 0.0)
			default_force = 26.0
			wind_tint = Color(0.36, 0.90, 1.0, 0.58)

	wind_force_newtons = p_force if p_force > 0.0 else default_force


func contains_local_point(pt_in_parent_space: Vector3, margin: float = 0.25) -> bool:
	var half := zone_size * 0.5 + Vector3.ONE * margin
	var diff := pt_in_parent_space - position
	return (
		absf(diff.x) <= half.x
		and absf(diff.y) <= half.y
		and absf(diff.z) <= half.z
	)


func _ready() -> void:
	add_to_group("wind_zone")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = zone_size
	col.shape = box
	add_child(col)

	_build_wind_visuals()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _build_wind_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var ribbon_mat := MaterialLibrary.make_frosted_acrylic_material(wind_tint)
	var arrow_color := wind_tint.lightened(0.22)
	arrow_color.a = 0.78
	var arrow_mat := MaterialLibrary.make_frosted_acrylic_material(arrow_color)
	var rim_color := Color(wind_tint.r, wind_tint.g, wind_tint.b, 0.28)
	var rim_mat := MaterialLibrary.make_frosted_acrylic_material(rim_color)

	# Subtle base boundary strips on the bottom face of the wind volume so edges read clearly
	for side_x in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_box := BoxMesh.new()
		edge_box.size = Vector3(0.08, 0.05, zone_size.z)
		edge_box.material = rim_mat
		RenderHelper.attach_mesh(edge, edge_box)
		edge.position = Vector3(side_x * (zone_size.x * 0.5 - 0.04), -zone_size.y * 0.5 + 0.03, 0.0)
		add_child(edge)

	# Orient _flow_root so its -Z axis points strictly along wind_dir_local
	_flow_root = Node3D.new()
	_flow_root.name = "WindFlowRoot"
	var up_hint := Vector3.UP if absf(wind_dir_local.dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
	_flow_root.basis = Basis.looking_at(wind_dir_local, up_hint)
	add_child(_flow_root)

	var flow_span := _compute_flow_span(wind_dir_local)
	var cross_w := maxf(1.4, _compute_flow_span(_flow_root.basis.x) * 0.76)
	var cross_h := maxf(1.2, _compute_flow_span(_flow_root.basis.y) * 0.68)
	var ribbon_base_len := clampf(flow_span * 0.26, 1.4, 2.6)

	_ribbon_items.clear()
	for i in range(RIBBON_COUNT):
		var u := (float(i % 4) + 0.5) / 4.0 - 0.5
		@warning_ignore("integer_division")
		var row := i / 4
		var v := (float(row) + 0.5) / 3.0 - 0.5
		var stagger := fmod(float(i) * 0.29 + float(row) * 0.17, 1.0)

		var rib := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(0.055, 0.035, ribbon_base_len)
		rbox.material = ribbon_mat
		RenderHelper.attach_mesh(rib, rbox)
		_flow_root.add_child(rib)

		_ribbon_items.append({
			"node": rib,
			"x": u * cross_w,
			"y": v * cross_h,
			"offset": stagger,
			"span": flow_span,
		})

	# Three crisp 3D chevron arrowheads pointing along wind_dir_local (-Z of _flow_root)
	var chevron_rot := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	for idx in range(3):
		var z_frac := (float(idx) - 1.0) * 0.28 * flow_span
		var chev := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.68, 0.56, 0.10)
		prism.material = arrow_mat
		RenderHelper.attach_mesh(chev, prism)
		chev.transform = Transform3D(chevron_rot, Vector3(0.0, 0.0, z_frac))
		_flow_root.add_child(chev)

	_update_ribbon_transforms()


func _compute_flow_span(dir: Vector3) -> float:
	var n := dir.normalized()
	return absf(n.x) * zone_size.x + absf(n.y) * zone_size.y + absf(n.z) * zone_size.z


func _update_ribbon_transforms() -> void:
	for item in _ribbon_items:
		var node: MeshInstance3D = item["node"]
		if node == null or not is_instance_valid(node):
			continue
		var span := float(item["span"])
		var t := fposmod(_visual_phase + float(item["offset"]), 1.0)
		var z_pos := lerpf(span * 0.44, -span * 0.44, t)
		var envelope := sin(t * PI)
		node.position = Vector3(float(item["x"]), float(item["y"]), z_pos)
		node.scale = Vector3(maxf(0.15, envelope), maxf(0.15, envelope), maxf(0.20, envelope))


func _on_body_entered(body: Node) -> void:
	if body is RigidBody3D:
		var rb := body as RigidBody3D
		if not _bodies_in_zone.has(rb):
			_bodies_in_zone.append(rb)


func _on_body_exited(body: Node) -> void:
	if body is RigidBody3D:
		_bodies_in_zone.erase(body as RigidBody3D)


func _sync_overlapping_rigidbodies() -> void:
	for b in get_overlapping_bodies():
		if b is RigidBody3D:
			var rb := b as RigidBody3D
			if not _bodies_in_zone.has(rb):
				_bodies_in_zone.append(rb)


func _physics_process(delta: float) -> void:
	if not _initial_scan_done:
		_initial_scan_done = true
		_sync_overlapping_rigidbodies()
	elif monitoring:
		_sync_overlapping_rigidbodies()

	if not _ribbon_items.is_empty():
		var span := maxf(2.0, _compute_flow_span(wind_dir_local))
		var scroll_speed := clampf(wind_force_newtons * 0.42, 7.0, 19.0)
		_visual_phase = fposmod(_visual_phase + (scroll_speed * delta) / span, 1.0)
		_update_ribbon_transforms()

	var basis_world := (
		global_transform.basis.orthonormalized()
		if is_inside_tree()
		else transform.basis.orthonormalized()
	)
	var w_world := (basis_world * wind_dir_local).normalized()
	var max_wind_speed := clampf(wind_force_newtons * 0.78, 16.0, 34.0)

	for i in range(_bodies_in_zone.size() - 1, -1, -1):
		var rb := _bodies_in_zone[i]
		if rb == null or not is_instance_valid(rb) or rb.is_queued_for_deletion():
			_bodies_in_zone.remove_at(i)
			continue
		if rb.freeze:
			continue

		if rb is PlayerBall3D:
			_apply_wind_to_ball(rb as PlayerBall3D, w_world)
		else:
			_apply_wind_to_obstacle(rb, w_world, max_wind_speed)


func _apply_wind_to_ball(ball: PlayerBall3D, w_world: Vector3) -> void:
	if ball.is_respawning or ball._is_paused:
		return
	var area_scale := pow(ball.current_radius / StatSheet.BASE_RADIUS, 1.5)
	var f_vec := w_world * (wind_force_newtons * area_scale)

	if ball.synergy_bus != null:
		var ext_mult := ball.synergy_bus.stats.get_stat("external_boost_mult")
		if ext_mult > 1.001:
			var t_basis := ball.get_track_basis()
			var fwd_dir := -t_basis.z.normalized()
			var up_dir := t_basis.y.normalized()
			var fwd_comp := f_vec.dot(fwd_dir)
			var up_comp := f_vec.dot(up_dir)
			if fwd_comp > 0.0:
				f_vec += fwd_dir * (fwd_comp * (ext_mult - 1.0))
			if up_comp > 0.0:
				f_vec += up_dir * (up_comp * (ext_mult - 1.0))

	ball.apply_central_force(f_vec)


func _apply_wind_to_obstacle(rb: RigidBody3D, w_world: Vector3, max_wind_speed: float) -> void:
	var along_v := rb.linear_velocity.dot(w_world)
	var rel_factor := clampf(1.0 - (along_v / max_wind_speed), 0.0, 1.25)

	if rb is AerialBlocker:
		var ab := rb as AerialBlocker
		var area_ab := 1.15 if ab.blocker_type == "soft_balloon" else 0.95
		if ab.is_tethered:
			if ab.blocker_type == "soft_balloon" and wind_force_newtons * area_ab >= 12.0:
				ab.untether()
			else:
				return
		rb.apply_central_force(w_world * (wind_force_newtons * area_ab * rel_factor))
		return

	if rb is BouncerSlime:
		var slime := rb as BouncerSlime
		if slime.is_patrolling:
			return
		rb.apply_central_force(w_world * (wind_force_newtons * 1.0 * rel_factor))
		return

	if rb is WoodenPin:
		var pin := rb as WoodenPin
		var f_pin := wind_force_newtons * 0.95 * rel_factor
		if f_pin >= 9.5:
			pin.dislodge()
		var pin_up := (
			pin.global_transform.basis.y.normalized()
			if pin.is_inside_tree()
			else pin.transform.basis.y.normalized()
		)
		pin.apply_force(w_world * f_pin, pin_up * 0.36)
		return

	if rb is CrateObstacle:
		var crate := rb as CrateObstacle
		var area_c := 0.90 if crate.weight_tier == "light" else 1.05
		var f_crate := wind_force_newtons * area_c * rel_factor
		if crate.weight_tier == "light" and f_crate >= 9.5:
			crate.dislodge()
		elif crate.weight_tier == "medium" and f_crate >= 34.0:
			crate.dislodge()
		crate.apply_central_force(w_world * f_crate)
		return

	if rb is ExplosiveBarrel:
		var barrel := rb as ExplosiveBarrel
		var area_b := 0.95
		var f_barrel := wind_force_newtons * area_b * rel_factor
		if barrel.is_detonated and f_barrel >= 8.0:
			barrel.sleeping = false
		barrel.apply_central_force(w_world * f_barrel)
		return

	# ShieldBrute (20kg) and any generic RigidBody3D receive pure Newtonian force indiscriminately
	rb.apply_central_force(w_world * (wind_force_newtons * 1.10 * rel_factor))
```

In `src/track/entities/track_entity_factory.gd`:
- Update `create_bouncer_slime` default `patrol_half_w: float = 3.5`
- Add `create_wind_zone`:

```gdscript
static func create_wind_zone(
	pos: Vector3,
	zone_size: Vector3 = Vector3(6.0, 3.6, 12.0),
	preset: String = "cross_right",
	force_newtons: float = -1.0
) -> WindZone:
	var n := WindZone.new()
	n.configure_wind(zone_size, preset, force_newtons)
	n.position = pos
	return n
```

In `src/upgrades/upgrade_catalog.gd`, update `"tailwind_sail"` description:

```gdscript
			"受到加速带、缓冲桩、顺风/上升风场与爆炸气浪作用时，获得的有利推进力 ×1.75。"
```

- [ ] **Step 4: Run test suite to verify green**

Run: `./scripts/test.sh`
Expected: PASS (`0 failed`).

- [ ] **Step 5: Commit Task 3**

```bash
git add src/track/entities/wind_zone.gd src/track/entities/track_entity_factory.gd src/upgrades/upgrade_catalog.gd tests/test_entities.gd
git commit -m "feat: add regional 3D WindZone with indiscriminate rigidbody physics and ribbons"
```

---

### Task 4: `TrackGenerator3D` +25% Layout, Sparse Upper-Air Layer, & Regional Wind Orchestration

**Files:**
- Modify: `src/track/track_generator_3d.gd`
- Test: `tests/test_track_generator.gd`
- Test: `tests/test_game_loop.gd`

**Interfaces:**
- Consumes: `TrackChunkBase.STANDARD_WIDTH` (`12.5`), `TrackChunkBase.add_sky_platform(...)`, `TrackEntityFactory.create_wind_zone(...)`
- Produces:
  - +25% widened start platform (`12.5m`), finish archway (`15.0m` runway, `±6.75m` pillars, `28.0 × 22.0 × 3.5m` goal `Area3D` covering ground and sky finishes), and lateral entity placements
  - Low-density upper-air `SkyPlatform`s and high-altitude rings/crates/pins/blockers (`Y = 4.5m ~ 6.6m`)
  - Deterministic ground & aerial `WindZone`s across generated chunks

- [ ] **Step 1: Write the failing generator & game-loop tests for upper-air sky layer, wind zones, and slope stability**

In `tests/test_track_generator.gd`:
1. Update `_capture_track_signature(info: Dictionary)` to also record `WindZone` preset & force:
```gdscript
		if node_ent is AerialBlocker:
			extra += "|phase=%0.4f" % (node_ent as AerialBlocker).initial_phase
		elif node_ent is WindZone:
			var wz := node_ent as WindZone
			extra += "|wind=%s:%0.2f" % [wz.wind_preset, wz.wind_force_newtons]
```
2. In `_test_wave_hills_side_launch_ramp_and_vertical_entities()`, track and assert that seeded tracks generate:
   - `found_sky_platform` (`StaticBody3D` in group `"sky_platform"` inside chunks at `position.y >= 4.4`)
   - `found_high_air_entity` (entity at `position.y >= 4.5`)
   - `found_ground_wind` (`WindZone` at `position.y < 3.6`)
   - `found_aerial_wind` (`WindZone` at `position.y >= 3.6` or `wind_preset == "updraft"`)
   - Multiple distinct `WindZone` presets (`seen_wind_presets.size() >= 4`)
   - Low-density upper-air ratio (`sky_chunk_count <= total_chunk_count * 0.65`, keeping upper air uncluttered).

In `tests/test_game_loop.gd`:
1. Update `_capture_world_track_state(world)` to include `WindZone` preset & force in `extra` just like `test_track_generator.gd`.
2. In `_test_vertical_gravity_zero_roll_and_slope_stability()`, collect active `WindZone`s first and exclude obstacles spawned inside a `WindZone` (`wz.contains_local_point(node_ent.position, 0.5)`) from the calm-slope stationary `500g`/`800g` lists (since `WindZone` intentionally blows light crates and pins!), while keeping `20kg` `ShieldBrute` stationary everywhere.
3. In `_test_hud_seed_modal_pause_bonus_ring_and_summary_seed_actions()`, spawn a `WindZone` (`"cross_right"`, `30.0 N`) during the `SEED_INPUT` pause check and assert its `_visual_phase` and nearby `500g` crate stay completely frozen while `SEED_INPUT` is open!

- [ ] **Step 2: Run test suite to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL because `TrackGenerator3D` does not yet spawn `SkyPlatform`s, high-altitude (`Y >= 4.5m`) entities, or `WindZone`s.

- [ ] **Step 3: Update `TrackGenerator3D` with +25% lateral scaling, `_populate_high_air_layer`, and `_populate_chunk_wind_zones`**

In `src/track/track_generator_3d.gd`:
1. Update `_build_start_platform()`:
   - Floor width `TrackChunkBase.STANDARD_WIDTH` (`12.5m`), side rails at `±6.45`, backstop rail `Vector3(12.9, 1.1, 0.5)`.
2. Update `_build_finish_archway(z_pos)`:
   - Runway slab width `15.0` (`Vector3(15.0, 0.6, FINISH_RUNWAY_LEN)`), pillars at `[-6.75, 6.75]` (`height = 7.5`, `y = 3.75`), crossbar `Vector3(14.4, 0.75, 0.75)` at `y = 7.4`, `goal_area` at `Vector3(0.0, 7.5, z_pos)` with `BoxShape3D` size `Vector3(28.0, 22.0, 3.5)`.
3. Update `_resolve_rigidbody_clearance`:
   - If `desired.y >= 4.2` (upper-air / sky platform), restrict `test_x` clamp to `[desired.x - 1.1, desired.x + 1.1]` so perched sky-platform obstacles never shift off the `3.8m`-wide sky deck; otherwise clamp `test_x` to `[-4.8, 4.8]` with `x_offsets = [0.0, -1.2, 1.2, -2.4, 2.4, -3.6, 3.6]`.
4. Scale lateral entity coordinates in `_populate_chunk_entities` by `1.25×`:
   - `StraightWide`: `BoostPad` `[-2.75, 2.75]`; first chunk `spring_x = side_sign * 3.85`, pins `-side_sign * 2.95`, crates `lane_sign * rng.randf_range(1.2, 2.55)`; non-first chunk `ramp_x = side_sign * 4.0`, `add_side_launch_ramp(Vector3(ramp_x, 0.0, -10.5), 3.0)`, pins `-side_sign * 2.05`, `ShieldBrute` `-side_sign * 1.45`, `opp_x = -side_sign * 3.75`, `ExplosiveBarrel` `-side_sign * 3.65`, `crate_slots` X multiplied by `1.25`, `BouncerSlime` `patrol_half_w = 3.5`.
   - `WaveHills`: `ring_x_1`, `ring_x_2` in `[-2.75, 2.75]`, blocker clamp `[-4.0, 4.0]`, trough crates at `±2.75`, exit pins in `[-1.75, 1.75]`.
   - `NarrowBridge`: Level 2+ `nb_x` in `[-1.05, 1.05]`.
   - `SplitPath`: Left lane `-3.85` (crates `-2.70`, `-5.00`), Right lane `+3.85` (`SlimeZone` `Vector2(4.5, 10.0)`, blocker `x = 2.95`).
   - `RampGap`: `chasm_blocker_x = ±1.05`, landing crates `±1.75`, `BouncerSlime` `patrol_half_w = 3.5`.
   - `PinballAlley`: bumpers at `-2.75`, `+2.75`, `0.0`; `BouncerSlime` `3.75`; crate `[-4.0, 4.0]`; barrel `[-3.1, 3.1]`.
   - `FunnelGauntlet`: `BoostPad`s `±3.0`, `ShieldBrute`s `±2.30`, funnel crates `lane_sign * rng.randf_range(1.45, 3.15)`, `BouncerSlime` `3.75`.
5. Add `_populate_high_air_layer(chunk: TrackChunkBase, level: int, rng: RandomNumberGenerator, is_first_chunk: bool) -> bool` (returns `true` if it spawned an approach updraft so `_populate_chunk_wind_zones` avoids overlapping a second wind zone on the same Z):
   - Skip if `is_first_chunk` or `chunk.chunk_type == "NarrowBridge"`.
   - Roll `sky_prob := clampf(0.34 + 0.04 * float(level - 1), 0.34, 0.48)`. If `rng.randf() >= sky_prob`, return `false`.
   - For `"WaveHills"` or `"RampGap"`:
     - `var sky_x := rng.randf_range(-2.4, 2.4)`
     - `var sky_y := rng.randf_range(4.8, 5.7)`
     - If `rng.randf() < 0.55`: build `chunk.add_sky_platform(Vector3(sky_x, sky_y, -18.5), Vector3(3.8, 0.34, 10.0), true)` and perch a high `AerialBonusRing` (`sky_y + 1.25`) + 2 `WoodenPin`s or `500g` crate on it; else spawn a high-arc `AerialBonusRing` (`sky_y + 0.4`) + offset high `AerialBlocker` (`sky_y + 0.2`).
   - For `"StraightWide"`, `"SplitPath"`, `"PinballAlley"`, `"FunnelGauntlet"`:
     - Choose lane `sky_x`: `(-3.85 if rng.randf() < 0.5 else 3.85)` on `"SplitPath"`, else `[-3.6, 0.0, 3.6][rng.randi_range(0, 2)]`.
     - `var sky_y := rng.randf_range(4.6, 5.3)`
     - `chunk.add_sky_platform(Vector3(sky_x, sky_y, -16.2), Vector3(3.8, 0.34, 11.2), rng.randf() < 0.65)`
     - `var top_y := sky_y + 0.17`
     - Spawn `AerialBonusRing` at `Vector3(sky_x, top_y + 1.20, z0 - 13.0)`.
     - Spawn perched high-altitude debris at `z0 - 19.2`: 55% 2-pin `WoodenPin` pair (`Vector3(sky_x ± 0.52, top_y + 0.79, z0 - 19.2)`), 45% `500g` light `CrateObstacle` (`Vector3(sky_x, top_y + 0.50, z0 - 19.2)`).
     - With 55% chance, place an approach `"updraft"` `WindZone` at `Vector3(sky_x, 2.35, z0 - 6.8)` (`Vector3(4.2, 4.7, 8.2)`, `45.0 N`) so the ball can ride the thermal column straight onto the sky bridge!
6. Add `_populate_chunk_wind_zones(chunk: TrackChunkBase, level: int, rng: RandomNumberGenerator, is_first_chunk: bool, has_approach_updraft: bool) -> void`:
   - Skip if `is_first_chunk` or `has_approach_updraft`.
   - Roll `wind_prob := clampf(0.50 + 0.04 * float(level - 1), 0.50, 0.68)`. If `rng.randf() >= wind_prob`, return.
   - Deterministically roll ground (`58%`) vs aerial (`42%`) regional wind zone:
     - Ground region (`y = 1.85`, `z = z0 - chunk.length * rng.randf_range(0.42, 0.68)`):
       - On `"NarrowBridge"`: gentle-to-medium `"cross_left"` / `"cross_right"` (`21.0 N`) or `"tailwind"` (`26.0 N`), size `Vector3(6.5, 3.6, 10.0)`.
       - On `"SplitPath"`: lane-specific (`±3.85`, width `5.2m`) `"tailwind"` (`30.0 N`), `"headwind"` (`21.0 N`), or `"updraft"` (`44.0 N`).
       - On wide chunks: `"cross_left"`, `"cross_right"`, `"tailwind"`, `"updraft"`, or half-width `"headwind"` (`x = ±3.1`, width `5.6m` so player can steer around or ride adjacent lanes), force `rng.randf_range(23.0, 31.0)` (`44.0` for `"updraft"`).
     - Aerial region (`y = rng.randf_range(3.8, 5.4)`, `z = z0 - chunk.length * 0.55`, size `Vector3(10.5, 3.4, 11.5)`):
       - Presets: `"cross_left"`, `"cross_right"`, `"tailwind"`, `"high_downdraft_left"`, `"high_downdraft_right"`.

- [ ] **Step 4: Run full test suite to verify 100% green**

Run: `./scripts/test.sh`
Expected: PASS (`0 failed` across all suites).

- [ ] **Step 5: Commit Task 4 and rebuild Web HTML5 export**

```bash
git add src/track/track_generator_3d.gd tests/test_track_generator.gd tests/test_game_loop.gd
git commit -m "feat: populate widened tracks with upper-air SkyPlatforms and regional 3D WindZones"
./scripts/build-web.sh
git add web/
git commit -m "chore: rebuild web export with +25% wide track, sky layer, and 3D wind zones"
```
