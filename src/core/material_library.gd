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

const DEFAULT_OUTLINE_COLOR: Color = Color(0.22, 0.14, 0.09, 1.0)

static var _texture_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
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
	mat.rim_enabled = false
	return mat


static func make_toon_outline_material(
	thickness: float = 0.026,
	outline_color: Color = DEFAULT_OUTLINE_COLOR
) -> StandardMaterial3D:
	var q_thick := int(round(thickness * 1000.0))
	var key := "%d_%d" % [q_thick, outline_color.to_rgba32()]
	if _outline_cache.has(key):
		return _outline_cache[key] as StandardMaterial3D
	var out_mat := StandardMaterial3D.new()
	out_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	out_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	out_mat.albedo_color = outline_color
	out_mat.grow = true
	out_mat.grow_amount = maxf(0.008, thickness)
	_outline_cache[key] = out_mat
	return out_mat


static func high_friction_physics(friction_val: float = 0.88, bounce_val: float = 0.12) -> PhysicsMaterial:
	var pmat := PhysicsMaterial.new()
	pmat.friction = friction_val
	pmat.bounce = bounce_val
	return pmat


static func make_beechwood_material(tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := _new_base_material()
	var warm_maple := Color(0.90, 0.78, 0.63, 1.0)
	mat.albedo_color = Color(
		tint.r * warm_maple.r,
		tint.g * warm_maple.g,
		tint.b * warm_maple.b,
		tint.a
	)
	mat.albedo_texture = _load_cached_texture(TEX_TRACK_BEECHWOOD)
	mat.metallic = 0.0
	mat.metallic_specular = 0.08
	mat.roughness = 0.80
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	mat.uv1_triplanar_sharpness = 3.2
	return mat


static func make_workbench_material(tint: Color = Color(0.86, 0.75, 0.62)) -> StandardMaterial3D:
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


static func make_ceramic_pin_material(tint: Color = Color(0.98, 0.97, 0.94)) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = tint
	mat.metallic = 0.02
	mat.roughness = 0.28
	mat.metallic_specular = 0.48
	mat.next_pass = make_toon_outline_material(0.022)
	return mat


static func make_frosted_acrylic_material(tint: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var alpha := clampf(tint.a if tint.a < 0.99 else 0.80, 0.20, 0.92)
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.metallic = 0.04
	mat.roughness = 0.34
	mat.emission_enabled = true
	mat.emission = Color(tint.r, tint.g, tint.b) * 0.20
	mat.emission_energy_multiplier = 0.28
	return mat


static func make_wood_crate_material(is_heavy: bool) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.uv1_scale = Vector3(3.0, 2.0, 1.0)
	if is_heavy:
		mat.albedo_texture = _load_cached_texture(TEX_CRATE_BALSA_WOOD)
		mat.albedo_color = Color(0.56, 0.35, 0.21)
		mat.metallic = 0.04
		mat.metallic_specular = 0.16
		mat.roughness = 0.64
		mat.next_pass = make_toon_outline_material(0.030)
	else:
		mat.albedo_texture = _load_cached_texture(TEX_CRATE_PAINTED_BLUE)
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		mat.metallic = 0.0
		mat.metallic_specular = 0.18
		mat.roughness = 0.60
		mat.next_pass = make_toon_outline_material(0.026)
	return mat


static func make_cast_iron_material(tint: Color = Color(0.24, 0.33, 0.52)) -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_texture = tex
	if tex != null:
		mat.albedo_color = Color(
			clampf(tint.r * 1.9, 0.38, 1.15),
			clampf(tint.g * 1.9, 0.42, 1.15),
			clampf(tint.b * 1.9, 0.52, 1.25),
			tint.a
		)
	else:
		mat.albedo_color = tint
	mat.metallic = 0.68
	mat.roughness = 0.42
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
	mat.uv1_triplanar_sharpness = 3.2
	mat.next_pass = make_toon_outline_material(0.028)
	return mat


static func make_tungsten_ball_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_color = Color(0.82, 0.89, 0.98)
	mat.metallic = 0.78
	mat.roughness = 0.20
	mat.metallic_specular = 0.72
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
	mat.uv1_triplanar_sharpness = 3.2
	mat.next_pass = make_toon_outline_material(0.028)
	return mat


static func make_starter_ball_material(
	livery_path: String = TEX_BALL_LIVERY_BEACH,
	tint: Color = Color.WHITE
) -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(livery_path)
	if tex == null:
		tex = _load_cached_texture(TEX_BALL_LIVERY_BEACH)
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.metallic = 0.04
	mat.roughness = 0.34
	mat.metallic_specular = 0.46
	mat.next_pass = make_toon_outline_material(0.028)
	return mat


static func make_retro_barrel_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(TEX_BARREL_RETRO_HAZARD)
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 0.96, 0.92) if tex != null else Color(0.92, 0.28, 0.22)
	mat.uv1_scale = Vector3(1.0, 2.0, 1.0)
	mat.metallic = 0.08
	mat.roughness = 0.48
	mat.next_pass = make_toon_outline_material(0.028)
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
	mat.next_pass = make_toon_outline_material(0.024)
	return mat


static func make_pin_stripe_material(color: Color = Color(0.90, 0.20, 0.20)) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = color
	mat.metallic = 0.04
	mat.roughness = 0.26
	mat.metallic_specular = 0.48
	mat.next_pass = make_toon_outline_material(0.016)
	return mat


static func make_silicone_soft_material(color: Color, with_outline: bool = true) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.82
	mat.metallic_specular = 0.20
	if with_outline:
		mat.next_pass = make_toon_outline_material(0.024)
	return mat


static func make_jelly_outer_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var alpha := color.a if color.a < 0.99 else 0.74
	var tex := _load_cached_texture(TEX_JELLY_BUBBLE_SOFT)
	mat.albedo_texture = tex
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.metallic = 0.0
	mat.roughness = 0.14
	mat.metallic_specular = 0.72
	mat.uv1_scale = Vector3(1.2, 1.2, 1.2)
	mat.next_pass = make_toon_outline_material(0.024, Color(0.14, 0.26, 0.18, 1.0))
	return mat


static func make_jelly_core_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mat.metallic = 0.0
	mat.roughness = 0.34
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 0.30
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
	text_color: Color = Color(0.99, 0.96, 0.89)
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
	var front_span := minf(maxf(0.35, box_size.x), maxf(0.35, box_size.y))
	var stamp_color := Color(text_color.r, text_color.g, text_color.b, 0.94)
	var is_light_ink := text_color.get_luminance() > 0.50
	var soft_backing := (
		Color(0.20, 0.13, 0.08, 0.72)
		if is_light_ink
		else Color(0.99, 0.96, 0.90, 0.68)
	)
	var front_lbl := _build_stencil_label(
		weight_text,
		font,
		stamp_color,
		soft_backing,
		0.0033 * clampf(front_span / 1.1, 0.50, 1.50) * char_factor,
		46,
		4
	)
	front_lbl.name = "WeightLabelFront"
	front_lbl.position = Vector3(0.0, -box_size.y * 0.14, box_size.z * 0.5 + 0.03)
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

	var pad_inst := MeshInstance3D.new()
	var pad_size := Vector3(maxf(0.36, half_x * 1.88), 0.085, maxf(0.36, half_z * 1.88))
	var pad_mesh := ClayMeshBuilder.make_rounded_box(pad_size, 0.038, 2)
	var pad_mat := make_silicone_soft_material(Color(0.68, 0.48, 0.34), true)
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
	return lbl
