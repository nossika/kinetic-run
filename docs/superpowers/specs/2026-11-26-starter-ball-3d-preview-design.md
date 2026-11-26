# Starter Ball Real-Time 3D Preview Design (`StarterBallPreview3D`)

## 1. Goal & Problem Statement
On `StartScreenPanel`, the 3 selectable starter balls previously used 2D rounded-panel `TextureRect` masks to approximate `sphere`, `rugby`, and `capsule_roller` shapes. While functional, flat 2D clipping lacks 3D surface curvature, specular lighting, real rolling motion, and an intuitive size reference. Replacing the 2D widget with a real-time 3D `SubViewport` turntable inside each card makes shape geometry, physical scale (`radius`), and rolling livery rotation immediately clear before starting a run.

## 2. Architecture & Components

### 2.1 Shared 3D Mesh Helper (`src/gameplay/player_ball_3d.gd`)
- Extract `static func populate_ball_visual(mesh_inst: MeshInstance3D, def: StarterBallDefinition) -> void` so both in-game `PlayerBall3D` and UI `StarterBallPreview3D` construct identical `SphereMesh` (`sphere`), `ClayMeshBuilder.make_ellipsoid_mesh` (`rugby`), and X-aligned `CapsuleMesh` (`capsule_roller`) geometry at `StatSheet.BASE_RADIUS`, paired with `MaterialLibrary.make_starter_ball_material`.
- Scale the visual pivot uniformly by `def.radius / StatSheet.BASE_RADIUS` so radius differences (`0.44m` mini vs `0.74m` jumbo) match gameplay 1:1.

### 2.2 Isolated 3D Turntable Widget (`src/ui/starter_ball_preview_3d.gd`)
- `StarterBallPreview3D` extends `SubViewportContainer` (`stretch = true`, `custom_minimum_size = Vector2(276.0, 144.0)`), framed inside a rounded sky-tinted diorama panel on each `StartScreenPanel` card.
- Internal `SubViewport` uses `own_world_3d = true` (`World3D.new()`), `transparent_bg = true`, and `msaa_3d = Viewport.MSAA_2X`.
- **Scene Graph inside `SubViewport`**:
  - `WorldEnvironment` (filmic tonemap, soft sky-tinted ambient light, compatible with `gl_compatibility` / WebGL2).
  - `KeyLight` (`DirectionalLight3D` with shadows enabled) + `RimFillLight` (`DirectionalLight3D` cool sky fill).
  - `PreviewCamera` (`Camera3D`, `fov = 34.0`, positioned at `Vector3(0.0, 1.20, 3.05)` looking at `Vector3(0.0, 0.46, 0.0)`).
  - `PedestalMesh` (`MeshInstance3D` fixed `0.94m`-radius chamfered beechwood turntable disc with top surface at `y = 0.0`, providing a constant ruler against which ball `radius` is judged).
  - `StagePivot` (`Node3D` at `Vector3.ZERO`, oscillating gently in three-quarter view `22° ± 24°` around Y so both front profile and side length of rugby/roller shapes remain visible).
  - `RollPivot` (`Node3D` at `y = def.radius`, uniformly scaled by `def.radius / StatSheet.BASE_RADIUS`, continuously rotating around `-X` at `2.6 rad/s` idle or `5.8 rad/s` when the card is hovered).
  - `BallMesh` (`MeshInstance3D` populated via `PlayerBall3D.populate_ball_visual`).

### 2.3 Lifecycle, Performance & Headless Testing
- `StartScreenPanel` connects `visibility_changed` to `StarterBallPreview3D.set_preview_active(visible)`. When `StartScreenPanel` hides upon starting a run, all 3 `SubViewport` instances switch to `SubViewport.UPDATE_DISABLED` and `set_process(false)`, costing **zero** GPU/CPU time during gameplay.
- When `DisplayServer.get_name() == "headless"`, `SubViewport` stays `UPDATE_DISABLED`, while all 3D nodes, meshes, transforms, and radius scale factors are still instantiated so automated tests can assert exact 3D preview state.
