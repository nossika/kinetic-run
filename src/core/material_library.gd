class_name MaterialLibrary
extends RefCounted

const TEX_TRACK_BEECHWOOD: String = "res://assets/textures/track_beechwood.png"
const TEX_CRATE_BALSA_WOOD: String = "res://assets/textures/crate_balsa_wood.png"
const TEX_CRATE_PAINTED_BLUE: String = "res://assets/textures/crate_painted_blue.png"
const TEX_METAL_CAST_IRON: String = "res://assets/textures/metal_cast_iron.png"
const TEX_ANCHOR_HAZARD_STRIPE: String = "res://assets/textures/anchor_hazard_stripe.png"
const TEX_BARREL_RETRO_HAZARD: String = "res://assets/textures/barrel_retro_hazard.png"
const TEX_JELLY_BUBBLE_SOFT: String = "res://assets/textures/jelly_bubble_soft.png"
const TEX_STORYBOOK_SKY_CLOUDS: String = "res://assets/textures/storybook_sky_clouds.png"
const TEX_BALL_LIVERY_BEACH: String = "res://assets/textures/ball_livery_beach.png"
const TEX_BALL_LIVERY_RACER: String = "res://assets/textures/ball_livery_racer.png"
const TEX_BALL_LIVERY_SWIRL: String = "res://assets/textures/ball_livery_swirl.png"
const TEX_BALL_LIVERY_POLKA: String = "res://assets/textures/ball_livery_polka.png"
const BUNDLED_FONT_PATH: String = "res://assets/fonts/game_ui_zh.ttf"

static var _texture_cache: Dictionary = {}
static var _cached_font: Font = null
static var _font_loaded: bool = false


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func _load_cached_texture(res_path: String) -> Texture2D:
	if _is_headless():
		return null
	if _texture_cache.has(res_path):
		return _texture_cache[res_path] as Texture2D
	var tex: Texture2D = load(res_path) as Texture2D
	_texture_cache[res_path] = tex
	return tex


static func load_storybook_sky_texture() -> Texture2D:
	return _load_cached_texture(TEX_STORYBOOK_SKY_CLOUDS)


static func _load_cached_font() -> Font:
	if _is_headless():
		return null
	if not _font_loaded:
		_font_loaded = true
		_cached_font = load(BUNDLED_FONT_PATH) as Font
	return _cached_font


static func _new_base_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.texture_repeat = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.rim_enabled = true
	mat.rim = 0.22
	mat.rim_tint = 0.38
	return mat


static func high_friction_physics(friction_val: float = 0.88, bounce_val: float = 0.12) -> PhysicsMaterial:
	var pmat := PhysicsMaterial.new()
	pmat.friction = friction_val
	pmat.bounce = bounce_val
	return pmat


static func make_beechwood_material(tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := _new_base_material()
	var warm_cream_maple := Color(0.91, 0.82, 0.70, 1.0)
	mat.albedo_color = Color(
		tint.r * warm_cream_maple.r,
		tint.g * warm_cream_maple.g,
		tint.b * warm_cream_maple.b,
		tint.a
	)
	mat.albedo_texture = _load_cached_texture(TEX_TRACK_BEECHWOOD)
	mat.metallic = 0.0
	mat.metallic_specular = 0.10
	mat.roughness = 0.78
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	mat.uv1_triplanar_sharpness = 3.2
	return mat


static func make_workbench_material(tint: Color = Color(0.88, 0.80, 0.70)) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = tint
	mat.albedo_texture = _load_cached_texture(TEX_TRACK_BEECHWOOD)
	mat.metallic = 0.0
	mat.metallic_specular = 0.08
	mat.roughness = 0.84
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.16, 0.16, 0.16)
	mat.uv1_triplanar_sharpness = 3.0
	return mat


static func make_frosted_acrylic_material(tint: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var alpha := clampf(tint.a if tint.a < 0.99 else 0.76, 0.18, 0.90)
	var soft_pastel := tint.lerp(Color(0.99, 0.96, 0.91), 0.24)
	mat.albedo_color = Color(soft_pastel.r, soft_pastel.g, soft_pastel.b, alpha)
	mat.metallic = 0.04
	mat.roughness = 0.36
	mat.emission_enabled = true
	mat.emission = Color(soft_pastel.r, soft_pastel.g, soft_pastel.b) * 0.24
	mat.emission_energy_multiplier = 0.32
	return mat


static func make_wood_crate_material(is_heavy: bool) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_CRATE_BALSA_WOOD)
	# 6 faces packed in a 3x2 UV grid; scaling UV1 by (3, 2, 1) frames each rounded cube face cleanly.
	mat.uv1_scale = Vector3(3.0, 2.0, 1.0)
	if is_heavy:
		mat.albedo_color = Color(0.68, 0.50, 0.36)
		mat.metallic = 0.04
		mat.metallic_specular = 0.14
		mat.roughness = 0.68
	else:
		mat.albedo_color = Color(0.99, 0.94, 0.85)
		mat.metallic = 0.0
		mat.metallic_specular = 0.12
		mat.roughness = 0.74
	return mat


static func make_cast_iron_material(tint: Color = Color(0.36, 0.38, 0.44)) -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_texture = tex
	if tex != null:
		mat.albedo_color = Color(
			clampf(tint.r * 2.1, 0.56, 1.20),
			clampf(tint.g * 2.1, 0.56, 1.20),
			clampf(tint.b * 2.1, 0.56, 1.20),
			tint.a
		)
	else:
		mat.albedo_color = tint
	mat.metallic = 0.70
	mat.roughness = 0.44
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
	mat.uv1_triplanar_sharpness = 3.2
	return mat


static func make_tungsten_ball_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_color = Color(0.84, 0.90, 0.98)
	mat.metallic = 0.78
	mat.roughness = 0.20
	mat.metallic_specular = 0.72
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
	mat.uv1_triplanar_sharpness = 3.2
	mat.emission_enabled = true
	mat.emission = Color(0.16, 0.20, 0.26)
	mat.emission_energy_multiplier = 0.14
	return mat


static func make_retro_barrel_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(TEX_BARREL_RETRO_HAZARD)
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.99, 0.97, 0.94) if tex != null else Color(0.93, 0.46, 0.38)
	mat.uv1_scale = Vector3(1.0, 2.0, 1.0)
	mat.metallic = 0.10
	mat.roughness = 0.52
	return mat


static func make_charred_husk_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_color = Color(0.28, 0.25, 0.24)
	mat.metallic = 0.18
	mat.roughness = 0.86
	mat.metallic_specular = 0.12
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.75, 0.75, 0.75)
	mat.uv1_triplanar_sharpness = 3.2
	return mat


static func make_pin_stripe_material(color: Color = Color(0.92, 0.44, 0.38)) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = color
	mat.metallic = 0.04
	mat.roughness = 0.28
	mat.metallic_specular = 0.46
	return mat


static func make_silicone_soft_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	var warm_clay := color.lerp(Color(0.99, 0.96, 0.91), 0.16)
	mat.albedo_color = Color(warm_clay.r, warm_clay.g, warm_clay.b, color.a)
	mat.metallic = 0.0
	mat.roughness = 0.88
	mat.metallic_specular = 0.18
	return mat


static func make_jelly_outer_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var alpha := color.a if color.a < 0.99 else 0.62
	var tex := _load_cached_texture(TEX_JELLY_BUBBLE_SOFT)
	mat.albedo_texture = tex
	var soft_jelly := color.lerp(Color(0.99, 0.98, 0.94), 0.26)
	mat.albedo_color = Color(soft_jelly.r, soft_jelly.g, soft_jelly.b, alpha)
	mat.metallic = 0.0
	mat.roughness = 0.14
	mat.metallic_specular = 0.72
	mat.uv1_scale = Vector3(1.2, 1.2, 1.2)
	return mat


static func make_jelly_core_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	var bright := color.lerp(Color(1.0, 0.98, 0.92), 0.32)
	mat.albedo_color = Color(bright.r, bright.g, bright.b, 1.0)
	mat.metallic = 0.0
	mat.roughness = 0.34
	mat.emission_enabled = true
	mat.emission = Color(bright.r, bright.g, bright.b)
	mat.emission_energy_multiplier = 0.32
	return mat


static func _remove_existing_child(target: Node, child_name: String) -> void:
	var existing := target.get_node_or_null(NodePath(child_name))
	if existing != null:
		target.remove_child(existing)
		existing.free()


static func attach_weight_labels(
	target: Node3D,
	weight_text: String,
	box_size: Vector3,
	text_color: Color = Color(0.98, 0.95, 0.88)
) -> void:
	if target == null:
		return
	target.set_meta("weight_label", weight_text)
	_remove_existing_child(target, "WeightLabelFront")
	_remove_existing_child(target, "WeightLabelTop")
	if _is_headless():
		return

	var font := _load_cached_font()
	var char_factor := clampf(4.5 / maxf(3.0, float(weight_text.length())), 0.65, 1.10)

	# Single-sided subtle wood-carved / clay-stamped front mark (no top duplicate, no black outline)
	var front_span := minf(maxf(0.35, box_size.x), maxf(0.35, box_size.y))
	var stamp_color := Color(text_color.r, text_color.g, text_color.b, 0.82)
	var is_light_ink := text_color.get_luminance() > 0.55
	var soft_backing := (
		Color(0.28, 0.20, 0.14, 0.28)
		if is_light_ink
		else Color(0.99, 0.95, 0.87, 0.26)
	)
	var front_lbl := _build_stencil_label(
		weight_text,
		font,
		stamp_color,
		soft_backing,
		0.0032 * clampf(front_span / 1.1, 0.50, 1.50) * char_factor,
		44,
		2
	)
	front_lbl.name = "WeightLabelFront"
	front_lbl.position = Vector3(0.0, -box_size.y * 0.14, box_size.z * 0.5 + 0.025)
	target.add_child(front_lbl)


static func attach_anchored_flange_base(
	target: Node3D,
	local_y: float,
	half_x: float,
	half_z: float,
	_show_fixed_label: bool = true
) -> void:
	if target == null:
		return
	target.set_meta("is_anchored_fixed", true)
	_remove_existing_child(target, "AnchoredFlangeBase")
	if _is_headless():
		return

	var root := Node3D.new()
	root.name = "AnchoredFlangeBase"

	# Clean single-piece rounded warm biscuit-clay suction pad (replaces hazard stripes, bolts, & FIXED text)
	var pad_inst := MeshInstance3D.new()
	var pad_size := Vector3(maxf(0.36, half_x * 1.88), 0.085, maxf(0.36, half_z * 1.88))
	var pad_mesh := ClayMeshBuilder.make_rounded_box(pad_size, 0.038, 2)
	var pad_mat := make_silicone_soft_material(Color(0.84, 0.74, 0.63))
	var trim_tex := _load_cached_texture(TEX_ANCHOR_HAZARD_STRIPE)
	if trim_tex != null:
		pad_mat.albedo_texture = trim_tex
		pad_mat.uv1_triplanar = true
		pad_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	ClayMeshBuilder.assign_mesh(pad_inst, pad_mesh, pad_mat)
	pad_inst.position = Vector3(0.0, local_y + 0.038, 0.0)
	root.add_child(pad_inst)

	target.add_child(root)


static func _build_stencil_label(
	text_val: String,
	font: Font,
	text_color: Color,
	outline_color: Color,
	px_size: float,
	f_size: int,
	o_size: int
) -> Label3D:
	var lbl := Label3D.new()
	if font != null:
		lbl.font = font
	lbl.text = text_val
	lbl.font_size = f_size
	lbl.outline_size = o_size
	lbl.pixel_size = px_size
	lbl.modulate = text_color
	lbl.outline_modulate = outline_color
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.double_sided = false
	lbl.shaded = false
	lbl.render_priority = 2
	return lbl
