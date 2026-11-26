# Real-Physics Persistent Obstacles & Wooden Pin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert all track obstacles in 《给我滚》 into persistent native Jolt `RigidBody3D` entities governed by real Newtonian mass ratios and 3D collision geometry without timed disappearance, adjust unbalanced weights/sensors (`250g` balloon, `2kg` angled crate, `0.45kg EMPTY` barrel husk, surface-contact `PinballBumper`), add the `800g` `WoodenPin` toppling obstacle, and bridge real contact impulses cleanly to all 12 roguelike upgrades.

**Architecture:** Every movable obstacle (`CrateObstacle`, `WoodenPin`, `ShieldBrute`, `BouncerSlime`, `AerialBlocker`, `ExplosiveBarrel`) extends `RigidBody3D` on `collision_layer = 1, collision_mask = 1` with no oversized `Area3D` interception sensors and no `0.75s` `queue_free()` timers; entities rest on the `-11°` beechwood slope via high static friction (`0.72–0.88 > tan 11°`), switch to realistic low air damping (`0.10–0.48`) once dislodged, and only clean up if they fall deep into the abyss (`track_local.y < -28.0m`). `PlayerBall3D._integrate_forces` inspects native Jolt 3D contacts each physics tick to compute real contact impulses and normal rebound deltas—leaving base ball velocity 100% solver-driven while triggering single-time `on_smash_target` events, heavy/jelly `on_wall_or_bumper_bounce` events, and `tungsten_core` proportional forward-loss recovery.

**Tech Stack:** Godot 4.6 (`gl_compatibility` renderer, Jolt Physics 3D, GDScript), Headless test suite (`./scripts/test.sh`), Web HTML5 export pipeline (`./scripts/build-web.sh`).

## Global Constraints

- Engine & Renderer: Godot 4.6 `gl_compatibility` + Jolt Physics 3D; must pass both headless automated tests (`./scripts/test.sh`) and Web HTML5 export (`./scripts/build-web.sh`).
- Headless Safety: Guard all mesh/font/texture attachment via `DisplayServer.get_name() == "headless"` / `MaterialLibrary` / `RenderHelper` while always building real `CollisionShape3D` nodes and metadata (`weight_label`, `is_anchored_fixed`) in headless mode.
- Determinism: Zero unseeded global `randf()` / `randi()` calls anywhere in `src/`. All track entity placements, crate yaw rotations, pin clusters, and aerial phases must draw deterministically from the `RandomNumberGenerator` seeded by `RunState.derive_track_seed(run_seed, level)`.
- Pure Newtonian Collision: Base `PlayerBall3D` (`smash_speed_loss_mult == 1.0`) must never overwrite post-collision `linear_velocity` with scripted percentages; obstacles stay on the track until level end unless `track_local.y < -28.0`.

---

### Task 1: Charred Husk & Pin Stripe Materials + Upgrade Copy Alignment

**Files:**
- Modify: `src/core/material_library.gd`
- Modify: `src/upgrades/upgrade_catalog.gd`
- Test: `tests/test_core_stats.gd`

**Interfaces:**
- Produces on `MaterialLibrary`:
  - `static func make_charred_husk_material() -> StandardMaterial3D` (soot-blackened matte scorched metal for detonated `0.45kg` barrel husks)
  - `static func make_pin_stripe_material(color: Color = Color(0.92, 0.28, 0.18)) -> StandardMaterial3D` (glossy painted lacquer neck band for `800g` `WoodenPin`)
- Updates copy strings in `UpgradeCatalog` (`tungsten_core`, `kinetic_furnace`, `smash_chrono`, `momentum_overload`) to reflect persistent physical impacts without changing any upgrade IDs, stat keys, or hook formulas.

- [ ] **Step 1: Write failing material tests in `tests/test_core_stats.gd`**

Add assertions inside `_test_material_library_metadata_and_friction()` in `tests/test_core_stats.gd`:

```gdscript
	var charred: StandardMaterial3D = lib_script.make_charred_husk_material()
	var pin_stripe: StandardMaterial3D = lib_script.make_pin_stripe_material()
	assert_true(charred != null, "Charred barrel husk material created")
	assert_gt(charred.roughness, 0.72, "Charred husk is soot-matte high roughness")
	assert_lt(charred.albedo_color.r, 0.35, "Charred husk has dark scorched tint")
	assert_true(pin_stripe != null, "WoodenPin lacquer stripe material created")
	assert_lt(pin_stripe.roughness, 0.35, "WoodenPin stripe has glossy painted finish")
```

- [ ] **Step 2: Run headless tests to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL (`Invalid call. Nonexistent function 'make_charred_husk_material'`).

- [ ] **Step 3: Implement material builders and update `UpgradeCatalog` descriptions**

Add to `src/core/material_library.gd` right after `make_retro_barrel_material()`:

```gdscript
static func make_charred_husk_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_color = Color(0.22, 0.20, 0.19)
	mat.metallic = 0.28
	mat.roughness = 0.84
	mat.metallic_specular = 0.14
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.85, 0.85, 0.85)
	mat.uv1_triplanar_sharpness = 4.0
	return mat


static func make_pin_stripe_material(color: Color = Color(0.92, 0.28, 0.18)) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = color
	mat.metallic = 0.06
	mat.roughness = 0.24
	mat.metallic_specular = 0.62
	return mat
```

Update descriptions in `src/upgrades/upgrade_catalog.gd` (`tungsten_core`, `kinetic_furnace`, `smash_chrono`, `momentum_overload`):
- `tungsten_core`: `"质量 ×1.65，冲撞障碍时的前向减速损耗降低 50%（直接放大动量 P 与碾压优势）。"`
- `kinetic_furnace`: `"强力撞飞路障时按实时动能 √Ek 释放物理爆炸气浪，掀翻周围障碍并顺风推射自身。"`
- `smash_chrono`: `"每累计触发 4 次有效破障冲撞，倒计时立即 +1.5 秒并爆发一次前向提速脉冲。"`
- `momentum_overload`: `"【唯一】每次有效撞飞、落地或反弹叠 1 层过载（最高 20 层），每层使所有词条冲量输出 +12%。"`

- [ ] **Step 4: Run headless tests to verify pass**

Run: `./scripts/test.sh`
Expected: PASS (`0 failed`).

- [ ] **Step 5: Commit**

```bash
git add src/core/material_library.gd src/upgrades/upgrade_catalog.gd tests/test_core_stats.gd
git commit -m "feat: add charred husk and pin stripe materials and align upgrade copy"
```

---

### Task 2: Real-Physics Ground Solid Obstacles (`CrateObstacle` 500g/2kg, `WoodenPin` 800g, `ShieldBrute` 20kg)

**Files:**
- Create: `src/track/entities/wooden_pin.gd`
- Modify: `src/track/entities/crate_obstacle.gd`
- Modify: `src/track/entities/shield_brute.gd`
- Modify: `src/track/entities/track_entity_factory.gd`
- Test: `tests/test_entities.gd`

**Interfaces:**
- Common contract on movable `RigidBody3D` obstacles (`CrateObstacle`, `WoodenPin`, `ShieldBrute`):
  - `var is_dislodged: bool = false`
  - `var has_yielded_smash: bool = false`
  - `var min_smash_impulse: float` (`1.6` for `500g` crate & `800g` pin, `2.6` for `2kg` crate, `4.5` for `20kg` brute)
  - `func dislodge() -> void` (switches from resting slope damp to low air damp while keeping `collision_layer = 1` and `collision_mask = 1`)
  - `func on_ball_physical_impact(impulse_mag: float) -> bool` (calls `dislodge()`; returns `true` and sets `has_yielded_smash = true` the first time `impulse_mag >= min_smash_impulse`)
  - `func apply_shockwave(origin: Vector3, radius: float, force: float, chain_depth: int, ball: PlayerBall3D) -> void` (applies physical `apply_impulse` with distance falloff, clamps max launch speed to `32.0 m/s`, and notifies `ball.notify_obstacle_impact(pos, chain_depth)` once if not yet yielded)
  - Abyss check in `_physics_process`: when parented under sloped track (`get_parent() is Node3D`), if `position.y < -28.0`, `queue_free()`.
- Produces on `TrackEntityFactory`:
  - `static func create_crate(pos: Vector3, tier: String = "light", yaw_deg: float = 0.0) -> CrateObstacle`
  - `static func create_heavy_crate(pos: Vector3, yaw_deg: float = 0.0) -> CrateObstacle`
  - `static func create_wooden_pin(pos: Vector3) -> WoodenPin`

- [ ] **Step 1: Write failing real-physics ground obstacle tests in `tests/test_entities.gd`**

Update `_test_crate_tiers_and_slime_momentum_thresholds()` and `_test_shield_brute_rigidbody_and_slime_zone()` in `tests/test_entities.gd` to test:
1. `CrateObstacle` (`light` = `0.5kg` `"500g"`, `medium` = `2.0kg` `"2kg"` with `yaw_deg` support), `WoodenPin` (`0.8kg` `"800g"`), `ShieldBrute` (`20.0kg` `"20kg"`) have zero `Area3D` child sensors (`get_children()` contains no `Area3D`), remain `collision_layer == 1` and `collision_mask == 1` after impact and shockwaves, and remain `is_instance_valid` after `90` physics frames (`1.5s > 0.75s`).
2. `WoodenPin` stands upright on an `-11°` sloped floor for `35` physics frames without tipping (`up_dot > 0.98`) or sliding (`absf(dz) < 0.12`), and topples dramatically (`up_dot < 0.75`) when struck by a rolling `1.5kg` `PlayerBall3D`.
3. Pure Newtonian mass ratio in real Jolt 3D collisions: a `1.5kg` ball rolling into a `500g` crate retains forward `-Z` motion and launches the crate forward, whereas a `1.5kg` ball rolling head-on into a `20kg` `ShieldBrute` rebounds backward (`ball.linear_velocity.z > 0.2`) while the `20kg` weight barely shifts and stays on the track.

- [ ] **Step 2: Run headless tests to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL (`create_wooden_pin` missing, `medium` crate still `2.5kg`, `Area3D` still present).

- [ ] **Step 3: Implement `WoodenPin`, refactor `CrateObstacle` and `ShieldBrute`, and update `TrackEntityFactory`**

Create `src/track/entities/wooden_pin.gd`:

```gdscript
class_name WoodenPin
extends RigidBody3D

const ABYSS_LOCAL_Y: float = -28.0
const MAX_SHOCKWAVE_SPEED: float = 32.0

var weight_label: String = "800g"
var min_smash_impulse: float = 1.6
var is_dislodged: bool = false
var has_yielded_smash: bool = false


func _init() -> void:
	mass = 0.80
	set_meta("weight_label", weight_label)


func _ready() -> void:
	mass = 0.80
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.10, 0.0)
	physics_material_override = MaterialLibrary.high_friction_physics(0.74, 0.28)
	gravity_scale = 1.0
	linear_damp = 1.1
	angular_damp = 1.6
	contact_monitor = true
	max_contacts_reported = 4

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.28
	cyl_shape.height = 1.56
	col.shape = cyl_shape
	add_child(col)

	_build_pin_visuals()
	MaterialLibrary.attach_weight_labels(self, weight_label, Vector3(0.56, 1.56, 0.56), Color(0.24, 0.14, 0.06))


func _build_pin_visuals() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wood_mat := MaterialLibrary.make_beechwood_material(Color(1.06, 0.99, 0.90))
	var stripe_mat := MaterialLibrary.make_pin_stripe_material(Color(0.92, 0.26, 0.18))

	var belly_inst := MeshInstance3D.new()
	var belly_cyl := CylinderMesh.new()
	belly_cyl.top_radius = 0.25
	belly_cyl.bottom_radius = 0.27
	belly_cyl.height = 0.86
	belly_cyl.radial_segments = 16
	belly_cyl.material = wood_mat
	RenderHelper.attach_mesh(belly_inst, belly_cyl)
	belly_inst.position = Vector3(0.0, -0.35, 0.0)
	add_child(belly_inst)

	var neck_inst := MeshInstance3D.new()
	var neck_cyl := CylinderMesh.new()
	neck_cyl.top_radius = 0.14
	neck_cyl.bottom_radius = 0.25
	neck_cyl.height = 0.36
	neck_cyl.radial_segments = 16
	neck_cyl.material = wood_mat
	RenderHelper.attach_mesh(neck_inst, neck_cyl)
	neck_inst.position = Vector3(0.0, 0.26, 0.0)
	add_child(neck_inst)

	var band_inst := MeshInstance3D.new()
	var band_cyl := CylinderMesh.new()
	band_cyl.top_radius = 0.165
	band_cyl.bottom_radius = 0.185
	band_cyl.height = 0.085
	band_cyl.radial_segments = 16
	band_cyl.material = stripe_mat
	RenderHelper.attach_mesh(band_inst, band_cyl)
	band_inst.position = Vector3(0.0, 0.32, 0.0)
	add_child(band_inst)

	var head_inst := MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.18
	head_sphere.height = 0.38
	head_sphere.radial_segments = 16
	head_sphere.rings = 10
	head_sphere.material = wood_mat
	RenderHelper.attach_mesh(head_inst, head_sphere)
	head_inst.position = Vector3(0.0, 0.58, 0.0)
	add_child(head_inst)


func _physics_process(_delta: float) -> void:
	if not is_dislodged and (linear_velocity.length_squared() > 0.35 or angular_velocity.length_squared() > 0.45):
		dislodge()
	if position.y < ABYSS_LOCAL_Y:
		queue_free()


func dislodge() -> void:
	if is_dislodged:
		return
	is_dislodged = true
	sleeping = false
	linear_damp = 0.10
	angular_damp = 0.18


func on_ball_physical_impact(impulse_mag: float) -> bool:
	dislodge()
	if not has_yielded_smash and impulse_mag >= min_smash_impulse:
		has_yielded_smash = true
		return true
	return false


func apply_shockwave(
	origin: Vector3,
	radius: float,
	force: float,
	chain_depth: int,
	ball: PlayerBall3D
) -> void:
	var self_pos := global_position if is_inside_tree() else position
	var dist := self_pos.distance_to(origin)
	if dist > radius or force < 4.0:
		return
	dislodge()
	var falloff := clampf(1.0 - (dist / (radius * 1.15)), 0.25, 1.0)
	var radial := self_pos - origin
	radial.y = 0.0
	var dir := radial.normalized() if radial.length_squared() > 0.001 else Vector3(0.25, 0.0, -1.0).normalized()
	var up_dir := global_transform.basis.y.normalized() if is_inside_tree() else Vector3.UP
	var impulse_vec := (dir + up_dir * 0.48).normalized() * (force * 0.85 * falloff)
	apply_impulse(impulse_vec, up_dir * 0.22)
	if linear_velocity.length() > MAX_SHOCKWAVE_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SHOCKWAVE_SPEED
	if not has_yielded_smash:
		has_yielded_smash = true
		if ball != null and ball.has_method("notify_obstacle_impact"):
			ball.notify_obstacle_impact(self_pos, chain_depth)
```

Refactor `src/track/entities/crate_obstacle.gd` (`light`: `0.5kg` `"500g"`, `medium`: `2.0kg` `"2kg"` `1.20m`, zero `Area3D`, zero `0.75s` TTL, dual-state damping + real `apply_shockwave` + abyss `< -28.0` cleanup) and `src/track/entities/shield_brute.gd` (`20.0kg` `"20kg"`, zero `Area3D`, zero velocity teleport overwrite, zero `0.75s` TTL, real `apply_shockwave` + abyss `< -28.0` cleanup). Update `src/track/entities/track_entity_factory.gd` with `yaw_deg` on `create_crate`/`create_heavy_crate` and `create_wooden_pin(pos)`.

- [ ] **Step 4: Run headless tests to verify pass**

Run: `./scripts/test.sh`
Expected: PASS on all Task 2 ground rigidbody assertions.

- [ ] **Step 5: Commit**

```bash
git add src/track/entities/wooden_pin.gd src/track/entities/crate_obstacle.gd src/track/entities/shield_brute.gd src/track/entities/track_entity_factory.gd tests/test_entities.gd
git commit -m "feat: convert crates and weights to persistent Jolt rigidbodies and add 800g WoodenPin"
```

---

### Task 3: Special Obstacles & Fixed Bumper Real-Physics Refactor (`BouncerSlime`, `AerialBlocker`, `ExplosiveBarrel`, `PinballBumper`)

**Files:**
- Modify: `src/track/entities/bouncer_slime.gd`
- Modify: `src/track/entities/aerial_blocker.gd`
- Modify: `src/track/entities/explosive_barrel.gd`
- Modify: `src/track/entities/pinball_bumper.gd`
- Test: `tests/test_entities.gd`

**Interfaces:**
- `BouncerSlime` (`extends RigidBody3D`):
  - `mass = 3.0`, `SphereShape3D` (`radius = 0.66`), `friction = 0.45, bounce = 0.88`, `weight_label = "3kg"`
  - `var is_patrolling: bool = true`, `var is_dislodged: bool = false`, `var has_yielded_smash: bool = false`, `var min_smash_impulse: float = 3.2`
  - While `is_patrolling`: `lock_rotation = true`, `gravity_scale = 0.0` (or slope-compensated kinematic-like horizontal patrol velocity along track local `±X` within `±patrol_half_width`, seated on floor); upon `on_ball_physical_impact(impulse_mag)` with `impulse_mag >= 2.2` or `apply_shockwave`, sets `is_patrolling = false`, `lock_rotation = false`, `gravity_scale = 1.0`, `linear_damp = 0.12`, `angular_damp = 0.20`, triggers `_bounce_squash = 1.0`, and bounces/rolls persistently on the track!
- `AerialBlocker` (`extends RigidBody3D`):
  - `blocker_type == "soft_balloon"`: `mass = 0.25`, `weight_label = "250g"`, `SphereShape3D` (`R = 0.72`), `friction = 0.35, bounce = 0.92`, `min_smash_impulse = 0.8`
  - `blocker_type == "mag_iron"`: `mass = 12.0`, `weight_label = "12kg"`, `BoxShape3D` (`1.25m` cube), `friction = 0.82, bounce = 0.16`, `min_smash_impulse = 4.5`
  - `var is_tethered: bool = true`, `var is_dislodged: bool = false`, `var has_yielded_smash: bool = false`
  - While `is_tethered`: `gravity_scale = 0.0`, deterministic bobbing/swaying (`sway_x = sin(phase * 1.8) * 0.45`, `bob_y = sin(phase * 2.7) * 0.28`); upon `untether()` (called on ball physical impact with sufficient impulse—any `>= 0.5` for balloon, `>= 4.5` for `mag_iron`—or shockwave): `is_tethered = false`, `soft_balloon` sets `gravity_scale = 0.28, linear_damp = 0.48`, `mag_iron` sets `gravity_scale = 1.0, linear_damp = 0.14` and hides `_mag_ring` (`_mag_ring.visible = false`), dropping onto the track persistently!
- `ExplosiveBarrel` (`extends RigidBody3D`):
  - Pre-detonation: `mass = 1.5`, `weight_label = "1.5kg"`, `CylinderShape3D` (`R = 0.52, H = 1.25`), `contact_monitor = true, max_contacts_reported = 6`, zero `Area3D` child.
  - Contact trigger: `_on_body_entered(body)` / `_integrate_forces(state)` triggers `detonate(...)` when contacted by `PlayerBall3D` (not respawning) or another `RigidBody3D` whose relative impact speed `> RB_IMPACT_SPEED_THRESHOLD` (`2.6 m/s`).
  - Post-detonation (`is_detonated == true`): remains `visible = true`, `collision_layer = 1`, `collision_mask = 1`! Updates `mass = 0.45`, `MaterialLibrary.attach_weight_labels(self, "EMPTY", ...)`, swaps `_barrel_mesh_inst` material to `MaterialLibrary.make_charred_husk_material()`, switches `linear_damp = 0.14, angular_damp = 0.24`, launches self husk upward/down-slope with spin so it clatters persistently down the track, and never detonates a second time.
- `PinballBumper` (`extends StaticBody3D`):
  - Zero `Area3D` child; `physics_material_override = MaterialLibrary.high_friction_physics(0.05, 0.95)`, added to group `"pinball_bumper"`.
  - `func trigger_bumper_bounce(ball: PlayerBall3D, contact_normal: Vector3) -> void`: respects `_cooldown` (`0.16s`), triggers `_ring_pulse = 1.0`, applies radial horizontal kick along `contact_normal` (`>= 8.5 m/s`) + `ball.notify_wall_or_bumper_bounce(contact_normal, global_position, BUMPER_IMPULSE_PER_KG * ball.mass)`.

- [ ] **Step 1: Write failing tests in `tests/test_entities.gd` for `BouncerSlime`, `AerialBlocker`, `ExplosiveBarrel` husk, and `PinballBumper`**

Update `tests/test_entities.gd` to assert:
1. `BouncerSlime` is a `3.0kg` `RigidBody3D` (`bounce >= 0.85`), patrols deterministically before hit, and after ball collision transitions to `is_dislodged == true` without disappearing after `90` physics frames.
2. `AerialBlocker("soft_balloon")` is a `0.25kg` (`"250g"`, `bounce >= 0.90`) `RigidBody3D` and `AerialBlocker("mag_iron")` is a `12.0kg` (`"12kg"`) `RigidBody3D`; identical `initial_phase` produces identical hover coordinates; after untethering, `soft_balloon` floats gently (`gravity_scale` ~ `0.28`) while `mag_iron` drops under `gravity_scale == 1.0` onto the sloped floor and remains there persistently.
3. `ExplosiveBarrel` has no `Area3D` child, ignores resting floor & slow rigidbodies (`<= 2.6 m/s`), detonates on real contact with `PlayerBall3D` or fast `RigidBody3D` (`> 2.6 m/s`), switches to `mass == 0.45` and `weight_label == "EMPTY"` while remaining `visible == true` and colliding with the sloped floor across `90` physics frames, and physically blasts nearby crates/weights via `apply_shockwave`.
4. `PinballBumper` has no `Area3D` child, carries group `"pinball_bumper"`, `bounce >= 0.90`, and boosts `PlayerBall3D` cleanly via `trigger_bumper_bounce`.

- [ ] **Step 2: Run headless tests to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL (`BouncerSlime` / `AerialBlocker` not `RigidBody3D`, `ExplosiveBarrel` frees itself on `detonate`).

- [ ] **Step 3: Implement `BouncerSlime`, `AerialBlocker`, `ExplosiveBarrel`, and `PinballBumper` refactors**

Implement the four entity scripts cleanly following the exact interfaces above.

- [ ] **Step 4: Run headless tests to verify pass**

Run: `./scripts/test.sh`
Expected: PASS on entity unit tests.

- [ ] **Step 5: Commit**

```bash
git add src/track/entities/bouncer_slime.gd src/track/entities/aerial_blocker.gd src/track/entities/explosive_barrel.gd src/track/entities/pinball_bumper.gd tests/test_entities.gd
git commit -m "feat: refactor slime, aerial blockers, barrel husk, and bumper to real Jolt physics"
```

---

### Task 4: `PlayerBall3D` Contact-Impulse Synergy Bridge & `GameWorld3D` Shockwave Wiring

**Files:**
- Modify: `src/gameplay/player_ball_3d.gd`
- Modify: `src/gameplay/game_world_3d.gd`
- Test: `tests/test_ball_and_gravity.gd`
- Test: `tests/test_entities.gd`

**Interfaces:**
- Produces on `PlayerBall3D`:
  - `func _integrate_forces(state: PhysicsDirectBodyState3D) -> void`:
    - Compares `state.linear_velocity` against `_saved_velocity_pre_step` and iterates `state.get_contact_count()`.
    - Handles `"track_rail"` bounce, `"pinball_bumper"` (`trigger_bumper_bounce`), `ExplosiveBarrel` (`on_ball_contact`), and movable obstacle `RigidBody3D` (`on_ball_physical_impact(impulse_mag)`).
    - When `smash_speed_loss_mult < 1.0` (e.g., `tungsten_core`) and colliding with a movable obstacle caused downhill forward speed loss `dv_fwd > 0.2`, restores `(1.0 - smash_speed_loss_mult) * dv_fwd` along `-track_basis.z` (clamped so speed never exceeds `_saved_velocity_pre_step.length()`).
    - Fires `notify_obstacle_impact(contact_pos, 0)` when `obstacle.on_ball_physical_impact(impulse_mag)` returns `true` (first effective impact only).
    - Fires `notify_wall_or_bumper_bounce(contact_normal, contact_pos, 0.0)` when rebounding strongly off a heavy/elastic obstacle (`normal_rebound_dv >= 3.2 m/s`, guarded by `_obstacle_bounce_cooldown = 0.18s`).
  - `func notify_obstacle_impact(target_pos: Vector3, chain_depth: int = 0) -> void` (emits `target_smashed` + dispatches `synergy_bus.on_smash_target(ctx)` without overwriting `linear_velocity`!).
  - Keeps `notify_smash_target(target_pos: Vector3, _base_speed_loss_ratio: float = 0.0, chain_depth: int = 0)` delegating to `notify_obstacle_impact(target_pos, chain_depth)` for clean compatibility.

- [ ] **Step 1: Write failing contact-impulse & Tungsten Core collision tests in `tests/test_ball_and_gravity.gd`**

Add `_test_real_collision_mass_ratio_and_tungsten_synergy()` in `tests/test_ball_and_gravity.gd` verifying in real Jolt 3D physics frames:
1. Un-upgraded `1.5kg` ball colliding head-on with `500g` crate vs `2kg` crate vs `20kg` weight yields strictly decreasing post-impact forward velocity (`v_after_500g > v_after_2kg > v_after_20kg`, with `v_after_20kg` rebounding backward `> 0.0`).
2. `3.8kg` upgraded ball (`tungsten_core` + `giant_field`) colliding with the exact same `2kg` crate retains dramatically higher forward speed than the `1.5kg` baseline ball.
3. Hitting an obstacle triggers `on_smash_target` (`kinetic_furnace` / `smash_chrono` / `total_smashed`) at most **once** per obstacle even if the ball bumps into the same persistent crate twice!
4. Bouncing off a `20kg` `ShieldBrute` or `3kg` `BouncerSlime` triggers `on_wall_or_bumper_bounce` (`vector_refractor` / `momentum_overload` stack gain).

- [ ] **Step 2: Run headless tests to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL (`_test_real_collision_mass_ratio_and_tungsten_synergy` assertions fail before `_integrate_forces` bridge is wired).

- [ ] **Step 3: Implement `PlayerBall3D._integrate_forces` contact bridge and `GameWorld3D` shockwave wiring**

Implement `_integrate_forces(state)` and `notify_obstacle_impact` in `src/gameplay/player_ball_3d.gd` (deferring signal emissions / shockwave spawns safely at the end of `step_ball` or via queued pending impact events so PhysicsServer3D state is never mutated mid-integration!) and verify `GameWorld3D._on_barrel_detonated` cleanly boosts & shockwaves nearby entities once.

- [ ] **Step 4: Run headless tests to verify pass**

Run: `./scripts/test.sh`
Expected: PASS on `test_ball_and_gravity.gd` and `test_entities.gd`.

- [ ] **Step 5: Commit**

```bash
git add src/gameplay/player_ball_3d.gd src/gameplay/game_world_3d.gd tests/test_ball_and_gravity.gd tests/test_entities.gd
git commit -m "feat: bridge real Jolt contact impulses in PlayerBall3D to roguelike synergies"
```

---

### Task 5: `TrackGenerator3D` 3D Layered Clearance, `WoodenPin` Clusters, Angled Crates & Full Verification

**Files:**
- Modify: `src/track/track_generator_3d.gd`
- Modify: `tests/test_track_generator.gd`
- Modify: `tests/test_game_loop.gd`

**Interfaces:**
- Updates `TrackGenerator3D`:
  - `_is_rigidbody_pos_clear(pos: Vector3, is_pin: bool = false) -> bool`:
    - Skips pairs on different vertical layers (`absf(pos.y - other.position.y) >= 1.50`), so `AerialBlocker` (`Y ~ 2.65m`) never displaces ground obstacles underneath.
    - Enforces `MIN_PIN_CLEARANCE_XZ = 0.92` between two `WoodenPin`s (allowing tight bowling-pin pairs/triangles) and `MIN_RB_CLEARANCE_XZ = 1.90` for all other co-planar `RigidBody3D` pairs.
  - `_spawn_tiered_crate`: rolls deterministic yaw angle (`rng.randf_range(-24.0, 24.0)` for `light`, `(1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(18.0, 40.0)` for `medium` `2kg` crates so angled faces spin away on glancing hits).
  - `_spawn_pin_cluster(center_x: float, center_z: float, count: int, chunk: TrackChunkBase)`: spawns 2-pin or 3-pin bowling formations (`800g` `WoodenPin`s at `y = 0.79`) in `StraightWide`, `WaveHills`, `SplitPath`, and `FunnelGauntlet`.
  - `NarrowBridge`: spawns `WoodenPin` or `500g` `light` crate on Level 2+ (never `2kg` medium crates on unrailed narrow bridges).

- [ ] **Step 1: Update and add failing track generator & full-loop tests**

Update `tests/test_track_generator.gd` and `tests/test_game_loop.gd` to assert:
1. Generated tracks spawn `WoodenPin` (`800g`), `500g` light crates, `2kg` angled medium crates (`absf(rotation_degrees.y) >= 15.0`), `250g` / `12kg` `AerialBlocker` `RigidBody3D`s, `3kg` `BouncerSlime` `RigidBody3D`s, `1.5kg` `ExplosiveBarrel`s, and `20kg` `ShieldBrute`s.
2. `NarrowBridge` chunks contain zero `"medium"` `2kg` crates.
3. Co-planar non-pin `RigidBody3D` pairs maintain `>= 1.85m` XZ clearance, co-planar `WoodenPin` pairs maintain `>= 0.90m` XZ clearance, and deterministic seeds produce 100% identical chunk types, entity classes, positions, rotations, and phases across runs and levels.
4. Full 3D simulation tests (`_test_vertical_gravity_zero_roll_and_slope_stability`, `_test_hud_seed_modal_pause_bonus_ring_and_summary_seed_actions`, `_test_emergent_build_outpaces_baseline_in_3d_simulation`) pass cleanly with persistent real-physics obstacles.

- [ ] **Step 2: Run headless tests to verify failure**

Run: `./scripts/test.sh`
Expected: FAIL (`WoodenPin` not yet spawned in `TrackGenerator3D`, 2D clearance collides aerial/ground rigidbodies).

- [ ] **Step 3: Implement `TrackGenerator3D` updates**

Implement height-layered clearance, crate yaw angles, `NarrowBridge` lightweight rule, and `WoodenPin` clusters in `src/track/track_generator_3d.gd`.

- [ ] **Step 4: Run full headless test suite and rebuild Web HTML5 bundle**

Run: `./scripts/test.sh && ./scripts/build-web.sh`
Expected: 100% tests PASS (`0 failed`) and `build/web/index.html` + `.pck` + `.wasm` exported cleanly.

- [ ] **Step 5: Commit**

```bash
git add src/track/track_generator_3d.gd tests/test_track_generator.gd tests/test_game_loop.gd build/web
git commit -m "feat: spawn WoodenPin clusters, angled crates, and 3D layered clearance with Web export"
```
