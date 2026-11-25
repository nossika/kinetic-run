class_name MaterialLibrary
extends RefCounted

const TEX_TRACK_BEECHWOOD: String = "res://assets/textures/track_beechwood.png"
const TEX_CRATE_BALSA_WOOD: String = "res://assets/textures/crate_balsa_wood.png"
const TEX_METAL_CAST_IRON: String = "res://assets/textures/metal_cast_iron.png"
const TEX_ANCHOR_HAZARD_STRIPE: String = "res://assets/textures/anchor_hazard_stripe.png"
const TEX_BARREL_RETRO_HAZARD: String = "res://assets/textures/barrel_retro_hazard.png"
const TEX_JELLY_BUBBLE_SOFT: String = "res://assets/textures/jelly_bubble_soft.png"
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
	return mat


static func high_friction_physics(friction_val: float = 0.88, bounce_val: float = 0.12) -> PhysicsMaterial:
	var pmat := PhysicsMaterial.new()
	pmat.friction = friction_val
	pmat.bounce = bounce_val
	return pmat


static func make_beechwood_material(tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := _new_base_material()
	var honey := Color(0.66, 0.52, 0.36, 1.0)
	mat.albedo_color = Color(
		tint.r * honey.r,
		tint.g * honey.g,
		tint.b * honey.b,
		tint.a
	)
	mat.albedo_texture = _load_cached_texture(TEX_TRACK_BEECHWOOD)
	mat.metallic = 0.0
	mat.metallic_specular = 0.14
	mat.roughness = 0.68
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
	mat.uv1_triplanar_sharpness = 4.0
	return mat


static func make_workbench_material(tint: Color = Color(0.46, 0.36, 0.26)) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = Color(tint.r * 0.72, tint.g * 0.70, tint.b * 0.68, tint.a)
	mat.albedo_texture = _load_cached_texture(TEX_TRACK_BEECHWOOD)
	mat.metallic = 0.0
	mat.metallic_specular = 0.10
	mat.roughness = 0.80
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
	mat.uv1_triplanar_sharpness = 4.0
	return mat


static func make_frosted_acrylic_material(tint: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var alpha := tint.a if tint.a < 0.99 else 0.72
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	mat.metallic = 0.08
	mat.roughness = 0.24
	mat.emission_enabled = true
	mat.emission = Color(tint.r, tint.g, tint.b) * 0.35
	mat.emission_energy_multiplier = 0.55
	return mat


static func make_wood_crate_material(is_heavy: bool) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_CRATE_BALSA_WOOD)
	# Godot 4 BoxMesh packs 6 faces in a 3x2 UV grid; scaling UV1 by (3, 2, 1) frames each cube face cleanly.
	mat.uv1_scale = Vector3(3.0, 2.0, 1.0)
	if is_heavy:
		mat.albedo_color = Color(0.56, 0.38, 0.24)
		mat.metallic = 0.06
		mat.metallic_specular = 0.18
		mat.roughness = 0.58
	else:
		mat.albedo_color = Color(0.92, 0.82, 0.68)
		mat.metallic = 0.0
		mat.metallic_specular = 0.16
		mat.roughness = 0.66
	return mat


static func make_cast_iron_material(tint: Color = Color(0.28, 0.30, 0.35)) -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_texture = tex
	if tex != null:
		# metal_cast_iron.png already carries dark ~0.20 charcoal value; preserve tint hue without crushing hammered detail.
		mat.albedo_color = Color(
			clampf(tint.r * 2.8, 0.45, 1.25),
			clampf(tint.g * 2.8, 0.45, 1.25),
			clampf(tint.b * 2.8, 0.45, 1.25),
			tint.a
		)
	else:
		mat.albedo_color = tint
	mat.metallic = 0.76
	mat.roughness = 0.34
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.65, 0.65, 0.65)
	mat.uv1_triplanar_sharpness = 4.0
	return mat


static func make_tungsten_ball_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_texture = _load_cached_texture(TEX_METAL_CAST_IRON)
	mat.albedo_color = Color(0.52, 0.58, 0.68)
	mat.metallic = 0.78
	mat.roughness = 0.20
	mat.metallic_specular = 0.88
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(1.2, 1.2, 1.2)
	mat.uv1_triplanar_sharpness = 4.0
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.12, 0.18)
	mat.emission_energy_multiplier = 0.16
	return mat


static func make_retro_barrel_material() -> StandardMaterial3D:
	var mat := _new_base_material()
	var tex := _load_cached_texture(TEX_BARREL_RETRO_HAZARD)
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE if tex != null else Color(0.92, 0.28, 0.18)
	# Godot 4 CylinderMesh maps side wall V in [0..0.5]; scaling V by 2 wraps full red-cream-red hazard band along barrel height.
	mat.uv1_scale = Vector3(1.0, 2.0, 1.0)
	mat.metallic = 0.32
	mat.roughness = 0.36
	return mat


static func make_silicone_soft_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.86
	mat.metallic_specular = 0.25
	return mat


static func make_jelly_outer_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var alpha := color.a if color.a < 0.99 else 0.58
	var tex := _load_cached_texture(TEX_JELLY_BUBBLE_SOFT)
	mat.albedo_texture = tex
	if tex != null:
		var lifted := color.lerp(Color.WHITE, 0.25)
		mat.albedo_color = Color(lifted.r, lifted.g, lifted.b, alpha)
	else:
		mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.metallic = 0.0
	mat.roughness = 0.12
	mat.metallic_specular = 0.85
	mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
	return mat


static func make_jelly_core_material(color: Color) -> StandardMaterial3D:
	var mat := _new_base_material()
	var bright := color.lightened(0.22)
	mat.albedo_color = Color(bright.r, bright.g, bright.b, 1.0)
	mat.metallic = 0.0
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 0.45
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
	text_color: Color = Color(0.98, 0.96, 0.90)
) -> void:
	if target == null:
		return
	target.set_meta("weight_label", weight_text)
	_remove_existing_child(target, "WeightLabelFront")
	_remove_existing_child(target, "WeightLabelTop")
	if _is_headless():
		return

	var font := _load_cached_font()
	var char_factor := clampf(4.5 / maxf(3.0, float(weight_text.length())), 0.65, 1.15)

	# Front (+Z) face stencil facing chase camera
	var front_span := minf(maxf(0.35, box_size.x), maxf(0.35, box_size.y))
	var front_lbl := _build_stencil_label(
		weight_text,
		font,
		text_color,
		0.0040 * clampf(front_span / 1.1, 0.50, 1.70) * char_factor,
		48,
		11
	)
	front_lbl.name = "WeightLabelFront"
	front_lbl.position = Vector3(0.0, 0.0, box_size.z * 0.5 + 0.02)
	target.add_child(front_lbl)

	# Top (+Y) face stencil readable from elevated chase camera angles
	var top_span := minf(maxf(0.35, box_size.x), maxf(0.35, box_size.z))
	var top_lbl := _build_stencil_label(
		weight_text,
		font,
		text_color,
		0.0040 * clampf(top_span / 1.1, 0.50, 1.70) * char_factor,
		48,
		11
	)
	top_lbl.name = "WeightLabelTop"
	top_lbl.position = Vector3(0.0, box_size.y * 0.5 + 0.02, 0.0)
	top_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	target.add_child(top_lbl)


static func attach_anchored_flange_base(
	target: Node3D,
	local_y: float,
	half_x: float,
	half_z: float,
	show_fixed_label: bool = true
) -> void:
	if target == null:
		return
	target.set_meta("is_anchored_fixed", true)
	_remove_existing_child(target, "AnchoredFlangeBase")
	if _is_headless():
		return

	var root := Node3D.new()
	root.name = "AnchoredFlangeBase"

	# 1. Wider black-and-yellow hazard border plate at local_y + 0.02
	var hazard_inst := MeshInstance3D.new()
	var hazard_box := BoxMesh.new()
	hazard_box.size = Vector3(half_x * 2.0 + 0.18, 0.04, half_z * 2.0 + 0.18)
	var hazard_mat := _new_base_material()
	var hazard_tex := _load_cached_texture(TEX_ANCHOR_HAZARD_STRIPE)
	hazard_mat.albedo_texture = hazard_tex
	hazard_mat.albedo_color = Color.WHITE if hazard_tex != null else Color(0.95, 0.78, 0.12)
	hazard_mat.metallic = 0.15
	hazard_mat.roughness = 0.55
	hazard_mat.uv1_triplanar = true
	hazard_mat.uv1_scale = Vector3(0.85, 0.85, 0.85)
	hazard_box.material = hazard_mat
	RenderHelper.attach_mesh(hazard_inst, hazard_box)
	hazard_inst.position = Vector3(0.0, local_y + 0.02, 0.0)
	root.add_child(hazard_inst)

	# 2. Dark cast-iron mounting base plate at local_y + 0.04
	var plate_inst := MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(half_x * 2.0, 0.06, half_z * 2.0)
	plate_box.material = make_cast_iron_material(Color(0.30, 0.32, 0.37))
	RenderHelper.attach_mesh(plate_inst, plate_box)
	plate_inst.position = Vector3(0.0, local_y + 0.04, 0.0)
	root.add_child(plate_inst)

	# 3. Four silver metallic hexagonal bolt heads at (±half_x * 0.88, local_y + 0.08, ±half_z * 0.88)
	var bolt_radius := clampf(minf(half_x, half_z) * 0.13, 0.055, 0.11)
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = bolt_radius
	bolt_mesh.bottom_radius = bolt_radius
	bolt_mesh.height = 0.06
	bolt_mesh.radial_segments = 6
	bolt_mesh.rings = 1
	var bolt_mat := _new_base_material()
	bolt_mat.albedo_color = Color(0.88, 0.91, 0.96)
	bolt_mat.metallic = 0.84
	bolt_mat.roughness = 0.22
	bolt_mesh.material = bolt_mat

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bolt_inst := MeshInstance3D.new()
			RenderHelper.attach_mesh(bolt_inst, bolt_mesh)
			bolt_inst.position = Vector3(sx * half_x * 0.88, local_y + 0.08, sz * half_z * 0.88)
			root.add_child(bolt_inst)

	# 4. Crisp "FIXED" stencil label on the front +Z rim when requested
	if show_fixed_label:
		var fixed_lbl := _build_stencil_label(
			"FIXED",
			_load_cached_font(),
			Color(1.0, 0.86, 0.28),
			clampf(half_x * 0.0058, 0.0036, 0.0058),
			42,
			11
		)
		fixed_lbl.name = "FixedRimLabel"
		fixed_lbl.position = Vector3(0.0, local_y + 0.18, half_z + 0.16)
		fixed_lbl.rotation_degrees = Vector3(-32.0, 0.0, 0.0)
		root.add_child(fixed_lbl)

	target.add_child(root)


static func _build_stencil_label(
	text_val: String,
	font: Font,
	text_color: Color,
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
	lbl.outline_modulate = Color(0.09, 0.10, 0.13, 0.96)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.double_sided = false
	lbl.shaded = false
	lbl.render_priority = 2
	return lbl
