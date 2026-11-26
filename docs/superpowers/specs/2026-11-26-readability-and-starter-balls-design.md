# Kinetic Run — Visual Readability, Toon Outlines & Seeded 3-Choice Starter Balls Design Spec

**Date:** 2026-11-26
**Project:** `kinetic-run` (Godot 4.6.2, `gl_compatibility` renderer, Jolt Physics 3D, Web HTML5 export)

---

## 1. Goals & Problem Statement

Following the initial Soft Clay-Storybook visual overhaul, gameplay inspection revealed two areas for improvement plus a core pre-run gameplay expansion:

1. **Scene Readability & Object Silhouettes**:
   - Foreground props, maple track slabs, horizon sky mist, and cream depth fog all clustered into the same warm-beige hue/value band, while `.lerp(cream, ...)` dilutions and bright white `rim_enabled` Fresnel highlights washed object edges into the pale track.
   - Objects need unmistakable **soft dark-cocoa cartoon outlines**, crisp **cool-sky vs. warm-track vs. vivid-toy-prop** color separation, and stronger contact shadows while retaining the cozy Clay-Storybook charm.
2. **Player Ball Cleanup & Rolling-Readable Liveries**:
   - Remove the redundant floating `EquatorialHalo` ring and legacy thin torus bands around `PlayerBall3D`.
   - Give balls bold, multi-panel painted toy liveries (via `gpt-image` seamless spherical/rotational textures + vivid color palettes) so forward spin and lateral roll are effortless to read at all speeds.
3. **Pre-Run Start Screen (`START_SCREEN`) with Seed Input & 3-Choice Random Starter Balls**:
   - Boot into `START_SCREEN` over a live, paused Level 1 3D track preview with an auto-generated random seed.
   - Centralize all seed editing (`LineEdit` + `🎲 随机换号` button) on the Start Screen; remove mid-run seed editing (`[N]` button & `SeedModal`) from `HudOverlay`.
   - Roll **3 deterministic starter balls** from `run_seed` (`RunState.derive_starter_ball_seed(run_seed)`), each with distinct smooth-rolling true 3D physics shapes (`sphere`, `rugby`, `capsule_roller`), randomized physical stats (`mass`, `radius`, `bounce`, `friction`, `linear_damp`), and distinct rolling liveries. Changing or randomizing the seed on the Start Screen immediately regenerates both the 3 starter ball options and the Level 1 preview track.

---

## 2. Module 1: Visual Readability, Toon Outlines & Color Separation

### 2.1 WebGL-Compatible Soft Cocoa Toon Outlines (`MaterialLibrary`)
- Add `MaterialLibrary.make_toon_outline_material(thickness: float = 0.026, outline_color: Color = Color(0.22, 0.14, 0.10))` using `StandardMaterial3D`:
  - `cull_mode = BaseMaterial3D.CULL_FRONT`
  - `shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED`
  - `albedo_color = outline_color`
  - `grow = true`, `grow_amount = thickness`
- Attach `next_pass` toon outlines automatically to interactive entity, character, rail, and player ball materials (`make_wood_crate_material`, `make_painted_toy_crate_material`, `make_cast_iron_material`, `make_tungsten_ball_material`, `make_starter_ball_material`, `make_retro_barrel_material`, `make_pin_stripe_material`, `make_silicone_soft_material`, `make_ceramic_pin_material`, `make_jelly_outer_material`), while keeping large floor slabs (`make_beechwood_material`, `make_workbench_material`) un-outlined so the track surface stays clean and calm.
- Disable white `rim_enabled` on `_new_base_material()` and switch from overly flat wrap lighting to balanced diffuse shading with crisp ground shadows (`shadow_opacity = 0.78`).

### 2.2 Three-Layer Cool/Warm & Value Separation
- **Layer 1 — Cool Crisp Sky & Subtle Horizon Mist (`GameWorld3D` + `storybook_sky_clouds.png`)**:
  - Regenerate `assets/textures/storybook_sky_clouds.png` via `gpt-image` with a rich, refreshing **clear pastel sky-blue gradient + crisp fluffy white storybook clouds** (avoiding beige/peach washout).
  - Lower `fog_density` to `0.0009` with cool sky-tinted horizon fog (`Color(0.76, 0.88, 0.97)`) so distant obstacles remain crisp and warm wooden tracks pop sharply against the cool blue sky.
- **Layer 2 — Warm Maple Track + Crisp Teal Guard Rails (`TrackChunkBase`)**:
  - Floor slabs stay warm honey-maple (`Color(0.90, 0.78, 0.63)`).
  - Guard rails use vivid teal-turquoise (`Color(0.20, 0.68, 0.66)`) with cocoa toon outlines so track boundaries read instantly.
- **Layer 3 — Vivid Painted Toy Color Coding for Obstacles**:
  - Remove `.lerp(cream, ...)` washout in `MaterialLibrary`.
  - **Light Crate (`500g`)**: Regenerate `assets/textures/crate_balsa_wood.png` as a crisp **sky-blue & butter-cream painted wooden toy block** (cool blue block on warm wood floor = instant contrast); **Heavy Crate (`2kg`)**: rich deep walnut/caramel (`Color(0.55, 0.34, 0.20)`) with dark cocoa bands.
  - **Wooden Pin (`800g`)**: Glossy ivory-white painted bowling pin (`make_ceramic_pin_material`) + vivid crimson neck ring (`Color(0.90, 0.22, 0.20)`).
  - **Explosive Barrel / Bouncer Slime / Boost Pad / Spring Pad / Aerial Bonus Ring / Shield Brute**: Vivid coral-red & white stripes, rich emerald jelly (`Color(0.18, 0.80, 0.44)`), bright lime-emerald pad, vivid tangerine spring pad, warm golden-amber ring, and deep cobalt-indigo shield brute.

---

## 3. Module 2: Smooth-Rolling Shapes & High-Contrast Ball Liveries

### 3.1 Cleanup of Redundant Ball Rings (`PlayerBall3D`)
- Remove `EquatorialHalo` from `_build_hud_ring_visuals()` and remove the two protruding `band` `TorusMesh` children from `_visual_root`.
- Keep `_hud_ring_root` with `_left_arrow_group`, `_right_arrow_group`, and subtle `_weight_label_3d` so lateral thrust cloud/droplet indicators continue working identically.

### 3.2 `StarterBallDefinition` & `StarterBallCatalog` (`src/core/`)
- `RunState.derive_starter_ball_seed(p_run_seed: int) -> int`: deterministic SplitMix32 derivation from `run_seed`.
- `StarterBallCatalog.roll_starter_balls(run_seed: int, count: int = 3) -> Array[StarterBallDefinition]`:
  - Deterministically generates 3 distinct starter balls for any `run_seed`.
  - Guarantees shape diversity across the 3 cards: each of the 3 slots uses one of the **3 smooth-rolling rotational shapes** (shuffled deterministically by seed):
    1. **`sphere`（圆球）**:
       - Physics collider: `SphereShape3D` with `radius = base_radius * scale`.
       - Visual mesh: `SphereMesh` (`radius = 0.55`, scaled by `visual_scale`).
       - Rolling feel: omni-directional, nimblest steering.
    2. **`rugby`（橄榄球）**:
       - Physics collider: smooth 3D prolate spheroid `ConvexPolygonShape3D` elongated gently along local X (`half_extents = (1.26 * R, 0.93 * R, 0.93 * R)` — circular in the YZ forward-rolling cross-section so straight downhill rolling is completely smooth, with playful gentle wobble on angled impacts!).
       - Visual mesh: matching smooth prolate ellipsoid `ArrayMesh` built in `ClayMeshBuilder.make_ellipsoid_mesh(...)`.
    3. **`capsule_roller`（圆边滚筒）**:
       - Physics collider: `CapsuleShape3D` rotated `90°` around Z so its axis aligns with local X (`radius = 0.86 * R`, `height = 2.36 * R` — full hemispherical rounded ends, broad contact patch, super stable straight roll).
       - Visual mesh: matching X-aligned `CapsuleMesh`.
  - **Randomized Physical Stats per Ball** (within fun, playable, balanced bounds):
    - `mass`: `0.85 kg` – `3.60 kg` (applied via `StatSheet` base/flat modifier so subsequent upgrades stack cleanly on top!)
    - `radius`: `0.44 m` – `0.74 m`
    - `bounce`: `0.10` – `0.82`
    - `friction`: `0.20` – `0.86` (applied to `PlayerBall3D.physics_material_override.friction`)
    - `linear_damp`: `0.18` – `0.52`
  - **4 `gpt-image` Seamless Rolling Liveries + Vivid Color Palettes**:
    - `assets/textures/ball_livery_beach.png` — 6-panel beach-ball color-block stripes + polar caps
    - `assets/textures/ball_livery_racer.png` — bold twin racing stripes + star number roundels
    - `assets/textures/ball_livery_swirl.png` — thick candy spiral ribbons
    - `assets/textures/ball_livery_polka.png` — high-contrast jumbo polka dots + equator band
    - Combined with distinct tint palettes and toon outlines so every starter ball looks unique on the selection card AND unmistakably shows spin in 3D!

---

## 4. Module 3: Start Screen (`StartScreenPanel`) & Seed Flow Consolidation

### 4.1 Game State Machine (`GameWorld3D`)
- States: `"START_SCREEN"`, `"RACING"`, `"DRAFTING"`, `"GAME_OVER"`.
- On `_ready()` (initial game launch):
  - Calls `open_start_screen("")` which generates a fresh random seed via `RunState.start_new_run(0)`, builds the Level 1 track in the background, rolls `current_starter_balls = StarterBallCatalog.roll_starter_balls(run_state.run_seed, 3)`, previews ball 0 stationary at the start gate, pauses physics/countdown (`game_state = "START_SCREEN"`), hides gameplay HUD/summary/draft panels, and shows `StartScreenPanel`.
- On `StartScreenPanel`:
  - **Seed Bar**: `LineEdit` pre-filled with `run_state.seed_text`, `🎲 随机种子` button (generates a new random seed immediately), and instant deterministic refresh whenever the seed text is edited or submitted (`preview_seed_on_start_screen(raw_text)` updates `run_state`, regenerates the 3 starter ball cards, and refreshes the background Level 1 track).
  - **3 Starter Ball Cards**: Warm storybook parchment cards displaying a vivid painted ball preview badge (shape silhouette + livery pattern + palette), generated title (e.g., `"弹跳糖果橄榄球"`, `"重装条纹滚筒"`), shape tag, and clear stat bars/values for **重量 / 大小 / 弹性 / 摩擦力**, plus `[1]`, `[2]`, `[3]` hotkeys or click to start!
  - Selecting card `index` (`select_starter_ball(index)`): applies that `StarterBallDefinition` to `synergy_bus.stats` and `player_ball`, hides `StartScreenPanel`, shows `HudOverlay`, unfreezes world simulation, and enters `"RACING"` on Level 1!
- Programmatic compatibility:
  - Keep `restart_run(seed_val)` and `restart_run_with_seed_text(raw_text)` entering `"RACING"` directly with deterministic starter ball `0` (or default baseline when called directly by headless simulation benchmarks) — specifically: let `restart_run` / `restart_run_with_seed_text` remain clean direct-start helpers for automated tests, while `open_start_screen(seed_text)` drives the interactive pre-run screen on boot and from `RunSummaryPanel`! Wait — let's double-check `test_game_loop.gd`:
    - In `test_game_loop.gd`, `_test_main_scene_boots_and_rolls_forward` instantiates `main.tscn` and checks state; updating `test_game_loop.gd` to test the new `START_SCREEN` boot -> `select_starter_ball(0)` -> `RACING` flow (and verifying seed change regenerates the 3 starter balls + HUD no longer has mid-run seed button) directly tests the new user-facing contract!

### 4.2 `HudOverlay` & `RunSummaryPanel` Simplification
- `HudOverlay`:
  - Remove `_seed_btn` (`改种子 [N]`), `_seed_modal`, and `KEY_N` input handling.
  - Display a clean read-only top pill showing `种子: <seed_text>  ·  <ball_name>`.
- `RunSummaryPanel`:
  - Replace mid-summary custom seed input with two clean storybook action buttons:
    - `🎲 新随机种子 · 重新选球开局（空格 / 回车）` -> opens `START_SCREEN` with a new random seed and 3 fresh balls.
    - `🔁 同种子 · 重新选球挑战` -> opens `START_SCREEN` pre-loaded with `run_state.seed_text` and its exact same 3 balls.

---

## 5. Verification Criteria
1. All unit & integration suites pass via `./scripts/test.sh` (0 failures, 0 script errors), covering:
   - Toon outline `next_pass` presence on interactive materials and absence on floor slabs;
   - Deterministic 3-ball generation from `run_seed` (same seed -> identical 3 balls; changing seed -> regenerated 3 balls; 3 distinct smooth shapes `sphere`, `rugby`, `capsule_roller`);
   - True Jolt 3D physics rolling test for all 3 shapes (`sphere`, `rugby`, `capsule_roller`) verifying smooth downhill rolling without stalling;
   - `START_SCREEN` boot, live seed change refreshing the 3 ball choices, `select_starter_ball(idx)` launching `RACING`, read-only seed on `HudOverlay`, and `RunSummaryPanel` returning to `START_SCREEN`.
2. Live 1280×720 OpenGL (`gl_compatibility`) rendered frame inspection verifying crisp dark-cocoa object outlines, clear sky-blue vs. maple-wood vs. vivid-prop contrast, start screen layout, and unmistakable rolling ball livery.
3. Clean Web HTML5 export via `./scripts/build-web.sh`.
