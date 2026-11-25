# Tabletop Visual Polish, Non-Dizzy Physics, Verticality & Deterministic Seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade 《给我滚》 into a bright tabletop marble-run experience with zero-roll non-dizzy camera, uniform downward gravity + real `-11°` sloped track + hold-to-thrust ball control, instant visual material/weight (`500g`–`20kg`)/anchored-bolt readability backed by `gpt-image` textures, vertical jump/spring/aerial-ring/floating-blocker gameplay, and a 100% deterministic user-configurable seed system.

**Architecture:** Global 3D physics space maintains constant vertical downward gravity `(0, -22, 0)` while `TrackGenerator3D` pitches `_track_root` by `-11°` so spherical `PlayerBall3D` naturally rolls downhill and high-friction (`0.88+`) weighted `RigidBody3D` obstacles stay seated until struck. `MaterialLibrary` centralizes `gpt-image` seamless textures, soft vs. hard shaders/materials, `Label3D` weight stencils, and bolted flange anchor bases (safely no-oping GPU resources in headless tests while recording testable metadata). `RunState` isolates per-level track RNG and draft RNG via deterministic SplitMix32 sub-seeds so identical seeds reproduce exact tracks and upgrade drafts.

**Tech Stack:** Godot 4.6 (`gl_compatibility` renderer, Jolt Physics 3D, GDScript), Python 3 + `.agents/skills/gpt-image/scripts/generate.py` (OpenAI `gpt-image-2`), Headless GDScript test runner (`./scripts/test.sh`).

## Global Constraints

- Engine & Renderer: Godot 4.x `gl_compatibility` (must support both native macOS/desktop and Web HTML5 export via `./scripts/build-web.sh`).
- Headless Safety: All tests run via `./scripts/test.sh` (`DisplayServer.get_name() == "headless"`). Never attach GPU-heavy textures/fonts unconditionally in headless mode without guarding via `RenderHelper` / `MaterialLibrary`.
- Determinism: Zero unseeded global `randf()` / `randi()` calls anywhere in `src/`. Every random roll must originate from `RunState.derive_track_seed(run_seed, level)` or `RunState.derive_draft_seed(run_seed, cleared_level)`.
- Camera Stability: `ChaseCamera3D` lateral roll (`rotation_degrees.z`) must remain `0.0` at all times; lateral input applies force only while held and stops immediately on release.

---

### Task 1: Deterministic Seed System & Tail Thruster Adaptation

**Files:**
- Modify: `src/core/run_state.gd`
- Modify: `src/upgrades/upgrade_catalog.gd`
- Test: `tests/test_core_stats.gd`
- Test: `tests/test_synergy_and_upgrades.gd`

**Interfaces:**
- Produces on `RunState`:
  - `var seed_text: String`
  - `static func parse_seed_input(raw_text: String) -> Dictionary` -> `{"seed": int, "text": String}`
  - `static func derive_track_seed(p_run_seed: int, level: int) -> int`
  - `static func derive_draft_seed(p_run_seed: int, cleared_level: int) -> int`
  - `func start_new_run_from_text(raw_text: String) -> void`
- Produces on `UpgradeCatalog`:
  - Updated `tail_thruster` ("侧喷尾流喷口"): `.with_mult("tilt_lateral_force_mult", 0.35)` and `_hook_tail_thruster` triggered whenever `absf(ctx.tilt_deg) > 0.1`.

- [ ] **Step 1: Write failing tests for deterministic seed parsing, sub-seed isolation, and tail thruster**

Append `_test_deterministic_seed_parsing_and_subseeds()` to `tests/test_core_stats.gd` and call it in `run()`:

```gdscript
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
	assert_eq(t1_a, t1_b, "Same run_seed and level produce identical track sub-seed")
	assert_true(t1_a != t2_a, "Different levels produce distinct track sub-seeds")
	assert_true(t1_a != d1_a, "Track seed and draft seed streams are isolated")
```

Also add a tail thruster lateral-thrust check inside `tests/test_synergy_and_upgrades.gd`:

```gdscript
	# Inside _test_emergent_wall_drift_and_overload_decay():
	var bus_thrust = bus_script.new()
	bus_thrust.apply_upgrade(catalog.get_upgrade("tail_thruster"))
	assert_gt(bus_thrust.stats.get_stat("tilt_lateral_force_mult"), 1.30, "Tail thruster boosts lateral force mult")
	var active_thrust_ctx = ctx_script.create(14.0, 6.0, 1.0, 1.5, 0.0, Vector3.UP, Vector3.ZERO, 0, 0)
	var idle_thrust_ctx = ctx_script.create(14.0, 6.0, 0.0, 1.5, 0.0, Vector3.UP, Vector3.ZERO, 0, 0)
	assert_gt(float(bus_thrust.on_physics_tick(active_thrust_ctx, 0.1)["forward_impulse"]), 0.1, "Holding lateral thrust converts lateral speed to forward impulse")
	assert_approx(float(bus_thrust.on_physics_tick(idle_thrust_ctx, 0.1)["forward_impulse"]), 0.0, 0.001, "Releasing lateral thrust stops tail thruster conversion")
```

- [ ] **Step 2: Run `./scripts/test.sh` to confirm tests fail**

Run: `./scripts/test.sh`
Expected: FAIL (`start_new_run_from_text` / `derive_track_seed` missing, `tail_thruster` assertion fails).

- [ ] **Step 3: Implement deterministic seed methods in `RunState` and update `tail_thruster` in `UpgradeCatalog`**

Update `src/core/run_state.gd`:

```gdscript
var run_seed: int = 0
var seed_text: String = ""


static func _splitmix32(x: int) -> int:
	var z := (x + 0x9E3779B9) & 0x7FFFFFFF
	z = ((z ^ (z >> 15)) * 0x85EBCA6B) & 0x7FFFFFFF
	z = ((z ^ (z >> 13)) * 0xC2B2AE35) & 0x7FFFFFFF
	z = (z ^ (z >> 16)) & 0x7FFFFFFF
	return maxi(1, z)


static func parse_seed_input(raw_text: String) -> Dictionary:
	var cleaned := raw_text.strip_edges()
	if cleaned == "":
		var auto_seed := 100000 + int(Time.get_ticks_usec() % 900000)
		return {"seed": auto_seed, "text": str(auto_seed)}
	if cleaned.is_valid_int():
		var val := maxi(1, abs(int(cleaned)) & 0x7FFFFFFF)
		return {"seed": val, "text": cleaned}
	var bytes := cleaned.to_utf8_buffer()
	var h: int = 2166136261
	for b in bytes:
		h = ((h ^ int(b)) * 16777619) & 0x7FFFFFFF
	return {"seed": maxi(1, h), "text": cleaned}


static func derive_track_seed(p_run_seed: int, level: int) -> int:
	return _splitmix32((p_run_seed * 31 + maxi(1, level) * 7919 + 0x13572468) & 0x7FFFFFFF)


static func derive_draft_seed(p_run_seed: int, cleared_level: int) -> int:
	return _splitmix32((p_run_seed * 53 + maxi(1, cleared_level) * 104729 + 0x24681357) & 0x7FFFFFFF)


func start_new_run(seed_val: int = 0) -> void:
	current_level = 1
	time_remaining = BASE_LEVEL_TIME
	owned_upgrade_ids.clear()
	peak_speed_kmh = 0.0
	max_kinetic_energy = 0.0
	total_smashed = 0
	if seed_val > 0:
		run_seed = seed_val & 0x7FFFFFFF
		seed_text = str(run_seed)
	else:
		var parsed := parse_seed_input("")
		run_seed = int(parsed["seed"])
		seed_text = String(parsed["text"])


func start_new_run_from_text(raw_text: String) -> void:
	var parsed := parse_seed_input(raw_text)
	start_new_run(int(parsed["seed"]))
	seed_text = String(parsed["text"])
```

Update `tail_thruster` in `src/upgrades/upgrade_catalog.gd`:

```gdscript
	_register(
		UpgradeDefinition.new(
			"tail_thruster",
			"侧喷尾流喷口",
			"common",
			"converter",
			"左右侧向推力 ×1.35；按住侧推持续变道时，将横向速度持续转化为前向推力。"
		)
		.with_mult("tilt_lateral_force_mult", 0.35)
		.with_hook("on_physics_tick", _hook_tail_thruster)
	)
```

And update `_hook_tail_thruster`:

```gdscript
static func _hook_tail_thruster(
	ctx: PhysicsEventContext,
	bus: PhysicsSynergyBus,
	count: int,
	out: Dictionary,
	delta: float
) -> void:
	if absf(ctx.tilt_deg) <= 0.1 or delta <= 0.0:
		return
	var mult := bus.get_effective_impulse_mult() * float(count)
	var thrust := (6.5 + 0.85 * absf(ctx.lateral_speed)) * ctx.mass * delta * mult
	out["forward_impulse"] = float(out["forward_impulse"]) + thrust
```

- [ ] **Step 4: Run `./scripts/test.sh` to verify tests pass**

Run: `./scripts/test.sh`
Expected: PASS (0 failures).

- [ ] **Step 5: Commit Task 1**

```bash
git add src/core/run_state.gd src/upgrades/upgrade_catalog.gd tests/test_core_stats.gd tests/test_synergy_and_upgrades.gd
git commit -m "feat: add deterministic seed isolation and update tail thruster for lateral thrust"
```

---

### Task 2: Generate 6 Tabletop Seamless Textures via `gpt-image` & Create `MaterialLibrary`

**Files:**
- Create: `assets/textures/track_beechwood.png`
- Create: `assets/textures/crate_balsa_wood.png`
- Create: `assets/textures/metal_cast_iron.png`
- Create: `assets/textures/anchor_hazard_stripe.png`
- Create: `assets/textures/barrel_retro_hazard.png`
- Create: `assets/textures/jelly_bubble_soft.png`
- Create: `src/core/material_library.gd`
- Modify: `tests/test_core_stats.gd`

**Interfaces:**
- Produces `MaterialLibrary`:
  - `static func high_friction_physics(friction_val: float = 0.88, bounce_val: float = 0.12) -> PhysicsMaterial`
  - `static func make_beechwood_material(tint: Color = Color.WHITE) -> StandardMaterial3D`
  - `static func make_frosted_acrylic_material(tint: Color) -> StandardMaterial3D`
  - `static func make_wood_crate_material(is_heavy: bool) -> StandardMaterial3D`
  - `static func make_cast_iron_material(tint: Color = Color(0.28, 0.30, 0.35)) -> StandardMaterial3D`
  - `static func make_tungsten_ball_material() -> StandardMaterial3D`
  - `static func make_retro_barrel_material() -> StandardMaterial3D`
  - `static func make_silicone_soft_material(color: Color) -> StandardMaterial3D`
  - `static func make_jelly_outer_material(color: Color) -> StandardMaterial3D`
  - `static func make_jelly_core_material(color: Color) -> StandardMaterial3D`
  - `static func attach_weight_labels(target: Node3D, weight_text: String, box_size: Vector3, text_color: Color = Color(0.98, 0.96, 0.90)) -> void` (sets `target.set_meta("weight_label", weight_text)` unconditionally + builds `Label3D` on front `+Z` and top `+Y` when not headless)
  - `static func attach_anchored_flange_base(target: Node3D, local_y: float, half_x: float, half_z: float, show_fixed_label: bool = true) -> void` (sets `target.set_meta("is_anchored_fixed", true)` unconditionally + builds dark cast-iron flange plate, black-yellow hazard border, 4 silver hex bolts, and optional `"FIXED"` `Label3D` when not headless)

- [ ] **Step 1: Generate the 6 unified tabletop textures using `.agents/skills/gpt-image/scripts/generate.py`**

Create `assets/textures/` and run `python3 .agents/skills/gpt-image/scripts/generate.py` (can run in parallel batches, resize to `512x512` via `sips -Z 512` on macOS so Web export stays lightweight and crisp) for all 6 textures:
1. `track_beechwood.png`: Seamless top-down light warm natural beechwood plank tabletop marble-run track surface texture, clean fine grain, bright studio daylight, stylized toy craft aesthetic.
2. `crate_balsa_wood.png`: Square toy wooden building block face texture, warm light balsa/birch wood grain with subtle chamfered wooden frame border, clean miniature workshop style.
3. `metal_cast_iron.png`: Seamless dark matte hammered cast-iron calibration weight metal surface texture, subtle brushed industrial metallic sheen, clean stylized miniature look.
4. `anchor_hazard_stripe.png`: Clean diagonal yellow-and-charcoal-black industrial caution stripe texture, matte painted toy workshop finish, seamless tileable.
5. `barrel_retro_hazard.png`: Stylized toy tin barrel wrap texture, bright vermilion red and cream white horizontal bands with clean hazard stripes, crisp miniature craft look.
6. `jelly_bubble_soft.png`: Seamless translucent pastel lime-emerald gummy jelly texture with tiny suspended air bubbles, soft glossy candy surface.

- [ ] **Step 2: Write failing unit test for `MaterialLibrary` metadata and physics material helpers**

Add `_test_material_library_metadata_and_friction()` to `tests/test_core_stats.gd`:

```gdscript
func _test_material_library_metadata_and_friction() -> void:
	var lib_script: GDScript = load("res://src/core/material_library.gd")
	assert_true(lib_script != null, "MaterialLibrary script must exist")
	if lib_script == null:
		return

	var pmat: PhysicsMaterial = lib_script.high_friction_physics()
	assert_gt(pmat.friction, 0.80, "Tabletop resting physics material has high static friction (> tan 11 deg)")

	var dummy := Node3D.new()
	lib_script.attach_weight_labels(dummy, "20kg", Vector3(1.4, 1.4, 1.4))
	assert_eq(String(dummy.get_meta("weight_label", "")), "20kg", "attach_weight_labels records weight_label metadata")

	var fixed_dummy := Node3D.new()
	lib_script.attach_anchored_flange_base(fixed_dummy, -0.6, 0.8, 0.8, true)
	assert_true(bool(fixed_dummy.get_meta("is_anchored_fixed", false)), "attach_anchored_flange_base marks node anchored")
	dummy.free()
	fixed_dummy.free()
```

- [ ] **Step 3: Implement `src/core/material_library.gd` and run Godot `--headless --import`**

Implement `MaterialLibrary` with cached texture loading (`res://assets/textures/*.png`), triplanar/UV1 scaling, soft vs. hard `StandardMaterial3D` builders, `Label3D` stencil tags using `res://assets/fonts/game_ui_zh.ttf`, and 4-corner silver hex bolt flange bases.

- [ ] **Step 4: Run `./scripts/test.sh` to verify tests pass**

Run: `./scripts/test.sh`
Expected: PASS (all texture imports valid, `MaterialLibrary` tests green).

- [ ] **Step 5: Commit Task 2**

```bash
git add assets/textures/ src/core/material_library.gd tests/test_core_stats.gd
git commit -m "feat: generate tabletop textures via gpt-image and add MaterialLibrary"
```

---

### Task 3: Non-Dizzy Camera, Hold-to-Thrust Lateral Controller & Ball Direction/Weight HUD Ring

**Files:**
- Create: `src/gameplay/lateral_thrust_controller.gd`
- Modify: `src/gameplay/chase_camera_3d.gd`
- Modify: `src/gameplay/player_ball_3d.gd`
- Test: `tests/test_ball_and_gravity.gd`

**Interfaces:**
- `LateralThrustController`:
  - `const WORLD_GRAVITY := Vector3(0.0, -22.0, 0.0)`
  - `const BASE_LATERAL_ACCEL: float = 20.0`
  - `const AIR_LATERAL_FACTOR: float = 0.65`
  - `var current_axis: float = 0.0`
  - `func reset() -> void`
  - `func compute_lateral_accel(input_axis: float, lateral_mult: float = 1.0, is_airborne: bool = false) -> float` (returns `0.0` immediately when `absf(input_axis) < 0.01`)
  - `func apply_vertical_gravity_to_space(space_rid: RID) -> void`
- `ChaseCamera3D`:
  - `ROLL_FACTOR = 0.0`, `rotation_degrees.z == 0.0` always; `BASE_PITCH_DEG = -27.0`; `FOLLOW_OFFSET = Vector3(0.0, 5.2, 8.2)`.
- `PlayerBall3D`:
  - `var track_reference: Node3D = null` (optional sloped track root for `to_local` / `to_global` coordinate transforms; falls back to world identity when `null`)
  - `func step_ball(delta: float, thrust_axis: float, lateral_accel: float = 0.0) -> void`
  - Non-rotating `_hud_ring_root` displaying live weight text (`"1.5kg"`, `"2.5kg"`, etc., stored in `get_meta("weight_label")`) and left/right thrust directional arrow + airflow bars when `absf(thrust_axis) > 0.05`.

- [ ] **Step 1: Update `tests/test_ball_and_gravity.gd` with failing tests for zero camera roll, instant lateral start/stop, and sloped local respawn**

Update `tests/test_ball_and_gravity.gd` to verify:
1. `LateralThrustController.compute_lateral_accel(1.0, 1.0, false)` gives `+20.0`, and `compute_lateral_accel(0.0, 1.0, false)` **immediately** returns `0.0` on the very next call without lag.
2. `ChaseCamera3D` keeps `absf(cam.rotation_degrees.z) < 0.001` even under full lateral input while still widening `fov` at high speed.
3. `PlayerBall3D` updates `get_meta("weight_label")` when `tungsten_core` / `giant_field` are applied (`"1.5kg"` -> `"3.8kg"`), applies lateral thrust only while `thrust_axis != 0`, and detects abyss fall accurately in `track_reference` local coordinates on a `-11°` sloped parent.

- [ ] **Step 2: Run `./scripts/test.sh` to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL.

- [ ] **Step 3: Implement `LateralThrustController`, zero-roll `ChaseCamera3D`, and upgraded `PlayerBall3D`**

Implement `src/gameplay/lateral_thrust_controller.gd`, update `src/gameplay/chase_camera_3d.gd` (`ROLL_FACTOR = 0.0`), and update `src/gameplay/player_ball_3d.gd` with:
- Polished tungsten-steel sphere visual + subtle equatorial groove bands;
- Top-level / counter-rotated `_hud_ring_root` holding the floating weight tag (`"1.5kg"`) and translucent cyan/amber left `◀` / right `▶` arrow + 3 jet puff bars;
- Track-local height/fall/respawn math (`_to_track_local`, `_to_track_world`) and slope-aligned forward rolling assist (`3.2 * mass * forward_drive_mult`) + lateral force (`lateral_accel * mass`) + gentle lateral stop damping when `absf(thrust_axis) < 0.05`.

- [ ] **Step 4: Run `./scripts/test.sh` to verify tests pass**

Run: `./scripts/test.sh`
Expected: PASS on `test_ball_and_gravity.gd`.

- [ ] **Step 5: Commit Task 3**

```bash
git add src/gameplay/lateral_thrust_controller.gd src/gameplay/chase_camera_3d.gd src/gameplay/player_ball_3d.gd tests/test_ball_and_gravity.gd
git commit -m "feat: replace tilt roll with zero-dizzy camera and hold-to-thrust ball controller"
```

---

### Task 4: Weighted RigidBodies (`500g`–`20kg`), Soft/Hard Visuals, Bolted Flange Bases & Vertical Entities (`SpringPad`, `AerialBonusRing`, `AerialBlocker`)

**Files:**
- Modify: `src/track/entities/crate_obstacle.gd`
- Modify: `src/track/entities/bouncer_slime.gd`
- Modify: `src/track/entities/shield_brute.gd`
- Modify: `src/track/entities/explosive_barrel.gd`
- Modify: `src/track/entities/pinball_bumper.gd`
- Modify: `src/track/entities/boost_pad.gd`
- Modify: `src/track/entities/slime_zone.gd`
- Create: `src/track/entities/spring_pad.gd`
- Create: `src/track/entities/aerial_bonus_ring.gd`
- Create: `src/track/entities/aerial_blocker.gd`
- Modify: `src/track/entities/track_entity_factory.gd`
- Test: `tests/test_entities.gd`

**Interfaces:**
- `CrateObstacle`:
  - `var weight_tier: String = "light"` (`"light"` -> `0.5 kg`, `"500g"`, `smash_momentum = 10.0`; `"medium"` -> `2.5 kg`, `"2.5kg"`, `smash_momentum = 18.0`; default factory `create_crate(pos, tier = "light")` and `create_heavy_crate(pos)`).
- `ShieldBrute` (20kg Cast-Iron Weight):
  - Extends `RigidBody3D`! `mass = 20.0`, high friction `0.92`, stepped cast-iron body + top grip ring, `weight_label == "20kg"`, `SMASH_MOMENTUM = 42.0`.
- `BouncerSlime`:
  - Dual-layer translucent jelly + squash-and-stretch visual animation + `weight_label == "3kg"`.
- `ExplosiveBarrel`:
  - Extends `RigidBody3D` (`mass = 1.5`, `weight_label == "1.5kg"`), detonates on ball contact OR fast rigidbody impact (`speed > 2.8`).
- `PinballBumper`:
  - Anchored flange base (`is_anchored_fixed == true`, `"FIXED"`) + matte silicone bounce cushion ring.
- `SpringPad` (`Area3D`):
  - Anchored flange base + yellow coil + silicone pad; `interact_with_ball(ball)` sets/adds track-upward launch velocity (`+11.5 m/s`) and forward boost (`6.5 * ball.mass`).
- `AerialBonusRing` (`Area3D`):
  - `signal ring_collected(bonus_seconds: float)`
  - Grants `+0.8s` and `15.0 * ball.mass` forward boost via `ball.notify_external_boost(...)`.
- `AerialBlocker` (`Node3D`):
  - `var blocker_type: String = "soft_balloon"` (`"soft_balloon"` -> `"2kg"`, `smash_momentum = 18.0`; `"mag_iron"` -> `"12kg"`, `smash_momentum = 36.0`)
  - `var initial_phase: float = 0.0` (deterministic bobbing/swaying phase).

- [ ] **Step 1: Extend `tests/test_entities.gd` with failing tests for weight tiers, labels, anchored flags, `SpringPad`, `AerialBonusRing`, and `AerialBlocker`**

Verify in `tests/test_entities.gd`:
1. Light crate (`500g`, `mass == 0.5`) vs Medium crate (`2.5kg`, `mass == 2.5`) vs ShieldBrute (`20kg`, `mass == 20.0` `RigidBody3D`) vs ExplosiveBarrel (`1.5kg`) vs BouncerSlime (`3kg`) all expose exact `weight_label` metadata and momentum thresholds.
2. `PinballBumper` and `SpringPad` expose `is_anchored_fixed == true`.
3. `SpringPad.interact_with_ball(ball)` launches `ball.linear_velocity.y > 10.0`.
4. `AerialBonusRing.interact_with_ball(ball)` emits `ring_collected(0.8)` and boosts forward `-Z` speed.
5. `AerialBlocker` (`"soft_balloon"` `2kg` vs `"mag_iron"` `12kg`) blocks/deflects low-momentum aerial balls and smashes when momentum exceeds threshold.

- [ ] **Step 2: Run `./scripts/test.sh` to verify tests fail**

Run: `./scripts/test.sh`
Expected: FAIL.

- [ ] **Step 3: Implement all upgraded tabletop entities and the 3 new vertical entities + `TrackEntityFactory` builders**

Implement clean, modular scripts under `src/track/entities/` using `MaterialLibrary` textures, soft/hard shaders, `attach_weight_labels`, and `attach_anchored_flange_base`.

- [ ] **Step 4: Run `./scripts/test.sh` to verify entity tests pass**

Run: `./scripts/test.sh`
Expected: PASS on `test_entities.gd`.

- [ ] **Step 5: Commit Task 4**

```bash
git add src/track/entities/ tests/test_entities.gd
git commit -m "feat: upgrade obstacles with real weights/labels/bolts and add vertical spring, bonus ring, and aerial blockers"
```

---

### Task 5: `-11°` Sloped Beechwood Track, `WaveHills` Chunk, Side Launch Ramps & Deterministic Spawning

**Files:**
- Modify: `src/track/track_chunk_base.gd`
- Modify: `src/track/track_generator_3d.gd`
- Test: `tests/test_track_generator.gd`

**Interfaces:**
- `TrackChunkBase`:
  - Supports `"WaveHills"` chunk (`length = 30.0`, two smooth undulating beechwood hills peaking at `+1.45 m` local Y).
  - `func add_side_launch_ramp(local_pos: Vector3, width: float = 2.4) -> StaticBody3D` (`16°` frosted cyan acrylic ramp with anchored flange base).
  - Beechwood track floor slabs + frosted acrylic guard rails with periodic anchored flange stanchions.
- `TrackGenerator3D`:
  - `const TRACK_SLOPE_PITCH_DEG: float = -11.0`
  - `signal bonus_ring_collected(seconds: float)`
  - `func get_track_root() -> Node3D`
  - `func world_to_track_local(world_pos: Vector3) -> Vector3`
  - `func track_local_to_world(local_pos: Vector3) -> Vector3`

- [ ] **Step 1: Add failing tests in `tests/test_track_generator.gd` for `-11°` slope, `WaveHills` chunk, vertical entities, and 100% deterministic multi-level seed layout**

Add tests verifying:
1. `gen.get_track_root().rotation_degrees.x` is `-11.0`, so `track_local_to_world(Vector3(0, 0, -100)).y < -18.0`.
2. `"WaveHills"` spawns in the chunk pool starting from Level 1.
3. Generated tracks include `SpringPad`, `AerialBonusRing`, and `AerialBlocker` entities.
4. Two independent `generate_track(level, RunState.derive_track_seed(seed, level))` calls with the same seed produce **identical chunk type arrays, entity counts, entity classes, and exact local positions** on both Level 1 and Level 2, while a different seed produces a different layout.

- [ ] **Step 2: Run `./scripts/test.sh` to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL.

- [ ] **Step 3: Implement `TrackChunkBase` (`WaveHills`, beechwood/acrylic materials, side launch ramps, bolted stanchions) and `TrackGenerator3D` (`-11°` slope & deterministic vertical/ground population)**

Ensure every `AerialBlocker` receives `rng.randf_range(0.0, TAU)` for `initial_phase` from the chunk's `rng`, and every `CrateObstacle` deterministically rolls `"light"` (`500g`) vs `"medium"` (`2.5kg`). Wire `AerialBonusRing.ring_collected` -> `bonus_ring_collected.emit`.

- [ ] **Step 4: Run `./scripts/test.sh` to verify track generator tests pass**

Run: `./scripts/test.sh`
Expected: PASS on `test_track_generator.gd`.

- [ ] **Step 5: Commit Task 5**

```bash
git add src/track/track_chunk_base.gd src/track/track_generator_3d.gd tests/test_track_generator.gd
git commit -m "feat: build real 11-deg sloped beechwood track, WaveHills chunk, and deterministic aerial/ground spawning"
```

---

### Task 6: Bright Workshop Lighting, Seed UI (`HudOverlay` & `RunSummaryPanel`), `GameWorld3D` Wiring & Live Visual Verification

**Files:**
- Modify: `src/ui/hud_overlay.gd`
- Modify: `src/ui/run_summary_panel.gd`
- Modify: `src/gameplay/game_world_3d.gd`
- Test: `tests/test_game_loop.gd`

**Interfaces:**
- `HudOverlay`:
  - `signal seed_submitted(seed_text: String)`
  - `signal seed_dialog_toggled(is_open: bool)`
  - Displays `种子: <seed_text> [填入种子]`, `[ ◀ 左推 | 右推 ▶ ]` live lateral thrust indicators, and modal `LineEdit` seed input popup (`N` shortcut or button click).
- `RunSummaryPanel`:
  - `signal restart_same_seed_requested`
  - `signal restart_custom_seed_requested(seed_text: String)`
  - Shows current `seed_text`, button `"新随机种子挑战（空格/回车）"`, button `"同种子重玩本局"`, and custom seed `LineEdit` + `"按此种子开局"`.
- `GameWorld3D`:
  - Bright tabletop studio lighting (`ProceduralSkyMaterial` warm daylight + soft fill + shadows).
  - Constant vertical space gravity `(0, -22.0, 0)` via `LateralThrustController`.
  - Uses `RunState.derive_track_seed(run_state.run_seed, level)` for track generation and `RunState.derive_draft_seed(run_state.run_seed, run_state.current_level)` for `roll_draft_choices`.
  - `func restart_run_with_seed_text(raw_text: String) -> void`

- [ ] **Step 1: Add failing integration tests in `tests/test_game_loop.gd`**

Add integration assertions verifying:
1. Global space gravity vector is strictly `Vector3(0, -1, 0)` (magnitude `22.0`), camera `rotation_degrees.z == 0.0`, and `PlayerBall3D` naturally rolls downhill along the `-11°` sloped track while unhit `500g` / `20kg` rigidbodies remain stationary on the slope (displacement `< 0.15 m` over 30 physics frames).
2. `world.restart_run_with_seed_text("TABLETOP2026")` reproduces the exact same Level 1 track chunks, Level 1 3-card draft choices, Level 2 track chunks, and Level 2 3-card draft choices across two independent runs (even if Run A picks card 0 and Run B picks a different stackable common card on Level 1!).
3. Picking a non-stackable legendary card on Level 1 excludes it on Level 2 while keeping Level 2 terrain 100% identical.

- [ ] **Step 2: Run `./scripts/test.sh` to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL.

- [ ] **Step 3: Implement `HudOverlay`, `RunSummaryPanel`, and `GameWorld3D` upgrades**

Wire bright studio sky/sunlight, `LateralThrustController`, track-local progress & finish detection, `bonus_ring_collected` (`+0.8s`), `SEED_INPUT` modal pause state, and deterministic sub-seed draft/track calls.

- [ ] **Step 4: Run full headless test suite, Web export build, and capture live rendered screenshots**

Run:
1. `./scripts/test.sh` -> Expected: `TEST SUMMARY: PASS` (all 6 suites, 0 failures).
2. `./scripts/build-web.sh` -> Expected: clean HTML5 export in `build/web/`.
3. Launch native Godot window or Playwright on `build/web/` to capture gameplay screenshots showing:
   - Bright beechwood & frosted acrylic track with zero horizon tilt;
   - `500g`, `2.5kg`, `20kg` labeled rigidbodies, translucent `3kg` jelly slimes, bolted `FIXED` flange bases;
   - Ball `1.5kg` tag + lateral thrust directional arrow + HUD seed pill;
   - Vertical ramps, `SpringPad`, suspended `AerialBonusRing`, and floating `2kg`/`12kg` `AerialBlocker`.

- [ ] **Step 5: Commit Task 6**

```bash
git add src/ui/hud_overlay.gd src/ui/run_summary_panel.gd src/gameplay/game_world_3d.gd tests/test_game_loop.gd
git commit -m "feat: integrate bright workshop lighting, seed input UI, and deterministic tabletop game loop"
```
