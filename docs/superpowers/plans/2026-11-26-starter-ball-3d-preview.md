# Starter Ball Real-Time 3D Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat 2D starter ball icon on `StartScreenPanel` with a live, rolling 3D `SubViewport` turntable (`StarterBallPreview3D`) that renders actual `PlayerBall3D` geometry, livery textures, lighting, and `radius` scale proportions.

**Architecture:** Extract a static mesh builder `PlayerBall3D.populate_ball_visual(mesh_inst, def)` shared between gameplay and UI, build a self-contained `StarterBallPreview3D` (`SubViewportContainer` with `own_world_3d = true`, wooden reference pedestal, 3-point studio lighting, continuous forward roll + three-quarter yaw sway, and hover boost), and wire it into `StartScreenPanel` with automatic `UPDATE_DISABLED` suspension during active runs.

**Tech Stack:** Godot 4.6 (`gl_compatibility` renderer, GDScript, `SubViewport` / `World3D`, WebGL2 HTML5 export).

## Global Constraints
- Must render cleanly in `gl_compatibility` (desktop + WebGL2 HTML5 export) with zero outer ring lines on the ball.
- Must suspend `SubViewport` rendering (`UPDATE_DISABLED`) and `_process` whenever `StartScreenPanel` is hidden so active gameplay incurs zero overhead.
- Must instantiate deterministic node hierarchy, mesh types, and `radius` scaling in `headless` mode for automated tests (`./scripts/test.sh`).

---

### Task 1: Shared `PlayerBall3D.populate_ball_visual` & `StarterBallPreview3D` Component

**Files:**
- Modify: `src/gameplay/player_ball_3d.gd:257-293`
- Create: `src/ui/starter_ball_preview_3d.gd`
- Modify: `src/ui/start_screen_panel.gd:14-62,148-220`
- Test: `tests/test_game_loop.gd`

**Interfaces:**
- Produces:
  - `PlayerBall3D.populate_ball_visual(mesh_inst: MeshInstance3D, def: StarterBallDefinition, shape_override: String = "") -> void`
  - `StarterBallPreview3D` (`class_name StarterBallPreview3D extends SubViewportContainer`) with:
    - `setup_ball(def: StarterBallDefinition, phase_offset: float = 0.0) -> void`
    - `set_preview_active(active: bool) -> void`
    - `set_hovered(hovered: bool) -> void`
    - `get_ball_scale_ratio() -> float`
    - `get_ball_mesh_instance() -> MeshInstance3D`
    - `is_preview_active() -> bool`

- [ ] **Step 1: Write failing tests in `tests/test_game_loop.gd`**

Add assertions verifying:
1. `StartScreenPanel` embeds 3 `StarterBallPreview3D` instances (one per card) using isolated `World3D` (`own_world_3d == true`).
2. Each `StarterBallPreview3D` builds a real 3D `Mesh` matching `sphere` (`SphereMesh`), `rugby` (`ArrayMesh`), and `capsule_roller` (`CapsuleMesh`), and scales `RollPivot` proportionally to `def.radius / StatSheet.BASE_RADIUS`.
3. Advancing `_process(0.25)` rotates `RollPivot` so the ball visibly rolls in 3D.
4. Picking a starter ball hides `StartScreenPanel` and suspends all 3 previews (`is_preview_active() == false` and `SubViewport.UPDATE_DISABLED`).

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL because `StarterBallPreview3D` does not exist yet and `StartScreenPanel` still uses flat `Panel` widgets.

- [ ] **Step 3: Implement `PlayerBall3D.populate_ball_visual`, `StarterBallPreview3D`, and `StartScreenPanel` integration**

1. Extract `PlayerBall3D.populate_ball_visual` in `src/gameplay/player_ball_3d.gd` so `sphere`, `rugby`, and `capsule_roller` meshes are created identically for both gameplay and UI (creating geometry in headless too while skipping GPU material textures in headless).
2. Create `src/ui/starter_ball_preview_3d.gd` with `SubViewport` (`own_world_3d = true`, `transparent_bg = true`, `msaa_3d = Viewport.MSAA_2X`), `PreviewCamera`, `KeyLight`, `RimFillLight`, fixed beechwood `PedestalMesh` at `y = 0`, `StagePivot` three-quarter yaw sway, and `RollPivot` forward rolling + hover speed boost.
3. Update `src/ui/start_screen_panel.gd` to wrap each `StarterBallPreview3D` in a rounded sky-blue studio niche, connect card mouse hover (`mouse_entered` / `mouse_exited`) to `preview.set_hovered(...)`, and sync `visibility_changed` to `set_preview_active(visible)`.

- [ ] **Step 4: Run `./scripts/test.sh`, inspect live rendered screenshot, and export Web build**

Run: `./scripts/test.sh && ./scripts/build-web.sh`
Expected: PASS (0 failures, 0 script errors), crisp 3D rendered starter balls on `StartScreenPanel` verified via screenshot inspection, and updated `web/` bundle committed.
