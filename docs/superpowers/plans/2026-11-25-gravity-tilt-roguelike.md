# 《给我滚》Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete, playable Godot 4.3 3D physics-based roguelike game where players tilt world gravity Left/Right (`±35°`) to race down procedurally generated obstacle/monster tracks within a 30-second timer and draft multiplicative, emergent physics upgrades between levels.

**Architecture:** Pure data-driven core (`StatSheet`, `RunState`, `PhysicsSynergyBus`, `UpgradeCatalog`) decoupled from Godot 3D scene orchestration (`GravityTiltController`, `PlayerBall3D`, `TrackGenerator3D`, `GameWorld3D`, and UI panels). Equivalent tilted 3D gravity is applied directly to the world physics space (`PhysicsServer3D`) to drive both the player ball and dynamic rigid-body obstacles without track-whip artifacts, while all upgrade synergies emerge naturally from real momentum ($P = m v$) and kinetic energy ($E_k = \frac{1}{2} m v^2$) equations routed through a recursion-guarded event bus.

**Tech Stack:** Godot 4.3 (`gl_compatibility` renderer), GDScript 2.0 (strict static typing), Godot Physics 3D (`RigidBody3D`, `Area3D`, `PhysicsServer3D`), Godot Headless CLI test runner (`scripts/test.sh`).

## Global Constraints

- Engine target: Godot `4.3.stable` (`gl_compatibility` rendering method, `1280x720` base viewport).
- Controls during racing: strictly **Left (`A` / `Left`)** and **Right (`D` / `Right`)** only. Draft and summary screens support keyboard (`Left`/`Right` + `Enter`/`Space`, or `1`/`2`/`3`) and mouse click.
- Coordinate convention: `-Z` is forward down-slope, `+X` is right, `-X` is left, `+Y` is upward normal.
- Base slope pitch: `11.0°`, base gravity magnitude `g0 = 22.0 m/s²`, default max lateral tilt `35.0°` (clamped up to `55.0°`).
- Timer & progression: `30.0s` base countdown per level (capped at `45.0s`), target track length `L(n) = 130 + (n - 1) * 55 + int((n - 1) / 3) * 25` meters.
- Safety guardrails: `continuous_cd = true` on `PlayerBall3D`, max synergy chain recursion `chain_depth <= 3`, single-frame bonus velocity delta cap `45.0 m/s`, max ball speed `85.0 m/s`, fall pull-back `1.2s` when `8.0m` below floor while timer continues running.

---

### Task 1: Godot 4.3 Project Scaffold & Headless Test Harness

**Files:**
- Create: `.gitignore`
- Create: `project.godot`
- Create: `icon.svg`
- Create: `scripts/test.sh`
- Create: `tests/test_base.gd`
- Create: `tests/run_tests.gd`

**Interfaces:**
- Consumes: Godot 4.3 CLI (`godot --headless`)
- Produces: `TestBase` assertion helper (`assert_true`, `assert_eq`, `assert_approx`, `assert_gt`, `assert_lt`) and `scripts/test.sh` returning exit code `0` on all pass or `1` on any failure.

- [ ] **Step 1: Create `.gitignore`, `project.godot`, `icon.svg`, and headless test runner**

Create `.gitignore`:
```gitignore
.godot/
build/
*.import
.DS_Store
```

Create `project.godot` configuring `gl_compatibility`, `1280x720` window, `move_left` / `move_right` / `ui_pick_1` / `ui_pick_2` / `ui_pick_3` actions, and `run/main_scene="res://scenes/main.tscn"`.

Create `tests/test_base.gd` and `tests/run_tests.gd` extending `SceneTree` to discover and run registered test suites and exit with nonzero status on any failure.

Create `scripts/test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . -s res://tests/run_tests.gd
```

- [ ] **Step 2: Run `./scripts/test.sh` to verify harness executes cleanly**

Run: `chmod +x scripts/test.sh && ./scripts/test.sh`
Expected: `PASS: 1/1 suites passed (0 failures)` with exit code `0`.

- [ ] **Step 3: Commit scaffold**

```bash
git add .gitignore project.godot icon.svg scripts/test.sh tests/test_base.gd tests/run_tests.gd
git commit -m "chore: scaffold Godot 4.3 project and headless TDD runner"
```

---

### Task 2: Dual-Multiplier `StatSheet` & `RunState` Progression

**Files:**
- Create: `src/core/stat_sheet.gd`
- Create: `src/core/run_state.gd`
- Create: `tests/test_core_stats.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `TestBase`
- Produces:
  - `StatSheet`:
    - `get_stat(key: String) -> float` computing `clamp((base + sum_flat) * prod(1.0 + mult), min_val, max_val)`
    - `add_flat(key: String, amount: float) -> void`
    - `add_mult(key: String, ratio: float) -> void`
    - `set_flag(flag: String, enabled: bool) -> void` / `has_flag(flag: String) -> bool`
    - `reset_modifiers() -> void`
  - `RunState`:
    - `current_level: int`, `time_remaining: float`, `owned_upgrade_ids: Array[String]`, `peak_speed_kmh: float`, `max_kinetic_energy: float`, `total_smashed: int`
    - `static func target_length_for_level(level: int) -> float`
    - `start_new_run() -> void`, `begin_level(level: int) -> void`, `tick_timer(delta: float) -> bool`, `add_bonus_time(seconds: float) -> void`, `record_physics_sample(speed_mps: float, kinetic_energy: float) -> void`

- [ ] **Step 1: Write failing unit tests in `tests/test_core_stats.gd`**

Test cases:
- Default stat values (`mass == 1.5`, `radius == 0.55`, `max_tilt_deg == 35.0`, `bounce == 0.25`, `linear_damp == 0.35`).
- Multiplicative synergy formula: `(1.5 + 0.8) * (1.0 + 0.65) * (1.0 + 0.20)` equals `4.554`, and min/max clamping (`bounce` capped at `1.0`, `max_tilt_deg` capped at `55.0`).
- `RunState.target_length_for_level`: Level 1 -> `130.0`, Level 5 -> `375.0`, Level 10 -> `700.0`, strictly increasing.
- Timer countdown reaches `0.0` and `add_bonus_time` clamps at `45.0s`.

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL because `stat_sheet.gd` and `run_state.gd` do not exist yet.

- [ ] **Step 3: Implement `src/core/stat_sheet.gd` and `src/core/run_state.gd`**

Implement clean, strictly typed `RefCounted` classes matching all stat keys and limits from Section 3.1 and Section 5.1 of the design spec.

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN pass**

Run: `./scripts/test.sh`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/core/stat_sheet.gd src/core/run_state.gd tests/test_core_stats.gd tests/run_tests.gd
git commit -m "feat: add dual-multiplier StatSheet and RunState progression"
```

---

### Task 3: `PhysicsSynergyBus` & 12 Orthogonal Atomic Upgrades (`UpgradeCatalog`)

**Files:**
- Create: `src/core/physics_event_context.gd`
- Create: `src/upgrades/upgrade_definition.gd`
- Create: `src/upgrades/upgrade_catalog.gd`
- Create: `src/core/physics_synergy_bus.gd`
- Create: `tests/test_synergy_and_upgrades.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `StatSheet`, `RunState`
- Produces:
  - `PhysicsEventContext`: snapshot of `speed`, `lateral_speed`, `tilt_deg`, `mass`, `momentum`, `kinetic_energy`, `vertical_impact`, `impact_normal`, `world_pos`, `combo_stacks`, `chain_depth`.
  - `UpgradeDefinition`: data object for an atomic upgrade (`id`, `title`, `rarity`, `layer`, `description`, `stat_flats`, `stat_mults`, `flags`).
  - `UpgradeCatalog`: all 12 spec upgrades + `roll_draft_choices(rng: RandomNumberGenerator, count: int, owned_ids: Array[String]) -> Array[UpgradeDefinition]`.
  - `PhysicsSynergyBus`:
    - `apply_upgrade(def: UpgradeDefinition) -> void`, `rebuild_stats() -> void`
    - `on_physics_tick(ctx: PhysicsEventContext, delta: float) -> Dictionary`
    - `on_land(ctx: PhysicsEventContext) -> Dictionary`
    - `on_wall_or_bumper_bounce(ctx: PhysicsEventContext) -> Dictionary`
    - `on_smash_target(ctx: PhysicsEventContext) -> Dictionary`
    - `on_boost_pad(ctx: PhysicsEventContext) -> Dictionary`
    - Each dispatch returns an action dictionary `{"forward_impulse": float, "shockwaves": Array[Dictionary], "bonus_time": float}` with `chain_depth <= 3` and single-frame velocity delta clamped to `45.0 * mass`.

- [ ] **Step 1: Write failing tests in `tests/test_synergy_and_upgrades.gd`**

Test cases:
- Catalog contains all 12 orthogonal upgrades across 3 layers; `roll_draft_choices` returns 3 distinct upgrades.
- Emergent `1 + 1 > 2` verification:
  1. **Frog-Slam synergy**: `tungsten_core` + `vulcan_rubber` + `quake_refractor` produces dramatically higher forward landing impulse than `quake_refractor` alone.
  2. **Wall-Drift synergy**: `vector_refractor` + `momentum_overload` converts wall hits into forward impulse that scales multiplicatively as Overload stacks climb toward 20 (`3.4x` at 20 stacks) and decays after `2.5s` idle.
  3. **Kinetic-Blast + Twin-Resonance**: `kinetic_furnace` shockwave force scales with $\sqrt{E_k}$, and adding `twin_resonance` doubles converter output (`×2`).
  4. **Guardrails**: `chain_depth >= 3` suppresses further shockwave spawning; extreme kinetic energy clamps single-dispatch forward velocity delta to `<= 45.0 m/s`.

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL on missing classes.

- [ ] **Step 3: Implement `physics_event_context.gd`, `upgrade_definition.gd`, `upgrade_catalog.gd`, and `physics_synergy_bus.gd`**

Implement data-driven upgrade registration and clean synergy dispatch pipeline without hardcoded archetype checks.

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN pass**

Run: `./scripts/test.sh`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/core/physics_event_context.gd src/upgrades/upgrade_definition.gd src/upgrades/upgrade_catalog.gd src/core/physics_synergy_bus.gd tests/test_synergy_and_upgrades.gd tests/run_tests.gd
git commit -m "feat: implement PhysicsSynergyBus and 12 emergent atomic upgrades"
```

---

### Task 4: `GravityTiltController`, `PlayerBall3D`, and `ChaseCamera3D`

**Files:**
- Create: `src/gameplay/gravity_tilt_controller.gd`
- Create: `src/gameplay/player_ball_3d.gd`
- Create: `src/gameplay/chase_camera_3d.gd`
- Create: `tests/test_ball_and_gravity.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `StatSheet`, `PhysicsSynergyBus`, `PhysicsEventContext`
- Produces:
  - `GravityTiltController`: `update_tilt(input_axis: float, max_tilt_deg: float, delta: float) -> Vector3`, `current_tilt_deg: float`, `compute_gravity_vector(tilt_deg: float, g_scale: float) -> Vector3`, `apply_to_space(space_rid: RID, gravity_vec: Vector3) -> void`
  - `PlayerBall3D` (`RigidBody3D`): syncs physical `mass`, sphere collision/mesh `radius`, `PhysicsMaterial` `bounce`, `linear_damp`, `continuous_cd = true`; resolves obstacle momentum checks; detects landing (`air_time > 0.25s`), fall respawn (`1.2s` pull-back), and low-speed stuck nudge (`< 0.6 m/s` for `1.8s`).
  - `ChaseCamera3D` (`Camera3D`): smooth position follow, visual roll `-0.55 * tilt_deg`, speed-scaled FOV `65.0 ~ 88.0`, and trauma shake `add_shake(amount: float)`.

- [ ] **Step 1: Write failing 3D physics tests in `tests/test_ball_and_gravity.gd`**

Test cases:
- `GravityTiltController` clamps tilt strictly within `[-max_tilt_deg, +max_tilt_deg]`, returns to `0°` when `input_axis == 0`, and keeps gravity magnitude constant at `22.0 m/s²`.
- `PlayerBall3D` syncs `mass`, `radius`, and `bounce` from `StatSheet`, enables `continuous_cd`, triggers `is_respawning` for `1.2s` when dropping below `safe_floor_y - 8.0`, and clamps max speed to `85.0 m/s`.
- `ChaseCamera3D` rolls opposite to tilt angle and increases `fov` as ball speed grows.

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL on missing gameplay scripts.

- [ ] **Step 3: Implement `gravity_tilt_controller.gd`, `player_ball_3d.gd`, and `chase_camera_3d.gd`**

Implement smooth 3D physics integration and procedural visual meshes/materials for the player ball.

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN pass**

Run: `./scripts/test.sh`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/gameplay/gravity_tilt_controller.gd src/gameplay/player_ball_3d.gd src/gameplay/chase_camera_3d.gd tests/test_ball_and_gravity.gd tests/run_tests.gd
git commit -m "feat: add GravityTiltController, PlayerBall3D, and ChaseCamera3D"
```

---

### Task 5: 7 Momentum-Interactive Track Entities (Obstacles, Monsters & Boosters)

**Files:**
- Create: `src/track/entities/track_entity_factory.gd`
- Create: `src/track/entities/crate_obstacle.gd`
- Create: `src/track/entities/slime_zone.gd`
- Create: `src/track/entities/bouncer_slime.gd`
- Create: `src/track/entities/shield_brute.gd`
- Create: `src/track/entities/boost_pad.gd`
- Create: `src/track/entities/pinball_bumper.gd`
- Create: `src/track/entities/explosive_barrel.gd`
- Create: `tests/test_entities.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `PlayerBall3D`, `PhysicsSynergyBus`
- Produces:
  - Standardized interaction methods invoked on collision/area overlap with `PlayerBall3D` and shockwaves (`apply_shockwave(origin: Vector3, radius: float, force: float, chain_depth: int)`).
  - Exact momentum thresholds from spec Section 4: `CrateObstacle` (`14.0`), `BouncerSlime` (`22.0`), `ShieldBrute` (`42.0`), `SlimeZone` (`+3.5` damp unless immune), `BoostPad` (`18.0 * mass`), `PinballBumper` (`14.0 * mass`), `ExplosiveBarrel` (`6.5m` radial blast).

- [ ] **Step 1: Write failing entity interaction tests in `tests/test_entities.gd`**

Test cases:
- `CrateObstacle`: low momentum (`P = 8.0`) does not shatter; high momentum (`P = 20.0`) shatters crate, reduces speed by `8% * smash_speed_loss_mult`, and emits smash signal.
- `BouncerSlime`: low momentum (`P = 12.0`) knocks ball backward (`+Z`); high momentum (`P = 28.0`) smashes slime.
- `ShieldBrute`: requires `P >= 42.0` to smash on direct hit, or breaks immediately from shockwave/barrel explosion.
- `SlimeZone`: increases ball effective damp unless `immune_slime_damp` flag is active on `StatSheet`.
- `BoostPad`, `PinballBumper`, and `ExplosiveBarrel`: boost forward `-Z` velocity scaled by `external_boost_mult`, and barrel explosion chain-smashes nearby crates/monsters.

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL on missing entity scripts.

- [ ] **Step 3: Implement all 7 entity scripts and `track_entity_factory.gd`**

Build stylized procedural 3D meshes with distinct readable colors (amber crates, toxic green slime zones/bouncers, crimson-armored shield brutes, cyan chevron boost pads, magenta neon bumpers, bright orange hazard barrels).

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN pass**

Run: `./scripts/test.sh`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/track/entities/ tests/test_entities.gd tests/run_tests.gd
git commit -m "feat: implement 7 momentum-driven obstacles, monsters, and boosters"
```

---

### Task 6: Modular `TrackChunkBase` & Procedural `TrackGenerator3D`

**Files:**
- Create: `src/track/track_chunk_base.gd`
- Create: `src/track/track_generator_3d.gd`
- Create: `tests/test_track_generator.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `RunState`, `TrackEntityFactory`
- Produces:
  - `TrackChunkBase` (`Node3D`): constructs geometry for all 6 chunk templates (`StraightWide`, `NarrowBridge`, `SplitPath`, `RampGap`, `PinballAlley`, `FunnelGauntlet`), exposes `chunk_type`, `length`, `entry_z`, `exit_z`, `floor_y_at(z)`, `safe_respawn_pos`, and spawn slots.
  - `TrackGenerator3D` (`Node3D`): `generate_track(level: int, seed_val: int) -> Dictionary` returning `{"total_length": float, "finish_z": float, "chunks": Array[TrackChunkBase], "entities": Array[Node3D]}` plus a glowing Finish Archway `Area3D`.

- [ ] **Step 1: Write failing procedural generation tests in `tests/test_track_generator.gd`**

Test cases:
- Generated track `total_length` meets or exceeds `RunState.target_length_for_level(level)` for Levels 1, 3, 6, and 10, and strictly increases across levels.
- Chunks align seamlessly end-to-end (`chunk[i].exit_z == chunk[i+1].entry_z`) with zero gaps except intentional `RampGap` chasm (which includes side auxiliary bridges).
- `FunnelGauntlet` only spawns on `level >= 3`, while all 6 chunk types appear across seeded runs by Level 5.

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL on missing track generator scripts.

- [ ] **Step 3: Implement `src/track/track_chunk_base.gd` and `src/track/track_generator_3d.gd`**

Implement all 6 chunk geometries with `StaticBody3D` colliders, glowing guide rails, ramps, split paths, and level-scaled obstacle/monster/booster placement.

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN pass**

Run: `./scripts/test.sh`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/track/track_chunk_base.gd src/track/track_generator_3d.gd tests/test_track_generator.gd tests/run_tests.gd
git commit -m "feat: add 6 modular 3D track chunks and procedural TrackGenerator3D"
```

---

### Task 7: `GameWorld3D` Loop, Arcade `HudOverlay`, `UpgradeDraftPanel`, & `RunSummaryPanel`

**Files:**
- Create: `src/ui/hud_overlay.gd`
- Create: `src/ui/upgrade_draft_panel.gd`
- Create: `src/ui/run_summary_panel.gd`
- Create: `src/gameplay/game_world_3d.gd`
- Create: `scenes/main.tscn`
- Create: `tests/test_game_loop.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: all core, upgrade, gameplay, and track modules
- Produces:
  - Complete playable scene `res://scenes/main.tscn` orchestrated by `GameWorld3D`:
    - States: `RACING`, `DRAFTING`, `GAME_OVER`
    - Pure **Left / Right** input during `RACING`; keyboard (`Left`/`Right` to select card + `Space`/`Enter` or `1`/`2`/`3`) + mouse support during `DRAFTING`; instant restart on `GAME_OVER`.
    - Live HUD displaying 30.0s countdown, speed in `km/h`, momentum $P$, Overload stacks, track progress bar, active build badges, and level banner.
    - Physical + visual radial shockwave execution (`emit_shockwave`) with `chain_depth` propagation.

- [ ] **Step 1: Write failing integration tests in `tests/test_game_loop.gd`**

Test cases:
- Instantiating `res://scenes/main.tscn` starts at Level 1 in `RACING` state with `30.0s` timer; stepping physics without input rolls the ball forward along `-Z` down the sloped gravity field.
- Crossing `finish_z` transitions `GameWorld3D` to `DRAFTING` and presents 3 distinct upgrade choices; selecting one applies the upgrade, advances to Level 2 with longer `finish_z`, and resets timer to `30.0s`.
- Letting the timer expire transitions `GameWorld3D` to `GAME_OVER`, and triggering restart cleanly resets to Level 1 with empty upgrades.

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL on missing `scenes/main.tscn` and `game_world_3d.gd`.

- [ ] **Step 3: Implement UI panels, `game_world_3d.gd`, and `scenes/main.tscn`**

Implement crisp Chinese arcade UI (using clean vector/PanelContainer styling and Godot default system CJK font fallback), lighting/environment, shockwave ring VFX, and full state machine.

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN pass**

Run: `./scripts/test.sh`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/ui/ src/gameplay/game_world_3d.gd scenes/main.tscn tests/test_game_loop.gd tests/run_tests.gd
git commit -m "feat: wire GameWorld3D state machine, arcade HUD, draft UI, and main scene"
```

---

### Task 8: Emergent Synergy End-to-End Simulation, Web Export Preview & `README.md`

**Files:**
- Modify: `tests/test_game_loop.gd` (add multi-frame 3D physics emergent build benchmark test)
- Create: `export_presets.cfg`
- Create: `README.md`

**Interfaces:**
- Consumes: complete Godot 4.3 project
- Produces:
  - End-to-end 3D simulation proof that emergent upgrade combos dramatically outpace a baseline unupgraded ball on an identical seeded track.
  - `README.md` documenting gameplay, controls, emergent synergy architecture, how to add new cards/chunks, and local run/test commands.
  - Local Web HTML5 export in `build/web/` (gitignored) verified cleanly so it is playable both in Godot 4 Editor and browser.

- [ ] **Step 1: Add end-to-end 3D emergent build benchmark test and verify with `./scripts/test.sh`**

Simulate 180 physics frames on a seeded track comparing baseline ball distance vs upgraded ball (`tungsten_core` + `kinetic_furnace` + `tail_thruster` + `momentum_overload`), asserting the upgraded build covers significantly greater `-Z` distance and triggers chain smashes without errors.

- [ ] **Step 2: Write `README.md` and `export_presets.cfg` (Web single-threaded `gl_compatibility`)**

Document project overview, controls, emergent 3-layer synergy extension guide, and CLI test command `./scripts/test.sh`.

- [ ] **Step 3: Run full verification gate (`./scripts/test.sh` + clean Godot boot check) and commit/push**

Run: `./scripts/test.sh`
Expected: All test suites PASS with 0 errors and 0 warnings.

```bash
git add README.md export_presets.cfg tests/test_game_loop.gd
git commit -m "docs: add README, Web export preset, and end-to-end emergent build verification"
git push -u origin main
```
