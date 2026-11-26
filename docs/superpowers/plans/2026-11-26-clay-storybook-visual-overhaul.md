# Clay-Storybook Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the game's rough, sharp-edged, demo-like visuals into a cohesive, soft, uncluttered **Clay-Storybook (柔和黏土绘本风)** aesthetic across 3D environments, textures, rounded procedural meshes, cute character eyes, single-sided weight stamps, and warm parchment UI without altering any physics behavior or determinism.

**Architecture:** We generate a cohesive set of low-noise hand-painted maple wood, balsa block, matte clay-iron, coral-striped barrel, soft jelly, and watercolor sky-cloud textures via `gpt-image`. A new cached `ClayMeshBuilder` (`ArrayMesh` procedural generator) replaces sharp 90° `BoxMesh` / 8-sided `CylinderMesh` / `PrismMesh` primitives with smooth rounded boxes, chamfered cylinders, organic pebble pads, and cute clay eyes while keeping `CollisionShape3D` shapes untouched. `MaterialLibrary` adopts Half-Lambert wrap diffuse + soft Fresnel rim lighting and declutters industrial hazard flanges and double-sided black-outlined `Label3D` stencils; `GameWorld3D` replaces the noisy `WorkbenchBackdrop` grid with a warm sky + depth fog; and `UiTheme` / HUD / modal panels shift from dark cyber-neon to rounded warm cream parchment cards.

**Tech Stack:** Godot 4.6 (`gl_compatibility` renderer, Jolt Physics 3D, GDScript), OpenAI `gpt-image-2` Python generator (`.agents/skills/gpt-image/scripts/generate.py`), headless test runner `./scripts/test.sh` (`res://tests/run_tests.gd`), Web HTML5 exporter `./scripts/build-web.sh`.

## Global Constraints

- **Headless Safety**: Guard runtime GPU mesh/texture/label creation with `DisplayServer.get_name() == "headless"` (except when `force_build == true` is explicitly passed in unit tests to validate `ClayMeshBuilder` geometry), while always preserving real `CollisionShape3D` shapes, `PhysicsMaterial`, node groups, and metadata (`weight_label`, `is_anchored_fixed`).
- **Zero Physics or Determinism Drift**: Never alter any `CollisionShape3D` dimensions, rigidbody `mass`, friction/bounce values, `-11.0°` track slope, or `RandomNumberGenerator` call counts/order in `TrackGenerator3D`.
- **Material & Metadata Test Contracts**: Preserve all existing `MaterialLibrary` static method names, `StandardMaterial3D` return types, PBR range assertions in `tests/test_core_stats.gd` (`iron.metallic > 0.65`, `tungsten.metallic > 0.75`, `tungsten.roughness < 0.25`, `silicone.roughness > 0.75`, `jelly_out.transparency == TRANSPARENCY_ALPHA`, `charred.roughness > 0.72`, `charred.albedo_color.r < 0.35`, `pin_stripe.roughness < 0.35`), and all `TEX_*` file paths.
- **UV Compatibility**: `ClayMeshBuilder.make_rounded_box` must pack its 6 faces into Godot's `3×2` UV grid so `make_wood_crate_material`'s `uv1_scale = Vector3(3.0, 2.0, 1.0)` frames each crate face cleanly; `make_chamfered_cylinder` must map its side wall into `V ∈ [0.0, 0.5]` so `make_retro_barrel_material`'s `uv1_scale = Vector3(1.0, 2.0, 1.0)` wraps the barrel band cleanly.

---

### Task 1: Generate Unified Clay-Storybook Textures & Watercolor Sky via `gpt-image`

**Files:**
- Modify: `assets/textures/track_beechwood.png`
- Modify: `assets/textures/crate_balsa_wood.png`
- Modify: `assets/textures/metal_cast_iron.png`
- Modify: `assets/textures/barrel_retro_hazard.png`
- Modify: `assets/textures/jelly_bubble_soft.png`
- Modify: `assets/textures/anchor_hazard_stripe.png`
- Create: `assets/textures/storybook_sky_clouds.png`
- Modify: `src/core/material_library.gd:1-12`
- Test: `tests/test_core_stats.gd`

**Interfaces:**
- Consumes: `.agents/skills/gpt-image/scripts/generate.py`
- Produces:
  - `MaterialLibrary.TEX_STORYBOOK_SKY_CLOUDS == "res://assets/textures/storybook_sky_clouds.png"`
  - Imported Godot `.import` resources for all 7 textures under `res://assets/textures/`

- [ ] **Step 1: Write the failing test for `TEX_STORYBOOK_SKY_CLOUDS` resource existence**

In `tests/test_core_stats.gd`, add `lib_script.TEX_STORYBOOK_SKY_CLOUDS` to the asset existence loop at lines 243–253:

```gdscript
	for tex_path in [
		lib_script.TEX_TRACK_BEECHWOOD,
		lib_script.TEX_CRATE_BALSA_WOOD,
		lib_script.TEX_METAL_CAST_IRON,
		lib_script.TEX_ANCHOR_HAZARD_STRIPE,
		lib_script.TEX_BARREL_RETRO_HAZARD,
		lib_script.TEX_JELLY_BUBBLE_SOFT,
		lib_script.TEX_STORYBOOK_SKY_CLOUDS,
		lib_script.BUNDLED_FONT_PATH,
	]:
		assert_true(ResourceLoader.exists(tex_path), "Imported asset exists: %s" % tex_path)
```

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL on `Invalid get index 'TEX_STORYBOOK_SKY_CLOUDS'`.

- [ ] **Step 3: Generate all 7 cohesive clay-storybook textures using `gpt-image` and register `TEX_STORYBOOK_SKY_CLOUDS`**

Run pre-flight check and generate each texture into a temporary staging folder `/tmp/kinetic_storybook_tex`, then move to `assets/textures/` with exact filenames:

```bash
mkdir -p /tmp/kinetic_storybook_tex

# 1. Creamy hand-painted light maple track texture (low contrast, warm, zero dark knots)
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1024x1024 --quality medium --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Seamless tileable flat 2D game texture of warm creamy light maple wood crafted in a cozy clay-storybook illustration style like Yoshi's Crafted World. Very soft low-contrast warm cream and pale honey grain (#F5E8D3 to #EBD8BE), smooth matte finish, zero dark knots, zero harsh lines, zero shadows, uniform flat lighting."

# 2. Toy wooden block face texture (soft rounded inset border, warm balsa wood)
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1024x1024 --quality medium --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Square flat 2D game texture of a single face of a cute handcrafted wooden toy block in soft storybook clay-wood art style. Warm pale almond wood surface (#F3E2C7) with a subtle soft rounded-corner recessed frame border slightly warmer (#E2CAA8), ultra clean, minimal low-noise hand-painted brush feel, centered symmetrical square, no text, no harsh black lines."

# 3. Matte painted ceramic-clay metal texture (replaces noisy hammered dark cast iron)
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1024x1024 --quality medium --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Seamless tileable flat 2D texture of smooth handcrafted matte polymer clay / satin ceramic-iron surface in medium-dark warm slate gray (#4B505B). Subtle gentle tactile clay thumbprint smoothness, very low noise, zero rust, zero sharp scratches, cozy miniature toy aesthetic, uniform flat lighting."

# 4. Cute coral-peach and cream striped toy barrel texture
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1024x1024 --quality medium --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Horizontally seamless flat 2D game texture for a cute storybook toy barrel wall: top band soft pastel coral-red (#EE7662), middle wide band warm cream (#FAF0DF) with subtle friendly painted star-dot motif, bottom band soft pastel coral-red (#EE7662). Matte gouache/clay painted look, clean smooth edges, zero grunge, zero rust, no text."

# 5. Soft translucent fruit-jelly micro-bubble texture
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1024x1024 --quality medium --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Seamless tileable flat 2D game texture of soft translucent pastel milk-jelly gummy candy surface, pale minty-white base (#E8FFF3) with a few tiny soft glowing round air bubbles, ultra smooth dreamy storybook pastel style, low visual noise, uniform lighting."

# 6. Soft warm terracotta clay trim texture (replaces harsh black-yellow hazard stripes)
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1024x1024 --quality medium --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Seamless tileable flat 2D game texture of warm biscuit terracotta polymer clay (#D9BFA3) with gentle soft pastel cream scalloped wave trim, cozy handcrafted miniature toy base texture, low contrast, no black or yellow stripes."

# 7. Cozy watercolor pastel sky & fluffy clouds panorama
python3 .agents/skills/gpt-image/scripts/generate.py \
  --size 1536x1024 --quality high --output-dir /tmp/kinetic_storybook_tex \
  --prompt "Horizontally seamless 360 equirectangular skybox panorama illustration in a gentle cozy storybook gouache and soft clay-cloud style. Soft pastel sky blue at top (#8CC4E8) blending smoothly into warm creamy peach-apricot horizon (#FCEFD9) and soft warm biscuit mist below horizon (#EAD7C0), with a few simple rounded puffy cream-white clouds floating calmly, serene, uncluttered, minimal detail."
```

Copy each generated image in order to its target path under `assets/textures/` (`track_beechwood.png`, `crate_balsa_wood.png`, `metal_cast_iron.png`, `barrel_retro_hazard.png`, `jelly_bubble_soft.png`, `anchor_hazard_stripe.png`, `storybook_sky_clouds.png`), inspect them with `Read` to verify visual quality, and add `const TEX_STORYBOOK_SKY_CLOUDS: String = "res://assets/textures/storybook_sky_clouds.png"` to `src/core/material_library.gd`.

- [ ] **Step 4: Import textures into Godot and run `./scripts/test.sh` to verify GREEN**

Run: `./scripts/test.sh`
Expected: PASS across all test suites, including `Imported asset exists: res://assets/textures/storybook_sky_clouds.png`.

- [ ] **Step 5: Commit Task 1**

```bash
git add assets/textures/*.png assets/textures/*.import src/core/material_library.gd tests/test_core_stats.gd
git commit -m "art: replace harsh textures with soft clay-storybook textures and sky panorama"
```

---

### Task 2: Build `ClayMeshBuilder` Procedural Rounded Geometry & Clay Eyes Library

**Files:**
- Create: `src/core/clay_mesh_builder.gd`
- Test: `tests/test_core_stats.gd`

**Interfaces:**
- Consumes: `RenderHelper.attach_mesh(mesh_inst, mesh_res)`
- Produces:
  - `ClayMeshBuilder.make_rounded_box(size: Vector3, bevel_radius: float = 0.14, bevel_segments: int = 3, force_build: bool = false) -> ArrayMesh`
  - `ClayMeshBuilder.make_chamfered_cylinder(top_radius: float, bottom_radius: float, height: float, bevel: float = 0.08, radial_segments: int = 24, force_build: bool = false) -> ArrayMesh`
  - `ClayMeshBuilder.make_pebble_pad(size_xz: Vector2, height: float = 0.10, radial_segments: int = 24, force_build: bool = false) -> ArrayMesh`
  - `ClayMeshBuilder.attach_clay_eyes(parent: Node3D, forward_pos: Vector3, eye_spacing: float = 0.24, eye_radius: float = 0.065, with_blush: bool = true, force_build: bool = false) -> Node3D`

- [ ] **Step 1: Write the failing unit tests for `ClayMeshBuilder` in `tests/test_core_stats.gd`**

Add `_test_clay_mesh_builder_shapes_and_caching()` to `tests/test_core_stats.gd` and invoke it from `run_all()`:

```gdscript
func _test_clay_mesh_builder_shapes_and_caching() -> void:
	var builder: GDScript = load("res://src/core/clay_mesh_builder.gd")
	assert_true(builder != null, "ClayMeshBuilder script must exist")
	if builder == null:
		return

	# In headless mode without force_build, returns null cleanly for zero-overhead tests
	if DisplayServer.get_name() == "headless":
		assert_true(builder.make_rounded_box(Vector3.ONE, 0.14, 3, false) == null, "Headless default skips GPU mesh")

	# With force_build = true, builds cached watertight rounded ArrayMesh with matching Godot front-face winding
	var ref_bm := BoxMesh.new()
	var ref_arr := ref_bm.get_mesh_arrays()
	var rv: PackedVector3Array = ref_arr[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = ref_arr[Mesh.ARRAY_NORMAL]
	var ri: PackedInt32Array = ref_arr[Mesh.ARRAY_INDEX]
	var expected_wind_sign := signf((rv[ri[1]] - rv[ri[0]]).cross(rv[ri[2]] - rv[ri[0]]).dot(rn[ri[0]]))

	var rbox: ArrayMesh = builder.make_rounded_box(Vector3(1.2, 1.0, 2.0), 0.16, 3, true)
	var rbox_cached: ArrayMesh = builder.make_rounded_box(Vector3(1.2, 1.0, 2.0), 0.16, 3, true)
	assert_true(rbox != null and rbox.get_surface_count() == 1, "RoundedBox builds 1-surface ArrayMesh")
	assert_eq(rbox, rbox_cached, "RoundedBox reuses cached ArrayMesh instance for identical dimensions")

	var rb_arr := rbox.surface_get_arrays(0)
	var verts: PackedVector3Array = rb_arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = rb_arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = rb_arr[Mesh.ARRAY_TEX_UV]
	var idxs: PackedInt32Array = rb_arr[Mesh.ARRAY_INDEX]
	assert_gt(verts.size(), 60, "RoundedBox has subdivided bevel vertices")
	assert_eq(verts.size(), norms.size(), "RoundedBox normal count matches vertex count")
	assert_eq(verts.size(), uvs.size(), "RoundedBox UV count matches vertex count")

	var aabb := rbox.get_aabb()
	assert_approx(aabb.size.x, 1.2, 0.02, "RoundedBox AABB width matches requested X")
	assert_approx(aabb.size.y, 1.0, 0.02, "RoundedBox AABB height matches requested Y")
	assert_approx(aabb.size.z, 2.0, 0.02, "RoundedBox AABB depth matches requested Z")

	var tri_wind_sign := signf((verts[idxs[1]] - verts[idxs[0]]).cross(verts[idxs[2]] - verts[idxs[0]]).dot(norms[idxs[0]]))
	assert_eq(tri_wind_sign, expected_wind_sign, "RoundedBox triangle winding matches Godot BoxMesh front-face convention")

	var ccyl: ArrayMesh = builder.make_chamfered_cylinder(0.5, 0.5, 1.2, 0.10, 24, true)
	assert_true(ccyl != null and ccyl.get_surface_count() == 1, "ChamferedCylinder builds valid ArrayMesh")
	assert_approx(ccyl.get_aabb().size.y, 1.2, 0.02, "ChamferedCylinder height matches 1.2m")

	var pebble: ArrayMesh = builder.make_pebble_pad(Vector2(4.0, 6.0), 0.12, 20, true)
	assert_true(pebble != null and pebble.get_surface_count() == 1, "PebblePad builds valid ArrayMesh")
	assert_approx(pebble.get_aabb().size.x, 4.0, 0.05, "PebblePad X span matches 4.0m")
	assert_approx(pebble.get_aabb().size.z, 6.0, 0.05, "PebblePad Z span matches 6.0m")

	var host := Node3D.new()
	var eyes_root: Node3D = builder.attach_clay_eyes(host, Vector3(0.0, 0.2, 0.5), 0.24, 0.065, true, true)
	assert_true(eyes_root != null and host.get_node_or_null("ClayEyes") != null, "attach_clay_eyes mounts ClayEyes child node")
	assert_gte(eyes_root.get_child_count(), 4, "ClayEyes includes left/right pupils, highlights, and blush")
	host.free()
```

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL because `res://src/core/clay_mesh_builder.gd` does not exist yet.

- [ ] **Step 3: Implement `src/core/clay_mesh_builder.gd`**

Create `src/core/clay_mesh_builder.gd`:

```gdscript
class_name ClayMeshBuilder
extends RefCounted

static var _mesh_cache: Dictionary = {}
static var _winding_sign: float = 0.0
static var _eye_dark_mat: StandardMaterial3D = null
static var _eye_shine_mat: StandardMaterial3D = null
static var _blush_mat: StandardMaterial3D = null


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func _get_front_winding_sign() -> float:
	if _winding_sign == 0.0:
		var bm := BoxMesh.new()
		var arr := bm.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var s := signf((v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]]).dot(n[idx[0]]))
		_winding_sign = s if s != 0.0 else -1.0
	return _winding_sign


static func _q(val: float) -> int:
	return int(round(val * 200.0))


static func _append_oriented_tri(
	indices: PackedInt32Array,
	verts: PackedVector3Array,
	norms: PackedVector3Array,
	i0: int,
	i1: int,
	i2: int,
	wind_sign: float
) -> void:
	var cross := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
	var n_avg := norms[i0] + norms[i1] + norms[i2]
	if cross.dot(n_avg) * wind_sign < 0.0:
		indices.append(i0)
		indices.append(i2)
		indices.append(i1)
	else:
		indices.append(i0)
		indices.append(i1)
		indices.append(i2)


static func make_rounded_box(
	size: Vector3,
	bevel_radius: float = 0.14,
	bevel_segments: int = 3,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var sx := maxf(0.02, size.x)
	var sy := maxf(0.02, size.y)
	var sz := maxf(0.02, size.z)
	var segs := clampi(bevel_segments, 1, 6)
	var max_r := minf(sx, minf(sy, sz)) * 0.46
	var r := clampf(bevel_radius, 0.004, max_r)

	var key := "rbox_%d_%d_%d_%d_%d" % [_q(sx), _q(sy), _q(sz), _q(r), segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var inner := Vector3(
		maxf(0.0, sx * 0.5 - r),
		maxf(0.0, sy * 0.5 - r),
		maxf(0.0, sz * 0.5 - r)
	)
	var m := 2 * segs + 1
	var d_lut: Array[float] = []
	var s_lut: Array[float] = []
	for k in range(m + 1):
		if k <= segs:
			var theta := -PI * 0.5 + (float(k) / float(segs)) * (PI * 0.5)
			d_lut.append(sin(theta))
			s_lut.append(-1.0)
		else:
			var theta := (float(k - (segs + 1)) / float(segs)) * (PI * 0.5)
			d_lut.append(sin(theta))
			s_lut.append(1.0)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()

	# 6 faces packed into 3x2 UV cells matching Godot's BoxMesh UV layout
	var face_defs: Array[Dictionary] = [
		{"axis": 2, "fixed": m, "u_ax": 0, "v_ax": 1, "u_flip": false, "v_flip": true, "cell": Vector2(0, 0)},
		{"axis": 2, "fixed": 0, "u_ax": 0, "v_ax": 1, "u_flip": true, "v_flip": true, "cell": Vector2(1, 0)},
		{"axis": 0, "fixed": m, "u_ax": 2, "v_ax": 1, "u_flip": true, "v_flip": true, "cell": Vector2(2, 0)},
		{"axis": 0, "fixed": 0, "u_ax": 2, "v_ax": 1, "u_flip": false, "v_flip": true, "cell": Vector2(0, 1)},
		{"axis": 1, "fixed": m, "u_ax": 0, "v_ax": 2, "u_flip": false, "v_flip": false, "cell": Vector2(1, 1)},
		{"axis": 1, "fixed": 0, "u_ax": 0, "v_ax": 2, "u_flip": false, "v_flip": true, "cell": Vector2(2, 1)},
	]
	var half_arr := [sx * 0.5, sy * 0.5, sz * 0.5]

	for f_idx in range(face_defs.size()):
		var fd: Dictionary = face_defs[f_idx]
		var axis: int = fd["axis"]
		var fixed_k: int = fd["fixed"]
		var u_ax: int = fd["u_ax"]
		var v_ax: int = fd["v_ax"]
		var u_flip: bool = fd["u_flip"]
		var v_flip: bool = fd["v_flip"]
		var cell: Vector2 = fd["cell"]
		var base_v := verts.size()

		for iv in range(m + 1):
			for iu in range(m + 1):
				var idx3 := [0, 0, 0]
				idx3[axis] = fixed_k
				idx3[u_ax] = iu
				idx3[v_ax] = iv

				var d_vec := Vector3(d_lut[idx3[0]], d_lut[idx3[1]], d_lut[idx3[2]])
				var n_vec := d_vec.normalized()
				var c_vec := Vector3(
					s_lut[idx3[0]] * inner.x,
					s_lut[idx3[1]] * inner.y,
					s_lut[idx3[2]] * inner.z
				)
				var pos := c_vec + n_vec * r
				verts.append(pos)
				norms.append(n_vec)

				var pos_arr := [pos.x, pos.y, pos.z]
				var u01 := clampf(pos_arr[u_ax] / (2.0 * half_arr[u_ax]) + 0.5, 0.0, 1.0)
				var v01 := clampf(pos_arr[v_ax] / (2.0 * half_arr[v_ax]) + 0.5, 0.0, 1.0)
				if u_flip:
					u01 = 1.0 - u01
				if v_flip:
					v01 = 1.0 - v01
				uvs.append(Vector2((cell.x + u01) / 3.0, (cell.y + v01) / 2.0))

		var stride := m + 1
		for iv in range(m):
			for iu in range(m):
				var a := base_v + iv * stride + iu
				var b := a + 1
				var c := a + stride
				var d := c + 1
				_append_oriented_tri(indices, verts, norms, a, b, d, wind_sign)
				_append_oriented_tri(indices, verts, norms, a, d, c, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func make_chamfered_cylinder(
	top_radius: float,
	bottom_radius: float,
	height: float,
	bevel: float = 0.08,
	radial_segments: int = 24,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var rt := maxf(0.02, top_radius)
	var rb := maxf(0.02, bottom_radius)
	var h := maxf(0.02, height)
	var r_segs := clampi(radial_segments, 8, 48)
	var bev := clampf(bevel, 0.004, minf(minf(rt, rb) * 0.48, h * 0.45))

	var key := "ccyl_%d_%d_%d_%d_%d" % [_q(rt), _q(rb), _q(h), _q(bev), r_segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	var half_h := h * 0.5
	var b_steps := 3
	# Profile rings from top center -> top bevel -> bottom bevel -> bottom center
	var ring_r: Array[float] = [0.0]
	var ring_y: Array[float] = [half_h]
	var ring_nr: Array[float] = [0.0]
	var ring_ny: Array[float] = [1.0]
	var ring_v: Array[float] = [0.75]

	for s in range(b_steps + 1):
		var frac := float(s) / float(b_steps)
		var ang := frac * (PI * 0.5)
		ring_r.append((rt - bev) + sin(ang) * bev)
		ring_y.append((half_h - bev) + cos(ang) * bev)
		ring_nr.append(sin(ang))
		ring_ny.append(cos(ang))
		ring_v.append(lerpf(0.02, 0.10, frac))

	for s in range(b_steps + 1):
		var frac := float(s) / float(b_steps)
		var ang := frac * (PI * 0.5)
		ring_r.append((rb - bev) + cos(ang) * bev)
		ring_y.append(-(half_h - bev) - sin(ang) * bev)
		ring_nr.append(cos(ang))
		ring_ny.append(-sin(ang))
		ring_v.append(lerpf(0.40, 0.48, frac))

	ring_r.append(0.0)
	ring_y.append(-half_h)
	ring_nr.append(0.0)
	ring_ny.append(-1.0)
	ring_v.append(0.75)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()
	var ring_count := ring_r.size()
	var cols := r_segs + 1

	for ri in range(ring_count):
		var rr := ring_r[ri]
		var yy := ring_y[ri]
		var nr := ring_nr[ri]
		var ny := ring_ny[ri]
		var vv := ring_v[ri]
		var is_cap := (ri == 0 or ri == ring_count - 1)
		for ci in range(cols):
			var u := float(ci) / float(r_segs)
			var phi := u * TAU
			var cs := cos(phi)
			var sn := sin(phi)
			verts.append(Vector3(cs * rr, yy, sn * rr))
			norms.append(Vector3(cs * nr, ny, sn * nr).normalized())
			if is_cap:
				uvs.append(Vector2(0.5, 0.75))
			else:
				uvs.append(Vector2(u, vv))

	for ri in range(ring_count - 1):
		for ci in range(r_segs):
			var a := ri * cols + ci
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if ri == 0:
				_append_oriented_tri(indices, verts, norms, a, c, d, wind_sign)
			elif ri == ring_count - 2:
				_append_oriented_tri(indices, verts, norms, a, b, c, wind_sign)
			else:
				_append_oriented_tri(indices, verts, norms, a, b, d, wind_sign)
				_append_oriented_tri(indices, verts, norms, a, d, c, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func make_pebble_pad(
	size_xz: Vector2,
	height: float = 0.10,
	radial_segments: int = 24,
	force_build: bool = false
) -> ArrayMesh:
	if _is_headless() and not force_build:
		return null

	var hx := maxf(0.1, size_xz.x * 0.5)
	var hz := maxf(0.1, size_xz.y * 0.5)
	var h := maxf(0.02, height)
	var r_segs := clampi(radial_segments, 12, 48)
	var key := "pebble_%d_%d_%d_%d" % [_q(hx), _q(hz), _q(h), r_segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh

	# Smooth squircle dome pad (superellipse exponent n=2.6 in XZ, gentle pillow dome in Y)
	var rings := 5
	var half_y := h * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wind_sign := _get_front_winding_sign()
	var cols := r_segs + 1

	# Top center -> rim -> bottom flat border
	var total_rings := rings + 2
	for ri in range(total_rings):
		for ci in range(cols):
			var u := float(ci) / float(r_segs)
			var phi := u * TAU
			var cs := cos(phi)
			var sn := sin(phi)
			# Squircle unit boundary (|x|^2.5 + |z|^2.5 = 1)
			var sx := signf(cs) * pow(absf(cs), 0.78)
			var sz := signf(sn) * pow(absf(sn), 0.78)

			var rad_t := 0.0
			var yy := half_y
			var ny := 1.0
			var nr := 0.0
			if ri <= rings:
				var frac := float(ri) / float(rings)
				var ang := frac * (PI * 0.5)
				rad_t = sin(ang)
				yy = -half_y + cos(ang) * h
				ny = cos(ang)
				nr = sin(ang) * 0.65
			else:
				rad_t = 0.0
				yy = -half_y
				ny = -1.0
				nr = 0.0

			var px := sx * hx * rad_t
			var pz := sz * hz * rad_t
			verts.append(Vector3(px, yy, pz))
			norms.append(Vector3(cs * nr, ny, sn * nr).normalized())
			uvs.append(Vector2(px / (2.0 * hx) + 0.5, pz / (2.0 * hz) + 0.5))

	for ri in range(total_rings - 1):
		for ci in range(r_segs):
			var a := ri * cols + ci
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if ri == 0:
				_append_oriented_tri(indices, verts, norms, a, c, d, wind_sign)
			elif ri == total_rings - 2:
				_append_oriented_tri(indices, verts, norms, a, b, c, wind_sign)
			else:
				_append_oriented_tri(indices, verts, norms, a, b, d, wind_sign)
				_append_oriented_tri(indices, verts, norms, a, d, c, wind_sign)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func _ensure_eye_materials() -> void:
	if _eye_dark_mat == null:
		_eye_dark_mat = StandardMaterial3D.new()
		_eye_dark_mat.albedo_color = Color(0.18, 0.13, 0.11)
		_eye_dark_mat.roughness = 0.32
		_eye_dark_mat.metallic = 0.04
	if _eye_shine_mat == null:
		_eye_shine_mat = StandardMaterial3D.new()
		_eye_shine_mat.albedo_color = Color(1.0, 0.99, 0.96)
		_eye_shine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _blush_mat == null:
		_blush_mat = StandardMaterial3D.new()
		_blush_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blush_mat.albedo_color = Color(0.98, 0.56, 0.54, 0.58)
		_blush_mat.roughness = 0.78


static func attach_clay_eyes(
	parent: Node3D,
	forward_pos: Vector3,
	eye_spacing: float = 0.24,
	eye_radius: float = 0.065,
	with_blush: bool = true,
	force_build: bool = false
) -> Node3D:
	if parent == null:
		return null
	var existing := parent.get_node_or_null("ClayEyes")
	if existing != null:
		parent.remove_child(existing)
		existing.free()

	if _is_headless() and not force_build:
		return null

	_ensure_eye_materials()
	var root := Node3D.new()
	root.name = "ClayEyes"
	root.position = forward_pos

	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = eye_radius
	pupil_mesh.height = eye_radius * 2.0
	pupil_mesh.radial_segments = 14
	pupil_mesh.rings = 8
	pupil_mesh.material = _eye_dark_mat

	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = eye_radius * 0.34
	shine_mesh.height = eye_radius * 0.68
	shine_mesh.radial_segments = 10
	shine_mesh.rings = 6
	shine_mesh.material = _eye_shine_mat

	for side_sign in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.mesh = pupil_mesh
		eye.position = Vector3(side_sign * eye_spacing * 0.5, 0.0, 0.0)
		eye.scale = Vector3(1.0, 1.12, 0.65)
		root.add_child(eye)

		var shine := MeshInstance3D.new()
		shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shine.mesh = shine_mesh
		shine.position = Vector3(
			side_sign * eye_spacing * 0.5 + eye_radius * 0.26,
			eye_radius * 0.30,
			eye_radius * 0.52
		)
		root.add_child(shine)

	if with_blush:
		var blush_mesh := SphereMesh.new()
		blush_mesh.radius = eye_radius * 0.78
		blush_mesh.height = eye_radius * 1.56
		blush_mesh.radial_segments = 12
		blush_mesh.rings = 6
		blush_mesh.material = _blush_mat
		for side_sign in [-1.0, 1.0]:
			var blush := MeshInstance3D.new()
			blush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			blush.mesh = blush_mesh
			blush.position = Vector3(
				side_sign * (eye_spacing * 0.5 + eye_radius * 1.15),
				-eye_radius * 0.55,
				-eye_radius * 0.08
			)
			blush.scale = Vector3(1.35, 0.72, 0.35)
			root.add_child(blush)

	parent.add_child(root)
	return root
```

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN**

Run: `./scripts/test.sh`
Expected: PASS across all suites including `_test_clay_mesh_builder_shapes_and_caching`.

- [ ] **Step 5: Commit Task 2**

```bash
git add src/core/clay_mesh_builder.gd tests/test_core_stats.gd
git commit -m "feat: add ClayMeshBuilder for rounded boxes, chamfered cylinders, pebble pads, and clay eyes"
```

---

### Task 3: Soft Half-Lambert Clay `MaterialLibrary`, De-cluttered Stamps/Anchors, & `GameWorld3D` Sky/Fog

**Files:**
- Modify: `src/core/material_library.gd`
- Modify: `src/gameplay/game_world_3d.gd`
- Modify: `project.godot`
- Test: `tests/test_core_stats.gd`
- Test: `tests/test_game_loop.gd`

**Interfaces:**
- Consumes: `ClayMeshBuilder.make_rounded_box`, `MaterialLibrary.TEX_STORYBOOK_SKY_CLOUDS`
- Produces:
  - Soft Half-Lambert (`DIFFUSE_LAMBERT_WRAP`) + gentle Fresnel rim `StandardMaterial3D` builders in `MaterialLibrary`
  - Single-sided subtle wood/clay stamp in `MaterialLibrary.attach_weight_labels(...)` (no `WeightLabelTop`, soft low-contrast ink without harsh black border)
  - Clean rounded clay suction base in `MaterialLibrary.attach_anchored_flange_base(...)` (no hazard stripes, bolts, or `"FIXED"` label)
  - `GameWorld3D` with `WorkbenchBackdrop` removed, warm storybook sky (`PanoramaSkyMaterial` + `ProceduralSkyMaterial` fallback), `AMBIENT_SOURCE_SKY` warm bounce light, and soft cream depth fog (`fog_enabled == true`)

- [ ] **Step 1: Write failing tests for Half-Lambert wrap shading, backdrop removal, and environment fog**

In `tests/test_core_stats.gd`, add inside `_test_material_library_metadata_and_friction()`:

```gdscript
	assert_eq(
		beech.diffuse_mode,
		BaseMaterial3D.DIFFUSE_LAMBERT_WRAP,
		"Storybook materials use soft Half-Lambert wrap diffuse shading"
	)
	assert_true(beech.rim_enabled, "Storybook materials enable gentle Fresnel rim softness")
```

In `tests/test_game_loop.gd`, inside `_test_level_transition_and_draft_flow()` (or world setup test), assert:

```gdscript
	assert_true(
		world.get_node_or_null("WorkbenchBackdrop") == null,
		"Cluttered gridded WorkbenchBackdrop is removed in storybook environment"
	)
	var wenv := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_true(wenv != null and wenv.environment != null, "WorldEnvironment configured")
	if wenv != null and wenv.environment != null:
		assert_true(wenv.environment.fog_enabled, "Warm storybook depth fog is enabled")
```

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL (`beech.diffuse_mode != DIFFUSE_LAMBERT_WRAP`, `fog_enabled == false`).

- [ ] **Step 3: Update `MaterialLibrary`, `GameWorld3D`, and `project.godot`**

1. In `project.godot`, update `anti_aliasing/quality/msaa_3d=2` (4x MSAA).
2. In `src/core/material_library.gd`:
   - In `_new_base_material()`:
     ```gdscript
     static func _new_base_material() -> StandardMaterial3D:
     	var mat := StandardMaterial3D.new()
     	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
     	mat.texture_repeat = true
     	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
     	mat.rim_enabled = true
     	mat.rim = 0.22
     	mat.rim_tint = 0.38
     	return mat
     ```
   - Update `make_beechwood_material`: lift `honey` from dark `Color(0.66, 0.52, 0.36)` to bright warm cream-maple `Color(0.96, 0.91, 0.83, 1.0)`, `roughness = 0.76`, `metallic_specular = 0.12`, `uv1_scale = Vector3(0.20, 0.20, 0.20)`.
   - Update `make_frosted_acrylic_material(tint)`: soften saturation toward milky pastel sea-glass (`var pastel := tint.lerp(Color(0.98, 0.96, 0.92), 0.22)`), `alpha = clampf(tint.a if tint.a < 0.99 else 0.76, 0.20, 0.88)`, `roughness = 0.34`, `emission_energy_multiplier = 0.28` (no harsh neon glare).
   - Update `make_wood_crate_material(is_heavy)`: light crate `Color(0.98, 0.92, 0.82)`, `roughness = 0.74`; heavy crate warm cocoa walnut `Color(0.66, 0.48, 0.34)`, `roughness = 0.68` (keeping `uv1_scale = Vector3(3.0, 2.0, 1.0)`).
   - Update `make_cast_iron_material`: warm ceramic-slate tint scaling with `metallic = 0.72`, `roughness = 0.44` (matte satin clay-iron while satisfying `metallic > 0.65`).
   - Update `make_tungsten_ball_material`: glazed ceramic silver-blue `Color(0.68, 0.76, 0.86)`, `metallic = 0.78`, `roughness = 0.20`, subtle warm rim.
   - Update `make_charred_husk_material`: matte warm charcoal clay `Color(0.28, 0.25, 0.24)`, `metallic = 0.18`, `roughness = 0.86`.
   - Update `make_silicone_soft_material(color)`: pastel-softened clay rubber `color.lerp(Color(0.99, 0.96, 0.92), 0.16)`, `roughness = 0.88`.
   - Update `attach_weight_labels`:
     - Remove `WeightLabelTop` completely (`_remove_existing_child(target, "WeightLabelTop")` without re-adding).
     - Build only `WeightLabelFront` with subtle wood-carved / clay-stamped styling: `outline_size = 2`, soft translucent backing `Color(0.28, 0.20, 0.14, 0.32)`, `modulate = Color(text_color.r, text_color.g, text_color.b, 0.84)`, `0.0033 * clampf(front_span / 1.1, 0.50, 1.55) * char_factor`.
   - Update `attach_anchored_flange_base`:
     - Keep `target.set_meta("is_anchored_fixed", true)` and `_remove_existing_child(target, "AnchoredFlangeBase")`.
     - Replace the 4-part industrial hazard/iron/bolts/`"FIXED"` assembly with a single clean, rounded warm biscuit-clay suction pad (`ClayMeshBuilder.make_rounded_box(Vector3(half_x * 1.92, 0.08, half_z * 1.92), 0.038, 2)`) using `make_silicone_soft_material(Color(0.84, 0.75, 0.64))`.
3. In `src/gameplay/game_world_3d.gd`:
   - Delete `_workbench_backdrop` field, all backdrop mesh/slat construction in `_setup_lighting_and_sky()`, and `_sync_workbench_backdrop()`.
   - Configure `Sky`: if not headless and `MaterialLibrary._load_cached_texture(MaterialLibrary.TEX_STORYBOOK_SKY_CLOUDS)` is non-null, use `PanoramaSkyMaterial` with `energy_multiplier = 1.02` (falling back to warm pastel `ProceduralSkyMaterial`: `sky_top_color = Color(0.56, 0.78, 0.92)`, `sky_horizon_color = Color(0.98, 0.93, 0.85)`, `ground_horizon_color = Color(0.94, 0.86, 0.76)`, `ground_bottom_color = Color(0.84, 0.74, 0.63)`).
   - Set `env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY`, `env.ambient_light_sky_contribution = 0.65`, `env.ambient_light_color = Color(0.96, 0.91, 0.84)`, `env.ambient_light_energy = 0.62`.
   - Enable soft storybook depth fog:
     ```gdscript
     env.fog_enabled = true
     env.fog_light_color = Color(0.97, 0.92, 0.85)
     env.fog_light_energy = 1.0
     env.fog_density = 0.0045
     env.fog_sky_affect = 0.16
     ```
   - Warm `MainSunLight` (`Color(1.0, 0.95, 0.87)`, `light_energy = 0.98`, `shadow_opacity = 0.68` so shadows are soft warm milk-tea rather than harsh black!) and `SkyFillLight` (`Color(0.88, 0.92, 1.0)`, `light_energy = 0.34`).
   - Soften `_spawn_vfx_ring` shockwave ring to a rounded `TorusMesh` in warm pastel apricot-gold (`Color(0.99, 0.80, 0.44, 0.68)`).

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN**

Run: `./scripts/test.sh`
Expected: PASS across all 6 test suites.

- [ ] **Step 5: Commit Task 3**

```bash
git add project.godot src/core/material_library.gd src/gameplay/game_world_3d.gd tests/test_core_stats.gd tests/test_game_loop.gd
git commit -m "feat: switch world lighting, fog, sky, and MaterialLibrary to soft clay-storybook style"
```

---

### Task 4: Remodel Track Chunks, Obstacles, Player Ball, & Wind Zones with Rounded Meshes & Clay Eyes

**Files:**
- Modify: `src/track/track_chunk_base.gd`
- Modify: `src/track/track_generator_3d.gd`
- Modify: `src/gameplay/player_ball_3d.gd`
- Modify: `src/track/entities/crate_obstacle.gd`
- Modify: `src/track/entities/wooden_pin.gd`
- Modify: `src/track/entities/explosive_barrel.gd`
- Modify: `src/track/entities/pinball_bumper.gd`
- Modify: `src/track/entities/spring_pad.gd`
- Modify: `src/track/entities/boost_pad.gd`
- Modify: `src/track/entities/slime_zone.gd`
- Modify: `src/track/entities/aerial_bonus_ring.gd`
- Modify: `src/track/entities/bouncer_slime.gd`
- Modify: `src/track/entities/shield_brute.gd`
- Modify: `src/track/entities/aerial_blocker.gd`
- Modify: `src/track/entities/wind_zone.gd`
- Test: `tests/test_entities.gd`
- Test: `tests/test_track_generator.gd`

**Interfaces:**
- Consumes: `ClayMeshBuilder.make_rounded_box`, `ClayMeshBuilder.make_chamfered_cylinder`, `ClayMeshBuilder.make_pebble_pad`, `ClayMeshBuilder.attach_clay_eyes`
- Produces:
  - Zero sharp 90° `BoxMesh` / 8-sided `CylinderMesh` / harsh `PrismMesh` visuals on gameplay entities (while keeping all `CollisionShape3D` shapes identical)
  - Cute `ClayEyes` mounted on character obstacles (`BouncerSlime`, `ShieldBrute`, `AerialBlocker`)

- [ ] **Step 1: Write failing tests verifying character obstacle metadata/structure and physics parity**

In `tests/test_entities.gd`, add assertions verifying that `BouncerSlime`, `ShieldBrute`, and `AerialBlocker` preserve exact collision shapes, mass, and `weight_label` metadata while `PinballBumper` and `SpringPad` no longer spawn cluttered `"BumperTopFixedStencil"` or `"SpringArrowStencil"` text labels:

```gdscript
	assert_true(
		bumper.get_node_or_null("BumperTopFixedStencil") == null,
		"PinballBumper removes cluttered FIXED top stencil text"
	)
	var spring_pad_top := spring.get_node_or_null("SiliconeTopPad")
	if spring_pad_top != null:
		assert_true(
			spring_pad_top.get_node_or_null("SpringArrowStencil") == null,
			"SpringPad removes harsh text arrow stencil"
		)
```

- [ ] **Step 2: Run `./scripts/test.sh` to verify pass/baseline in headless and check visual node structure**

Run: `./scripts/test.sh`
Expected: PASS in headless (or FAIL if any label created unconditionally); now remodel all 15 track/entity scripts cleanly.

- [ ] **Step 3: Remodel track chunks, obstacles, player ball, and wind zones**

Apply the rounded storybook geometry and cohesive warm pastel palette across all 15 files (leaving every `CollisionShape3D` untouched):

1. **`src/track/track_chunk_base.gd` & `src/track/track_generator_3d.gd`**:
   - `_add_floor_slab`: replace `BoxMesh` with `ClayMeshBuilder.make_rounded_box(size, 0.14, 3)` and `MaterialLibrary.make_beechwood_material(color)`.
   - `_add_speed_stripes`: replace metallic dark stripes with soft warm cream chalk rounded inlays (`ClayMeshBuilder.make_rounded_box(Vector3(half_w * 1.35, 0.018, 0.26), 0.008, 2)` in matte `Color(0.99, 0.96, 0.90)`).
   - `_add_guard_rail`: replace sharp neon `BoxMesh` wall with soft matte clay-wood rounded rail (`ClayMeshBuilder.make_rounded_box(size, minf(size.x, size.y) * 0.45, 3)`) using `MaterialLibrary.make_silicone_soft_material(...)` in cohesive storybook colors:
     - Standard rails: warm sage-mint `Color(0.56, 0.84, 0.74)` or creamy sky `Color(0.62, 0.80, 0.92)`;
     - `SplitPath` central divider: warm terracotta apricot `Color(0.92, 0.62, 0.46)`;
     - `PinballAlley` rails: soft peach-rose `Color(0.94, 0.62, 0.68)`;
     - `FunnelGauntlet` rails: soft coral-amber `Color(0.94, 0.58, 0.46)`.
   - `add_side_launch_ramp` & `add_sky_platform`: use `ClayMeshBuilder.make_rounded_box` in misty sky-blue (`Color(0.54, 0.78, 0.92, 0.84)`) with rounded warm cream side curbs (`Color(0.98, 0.95, 0.89)`), and warm wood-colored support stays on `SkyPlatform`.
   - `_build_finish_archway`: rounded cream-mint pillars (`ClayMeshBuilder.make_chamfered_cylinder(0.36, 0.40, 7.5, 0.10, 20)`) + plump rounded golden-sage crossbar (`ClayMeshBuilder.make_rounded_box(Vector3(14.6, 0.82, 0.82), 0.28, 3)`).

2. **Pure Handcrafted Craft Props (No Eyes)**:
   - `src/track/entities/crate_obstacle.gd`: replace `BoxMesh` with `ClayMeshBuilder.make_rounded_box(box_size, 0.14, 3)`; for `is_heavy` (`2kg`), replace protruding sharp iron boxes with subtle rounded warm-bronze clay corner bands (`ClayMeshBuilder.make_rounded_box(..., 0.035, 2)` in `Color(0.46, 0.34, 0.26)`).
   - `src/track/entities/wooden_pin.gd`: increase `radial_segments` from `16` to `24`, use `ClayMeshBuilder.make_chamfered_cylinder(0.25, 0.27, 0.86, 0.08, 24)` for the belly so bottom rim is softly rounded, and paint neck band soft coral `Color(0.92, 0.44, 0.38)`.
   - `src/track/entities/explosive_barrel.gd`: replace sharp `CylinderMesh` with `ClayMeshBuilder.make_chamfered_cylinder(0.52, 0.52, 1.25, 0.11, 24)` and replace sharp cylinder rims with smooth rounded `TorusMesh` hoops (`inner_radius = 0.48, outer_radius = 0.555`).
   - `src/track/entities/pinball_bumper.gd`: remove `"BumperTopFixedStencil"` `Label3D`; replace sharp metal post with a cute rounded cream-clay mushroom cap (`ClayMeshBuilder.make_chamfered_cylinder(0.46, 0.50, 1.18, 0.16, 24)` in `make_silicone_soft_material(Color(0.97, 0.93, 0.86))`) + plump pastel coral-pink silicone torus (`Color(0.95, 0.52, 0.58)`).
   - `src/track/entities/spring_pad.gd`: remove `"SpringArrowStencil"` `Label3D`; replace square `BoxMesh` top pad with a plump warm buttercup-yellow cylinder cushion (`ClayMeshBuilder.make_chamfered_cylinder(1.02, 1.06, 0.16, 0.06, 24)` in `Color(0.98, 0.82, 0.34)`) topped with two small rounded cream `CapsuleMesh` chevron bars.
   - `src/track/entities/boost_pad.gd`: replace `BoxMesh` base with `ClayMeshBuilder.make_pebble_pad(Vector2(2.3, 3.5), 0.10, 24)` in soft sage-mint (`Color(0.46, 0.86, 0.72, 0.86)`) and `CapsuleMesh` rounded chevrons (`radius = 0.065, height = 0.76`).
   - `src/track/entities/slime_zone.gd`: replace rectangular `BoxMesh` with organic `ClayMeshBuilder.make_pebble_pad(zone_size, 0.10, 28)` in soft honeydew-lime jelly (`Color(0.52, 0.88, 0.46, 0.68)`).
   - `src/track/entities/aerial_bonus_ring.gd`: warm honey-gold outer ring (`Color(0.98, 0.80, 0.36, 0.88)`) + mint inner ring (`Color(0.52, 0.90, 0.76, 0.88)`), and warm beechwood rounded stem.

3. **Cute Clay-Character Obstacles (With `ClayMeshBuilder.attach_clay_eyes`)**:
   - `src/track/entities/bouncer_slime.gd`: soft pastel mint-green outer jelly (`Color(0.44, 0.90, 0.64)`) + warm cream-mint inner core + `ClayMeshBuilder.attach_clay_eyes(_visual_root, Vector3(0.0, 0.08, 0.56), 0.26, 0.065, true)` so eyes & blush squash and stretch with the slime!
   - `src/track/entities/shield_brute.gd`: replace `radial_segments = 8` octagonal cylinders with smooth `28`-segment plump roly-poly clay-iron kettlebell body (`ClayMeshBuilder.make_chamfered_cylinder(0.66, 0.74, 0.82, 0.18, 28)` + rounded dome shoulder `SphereMesh` + chunky torus handle) and attach `ClayMeshBuilder.attach_clay_eyes(self, Vector3(0.0, -0.10, 0.69), 0.28, 0.068, true)`.
   - `src/track/entities/aerial_blocker.gd`:
     - `mag_iron`: replace sharp `BoxMesh` with plump `ClayMeshBuilder.make_rounded_box(Vector3(1.25, 1.25, 1.25), 0.22, 3)` + soft sky-blue hover torus + `ClayMeshBuilder.attach_clay_eyes(self, Vector3(0.0, 0.06, 0.62), 0.28, 0.062, false)`;
     - `soft_balloon`: soft pastel peach-apricot sphere (`Color(0.98, 0.62, 0.48)`) + rounded tie knot + `ClayMeshBuilder.attach_clay_eyes(self, Vector3(0.0, 0.05, 0.70), 0.24, 0.058, true)`.

4. **`src/gameplay/player_ball_3d.gd` & `src/track/entities/wind_zone.gd`**:
   - `PlayerBall3D`: replace sharp `PrismMesh` + `BoxMesh` thrust arrows and `BoxMesh` jet puffs with a smooth rounded cone/capsule pointer + 3 fluffy warm-white cotton cloud puffs (`SphereMesh`, radii `0.11, 0.085, 0.075`); soften `BallWeightLabel` to subtle cream ink (`outline_size = 3`, soft warm cocoa outline `Color(0.26, 0.19, 0.14, 0.55)`).
   - `WindZone`: soften `wind_tint` alphas (`0.36 ~ 0.44`), replace rectangular `BoxMesh` ribbons with smooth `CapsuleMesh` streamlines (`radius = 0.028, height = ribbon_base_len`, rotated along `-Z`), and replace sharp `PrismMesh` chevrons with soft rounded cone-droplets (`CylinderMesh` with `top_radius = 0.03, bottom_radius = 0.24, height = 0.46, radial_segments = 16`).

- [ ] **Step 4: Run `./scripts/test.sh` to verify GREEN**

Run: `./scripts/test.sh`
Expected: PASS across all 6 test suites with zero physics or collision drift.

- [ ] **Step 5: Commit Task 4**

```bash
git add src/track/ src/gameplay/player_ball_3d.gd tests/test_entities.gd
git commit -m "feat: remodel track, obstacles, wind zones, and ball with rounded clay meshes and cute eyes"
```

---

### Task 5: Warm Storybook Parchment UI Overhaul & Web HTML5 Export

**Files:**
- Modify: `src/ui/ui_theme.gd`
- Modify: `src/ui/hud_overlay.gd`
- Modify: `src/ui/upgrade_draft_panel.gd`
- Modify: `src/ui/run_summary_panel.gd`
- Modify: `web/*` (via `./scripts/build-web.sh`)
- Test: `tests/test_core_stats.gd`
- Test: `tests/test_game_loop.gd`

**Interfaces:**
- Consumes: `UiTheme.build_theme()`, `UiTheme.make_panel_style(...)`
- Produces:
  - Warm cream-parchment storybook UI cards (`#FAF3E6`), rounded capsule buttons/inputs/progress bars, cocoa-brown & sage-green typography across `HudOverlay`, `UpgradeDraftPanel`, and `RunSummaryPanel`
  - Updated `web/index.html`, `web/index.pck`, `web/index.wasm.bin`

- [ ] **Step 1: Write failing test for storybook warm parchment `UiTheme` styling**

In `tests/test_core_stats.gd`, add `_test_storybook_ui_theme_styles()` and call it in `run_all()`:

```gdscript
func _test_storybook_ui_theme_styles() -> void:
	var ui_script: GDScript = load("res://src/ui/ui_theme.gd")
	assert_true(ui_script != null, "UiTheme script exists")
	if ui_script == null:
		return
	var card_sb: StyleBoxFlat = ui_script.make_storybook_card_style()
	assert_true(card_sb != null, "make_storybook_card_style returns StyleBoxFlat")
	assert_gt(card_sb.bg_color.r, 0.85, "Storybook card background is warm light cream parchment")
	assert_gte(card_sb.corner_radius_top_left, 16, "Storybook card uses generous rounded corners (>=16px)")
```

- [ ] **Step 2: Run `./scripts/test.sh` to verify RED failure**

Run: `./scripts/test.sh`
Expected: FAIL (`Invalid call. Nonexistent function 'make_storybook_card_style'`).

- [ ] **Step 3: Implement warm storybook UI across `UiTheme`, `HudOverlay`, `UpgradeDraftPanel`, and `RunSummaryPanel`**

1. **`src/ui/ui_theme.gd`**:
   - Add palette constants (`CREAM_BG = Color(0.98, 0.95, 0.89, 0.94)`, `WALNUT_BORDER = Color(0.76, 0.63, 0.49, 0.92)`, `INK_PRIMARY = Color(0.28, 0.20, 0.14)`, `INK_MUTED = Color(0.48, 0.38, 0.29)`, `SAGE_ACCENT = Color(0.24, 0.62, 0.48)`, `AMBER_ACCENT = Color(0.80, 0.48, 0.18)`, `CORAL_ALERT = Color(0.84, 0.36, 0.28)`).
   - Add `make_storybook_card_style(bg_color = CREAM_BG, border_color = WALNUT_BORDER, corner_radius: int = 18, border_width: int = 2) -> StyleBoxFlat` with soft bottom drop shadow (`shadow_color = Color(0.26, 0.18, 0.11, 0.14)`, `shadow_size = 6`, `shadow_offset = Vector2(0, 3)`).
   - Update `make_panel_style(...)` to also include gentle shadow softness and default `corner_radius = 18`.
   - In `build_theme()`, configure rounded warm capsule `StyleBoxFlat` overrides for `Button` (`normal` warm almond `#F4E7D1`, `hover` `#FFF7E8`, `pressed` `#E6D3B5`, `disabled` `#EFE6D8`, `font_color = INK_PRIMARY`, `corner_radius = 14`), `LineEdit` (`normal`/`focus` soft inset cream `#FFFDF8` with walnut/sage border, `font_color = INK_PRIMARY`, `font_placeholder_color = INK_MUTED`), and `ProgressBar` (`background` warm sand `#E8DAC3` radius `8`, `fill` sage-mint `#66C49E` radius `8`).
2. **`src/ui/hud_overlay.gd`**:
   - Replace dark navy panel colors (`Color(0.07, 0.10, 0.17, ...)`) with `UiTheme.make_storybook_card_style(...)`:
     - Top timer card: cream parchment with warm walnut border; `_level_label` in `INK_MUTED`, `_timer_label` in `INK_PRIMARY` (switching to `CORAL_ALERT` when `<= 8.0s`);
     - Thrust badges: idle warm sand pill (`Color(0.93, 0.88, 0.79, 0.85)`) -> active soft sage-mint pill (`Color(0.46, 0.82, 0.68, 0.96)`) with deep cocoa/white label;
     - Seed pill: warm honey-cream card (`border = Color(0.84, 0.66, 0.38, 0.92)`), `_seed_label` in `Color(0.46, 0.33, 0.18)`;
     - Bottom build panel & speed panel: cream parchment cards; `_controls_hint` in `Color(0.52, 0.38, 0.22)`, `_upgrades_label` in `INK_PRIMARY`, `_speed_label` in `SAGE_ACCENT`, `_momentum_label` in `INK_MUTED`, `_overload_label` in `AMBER_ACCENT`;
     - Respawn banner & Seed modal: warm caramel backdrop `Color(0.18, 0.13, 0.09, 0.48)` and cream storybook dialog card.
3. **`src/ui/upgrade_draft_panel.gd` & `src/ui/run_summary_panel.gd`**:
   - Warm caramel modal backdrop `Color(0.18, 0.13, 0.09, 0.58)`;
   - `UpgradeDraftPanel`: header in warm cream `#FFF8EC` with soft cocoa shadow, collectible storybook cards (`Color(0.99, 0.96, 0.90, 0.98)` when selected vs `Color(0.96, 0.92, 0.85, 0.94)` idle, `20px` radius) with rarity borders (`common` warm flax `#9E8B74`, `rare` misty sky `#569EC8`, `legendary` warm amber `#E29530`) and `INK_PRIMARY` / `INK_MUTED` text;
   - `RunSummaryPanel`: warm cream notebook summary card (`22px` radius, soft coral-terracotta border `Color(0.86, 0.52, 0.40)`), cocoa text `#3A281B`.

- [ ] **Step 4: Run `./scripts/test.sh` and `./scripts/build-web.sh` to verify GREEN and refresh Web export**

Run: `./scripts/test.sh && ./scripts/build-web.sh`
Expected: All 6 test suites PASS with 0 failures; `web/index.html`, `web/index.pck`, and `web/index.wasm.bin` rebuilt cleanly.

- [ ] **Step 5: Commit Task 5**

```bash
git add src/ui/ tests/test_core_stats.gd web/
git commit -m "feat: overhaul HUD, draft cards, and summary UI to warm storybook parchment theme and rebuild web"
```
