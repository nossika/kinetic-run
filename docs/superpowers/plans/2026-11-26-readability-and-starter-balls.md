# Readability, Toon Outlines & Seeded 3-Choice Starter Balls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add crisp dark-cocoa cartoon outlines and cool-sky vs. vivid-toy color separation across the 3D world, remove redundant ball ring lines, introduce 3 smooth-rolling true-physics ball shapes (`sphere`, `rugby`, `capsule_roller`) with 4 `gpt-image` rolling liveries, and build the pre-run `START_SCREEN` uniting seed editing and deterministic 3-choice starter ball selection.

**Architecture:** `StarterBallDefinition` and `StarterBallCatalog` generate 3 deterministic smooth-rolling starter balls from `RunState.derive_starter_ball_seed(run_seed)` and apply physical stats (`mass`, `radius`, `bounce`, `friction`, `linear_damp`), Jolt collision shapes (`SphereShape3D`, smooth prolate `ConvexPolygonShape3D`, X-aligned `CapsuleShape3D`), and painted rolling liveries to `PlayerBall3D`. `MaterialLibrary` attaches WebGL-compatible inverted-hull toon outlines (`next_pass` with `CULL_FRONT` + `grow`) to interactive props/characters/rails while keeping floor slabs un-outlined, paired with cool sky-blue background contrast and vivid prop colors. `StartScreenPanel` handles pre-run seed input + live 3-ball selection, while `HudOverlay` removes mid-run seed editing.

**Tech Stack:** Godot 4.6.2 (`gl_compatibility` renderer, Jolt Physics 3D), GDScript, `gpt-image` (`gpt-image-2`), Web HTML5 export.

## Global Constraints

- Renderer must remain `gl_compatibility` and export cleanly via `./scripts/build-web.sh`.
- Starter ball shapes must use smooth circular cross-sections in the YZ rolling plane (`sphere`, `rugby`, `capsule_roller`) so straight downhill rolling never stalls.
- Seed changes on `StartScreenPanel` must immediately regenerate both `current_starter_balls` and the Level 1 track preview deterministically.
- Mid-run seed editing (`SeedModal` / `[N]` button) is removed from `HudOverlay`.
- Existing core physics, deterministic track/draft seeding, and synergy suites in `./scripts/test.sh` must remain green.

---

### Task 1: Generate Crisp Sky, Painted Toy Crate & 4 Seamless Rolling Ball Liveries via `gpt-image`

**Files:**
- Modify: `assets/textures/storybook_sky_clouds.png`
- Modify: `assets/textures/crate_balsa_wood.png`
- Create: `assets/textures/ball_livery_beach.png`
- Create: `assets/textures/ball_livery_racer.png`
- Create: `assets/textures/ball_livery_swirl.png`
- Create: `assets/textures/ball_livery_polka.png`
- Modify: `src/core/material_library.gd`
- Test: `tests/test_core_stats.gd`

- [ ] **Step 1: Add failing texture constants test in `tests/test_core_stats.gd`**
- [ ] **Step 2: Generate the 6 textures via `.agents/skills/gpt-image/scripts/generate.py` and verify visually with `Read`**
- [ ] **Step 3: Register `TEX_BALL_LIVERY_*` constants in `MaterialLibrary` and trigger Godot headless import**
- [ ] **Step 4: Run `./scripts/test.sh` and commit**

---

### Task 2: `StarterBallDefinition`, `StarterBallCatalog`, Smooth-Rolling Physics Shapes & `PlayerBall3D` Livery/Collider Support

**Files:**
- Create: `src/core/starter_ball_definition.gd`
- Create: `src/core/starter_ball_catalog.gd`
- Modify: `src/core/run_state.gd`
- Modify: `src/core/stat_sheet.gd`
- Modify: `src/core/clay_mesh_builder.gd`
- Modify: `src/gameplay/player_ball_3d.gd`
- Test: `tests/test_core_stats.gd`, `tests/test_ball_and_gravity.gd`

- [ ] **Step 1: Write failing unit & physics tests for deterministic 3-ball generation, `EquatorialHalo` removal, and smooth downhill rolling of `sphere`, `rugby`, and `capsule_roller`**
- [ ] **Step 2: Implement `RunState.derive_starter_ball_seed`, `StatSheet.set_base_override`, `ClayMeshBuilder.make_ellipsoid_mesh` & `make_ellipsoid_convex_shape`, `StarterBallDefinition`, `StarterBallCatalog`, and `PlayerBall3D.apply_starter_ball`**
- [ ] **Step 3: Run `./scripts/test.sh` to verify all ball shapes roll smoothly and deterministically**
- [ ] **Step 4: Commit**

---

### Task 3: Soft Cocoa Toon Outlines, Cool Sky Contrast & Vivid Toy Entity Color Coding

**Files:**
- Modify: `src/core/material_library.gd`
- Modify: `src/gameplay/game_world_3d.gd`
- Modify: `src/track/track_chunk_base.gd`
- Modify: `src/track/entities/crate_obstacle.gd`
- Modify: `src/track/entities/wooden_pin.gd`
- Modify: `src/track/entities/bouncer_slime.gd`
- Modify: `src/track/entities/shield_brute.gd`
- Modify: `src/track/entities/boost_pad.gd`
- Modify: `src/track/entities/spring_pad.gd`
- Modify: `src/track/entities/pinball_bumper.gd`
- Modify: `src/track/entities/aerial_bonus_ring.gd`
- Modify: `src/track/entities/aerial_blocker.gd`
- Test: `tests/test_core_stats.gd`

- [ ] **Step 1: Write failing tests verifying `make_toon_outline_material` `next_pass` on interactive materials, no outline on floor materials, and disabled white `rim_enabled`**
- [ ] **Step 2: Implement `make_toon_outline_material`, vivid non-washed-out prop materials, cool sky lighting/fog in `GameWorld3D`, and vivid colors across entities & rails**
- [ ] **Step 3: Run `./scripts/test.sh` and commit**

---

### Task 4: `StartScreenPanel`, Simplified `HudOverlay` & `RunSummaryPanel`, Live Render Verification & Web Export

**Files:**
- Create: `src/ui/start_screen_panel.gd`
- Modify: `src/ui/hud_overlay.gd`
- Modify: `src/ui/run_summary_panel.gd`
- Modify: `src/gameplay/game_world_3d.gd`
- Modify: `tests/test_game_loop.gd`
- Modify: `web/index.html`, `web/index.pck`, `web/index.wasm.bin`

- [ ] **Step 1: Update and add failing tests in `tests/test_game_loop.gd` for `START_SCREEN` boot, live seed edit regenerating 3 starter balls, `select_starter_ball(idx)` entering `RACING`, read-only HUD seed display, and `RunSummaryPanel` returning to `START_SCREEN`**
- [ ] **Step 2: Implement `StartScreenPanel`, simplify `HudOverlay` and `RunSummaryPanel`, and wire `GameWorld3D` state transitions**
- [ ] **Step 3: Run `./scripts/test.sh`, capture real 1280×720 OpenGL frames (`START_SCREEN` + `RACING`) to inspect outlines, contrast, and rolling ball liveries, and run `./scripts/build-web.sh`**
- [ ] **Step 4: Commit all changes**
