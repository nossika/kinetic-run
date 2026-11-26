class_name TrackChunkBase
extends Node3D

const STANDARD_WIDTH: float = 12.5
const FLOOR_THICKNESS: float = 0.6

var chunk_type: String = "StraightWide"
var length: float = 26.0
var entry_z: float = 0.0
var exit_z: float = -26.0


func build_chunk(p_type: String, p_entry_z: float) -> void:
	chunk_type = p_type
	entry_z = p_entry_z
	position = Vector3(0.0, 0.0, entry_z)

	match chunk_type:
		"StraightWide":
			length = 26.0
			_build_straight_wide()
		"WaveHills":
			length = 30.0
			_build_wave_hills()
		"NarrowBridge":
			length = 24.0
			_build_narrow_bridge()
		"SplitPath":
			length = 32.0
			_build_split_path()
		"RampGap":
			length = 28.0
			_build_ramp_gap()
		"PinballAlley":
			length = 26.0
			_build_pinball_alley()
		"FunnelGauntlet":
			length = 30.0
			_build_funnel_gauntlet()
		_:
			length = 26.0
			_build_straight_wide()

	exit_z = entry_z - length


func _add_floor_slab(local_pos: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = local_pos
	body.rotation_degrees = rot_deg
	body.physics_material_override = MaterialLibrary.high_friction_physics(0.88, 0.12)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = MaterialLibrary.make_beechwood_material(color)
	RenderHelper.attach_mesh(mesh_inst, box)
	body.add_child(mesh_inst)

	add_child(body)
	return body


func _add_sloped_wave_segment(
	width: float,
	thickness: float,
	y_start: float,
	z_start: float,
	y_end: float,
	z_end: float,
	color: Color
) -> StaticBody3D:
	var dz := z_start - z_end
	var dy := y_end - y_start
	var seg_len := sqrt(dz * dz + dy * dy)
	var pitch_rad := atan2(dy, dz)
	var y_mid := (y_start + y_end) * 0.5 - thickness * 0.5 * cos(pitch_rad)
	var z_mid := (z_start + z_end) * 0.5 - thickness * 0.5 * sin(pitch_rad)
	return _add_floor_slab(
		Vector3(0.0, y_mid, z_mid),
		Vector3(width, thickness, seg_len),
		color,
		Vector3(rad_to_deg(pitch_rad), 0.0, 0.0)
	)


func _add_guard_rail(
	local_pos: Vector3,
	size: Vector3,
	color: Color,
	yaw_deg: float = 0.0,
	show_front_fixed_label: bool = false
) -> StaticBody3D:
	var rail := StaticBody3D.new()
	rail.add_to_group("track_rail")
	rail.position = local_pos
	rail.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.08
	phys_mat.bounce = 0.55
	rail.physics_material_override = phys_mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	rail.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = MaterialLibrary.make_frosted_acrylic_material(color)
	RenderHelper.attach_mesh(mesh_inst, box)
	rail.add_child(mesh_inst)

	_attach_rail_stanchions(rail, size, show_front_fixed_label)

	add_child(rail)
	return rail


func _attach_rail_stanchions(rail: StaticBody3D, size: Vector3, show_front_fixed_label: bool) -> void:
	rail.set_meta("is_anchored_fixed", true)
	var base_y := -size.y * 0.5

	if size.x > size.z and size.x >= 4.0:
		# Wide cross-track backstop rail: stanchions at left, center, and right
		for sx in [-size.x * 0.38, 0.0, size.x * 0.38]:
			var post := Node3D.new()
			post.position = Vector3(sx, base_y, 0.0)
			rail.add_child(post)
			MaterialLibrary.attach_anchored_flange_base(post, 0.0, 0.55, maxf(0.32, size.z * 0.65), false)
		return

	var half_x := clampf(size.x * 0.65, 0.28, 0.85)
	var z_offsets: Array[float] = []
	if size.z >= 18.0:
		var end_z := size.z * 0.5 - 1.2
		z_offsets = [end_z, 0.0, -end_z]
	elif size.z >= 6.0:
		var end_z := size.z * 0.5 - 0.85
		z_offsets = [end_z, -end_z]
	else:
		z_offsets = [0.0]

	for idx in range(z_offsets.size()):
		var post := Node3D.new()
		post.position = Vector3(0.0, base_y, z_offsets[idx])
		rail.add_child(post)
		var show_lbl := show_front_fixed_label and idx == 0
		MaterialLibrary.attach_anchored_flange_base(post, 0.0, half_x, 0.55, show_lbl)


func add_side_launch_ramp(local_pos: Vector3, width: float = 3.0) -> StaticBody3D:
	const RAMP_PITCH_DEG: float = 16.0
	const RAMP_LEN: float = 5.25
	const RAMP_THICKNESS: float = 0.36

	var pitch_rad := deg_to_rad(RAMP_PITCH_DEG)
	# Position center so the +Z top entry edge meets local_pos.y flush (0.0mm lip) and rises to ~+1.45m
	var center_y := local_pos.y + (RAMP_LEN * 0.5) * sin(pitch_rad) - (RAMP_THICKNESS * 0.5) * cos(pitch_rad)

	var ramp := StaticBody3D.new()
	ramp.name = "SideLaunchRamp"
	ramp.position = Vector3(local_pos.x, center_y, local_pos.z)
	ramp.rotation_degrees = Vector3(RAMP_PITCH_DEG, 0.0, 0.0)
	ramp.physics_material_override = MaterialLibrary.high_friction_physics(0.72, 0.08)
	ramp.set_meta("is_anchored_fixed", true)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, RAMP_THICKNESS, RAMP_LEN)
	col.shape = shape
	ramp.add_child(col)

	var deck_mesh := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = Vector3(width, RAMP_THICKNESS, RAMP_LEN)
	deck_box.material = MaterialLibrary.make_frosted_acrylic_material(Color(0.16, 0.88, 1.0, 0.78))
	RenderHelper.attach_mesh(deck_mesh, deck_box)
	ramp.add_child(deck_mesh)

	if DisplayServer.get_name() != "headless":
		var trim_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.65, 0.98, 1.0, 0.88))
		for side_sign in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			var curb_box := BoxMesh.new()
			curb_box.size = Vector3(0.09, 0.10, RAMP_LEN)
			curb_box.material = trim_mat
			RenderHelper.attach_mesh(curb, curb_box)
			curb.position = Vector3(side_sign * (width * 0.5 - 0.045), RAMP_THICKNESS * 0.5 + 0.05, 0.0)
			ramp.add_child(curb)

	# Counter-rotate flange holder under raised half of wedge so anchor plate & bolts sit cleanly beneath acrylic deck
	var flange_holder := Node3D.new()
	flange_holder.rotation_degrees = Vector3(-RAMP_PITCH_DEG, 0.0, 0.0)
	flange_holder.position = Basis(Vector3.RIGHT, -pitch_rad) * Vector3(0.0, local_pos.y - center_y, -0.55)
	ramp.add_child(flange_holder)
	MaterialLibrary.attach_anchored_flange_base(flange_holder, 0.0, width * 0.46, 1.65, false)

	add_child(ramp)
	return ramp


func add_sky_platform(
	local_pos: Vector3,
	size: Vector3 = Vector3(3.8, 0.34, 11.5),
	with_end_kick: bool = false
) -> StaticBody3D:
	var deck := StaticBody3D.new()
	deck.name = "SkyPlatform"
	deck.add_to_group("sky_platform")
	deck.position = local_pos
	deck.physics_material_override = MaterialLibrary.high_friction_physics(0.80, 0.14)
	deck.set_meta("is_anchored_fixed", true)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	deck.add_child(col)

	var kick_len := 2.6
	var kick_pitch_deg := 12.0
	var kick_rad := deg_to_rad(kick_pitch_deg)
	var kick_offset := Vector3(
		0.0,
		(kick_len * 0.5) * sin(kick_rad),
		-size.z * 0.5 - (kick_len * 0.5) * cos(kick_rad) + 0.08
	)
	if with_end_kick:
		var kick_col := CollisionShape3D.new()
		var kick_shape := BoxShape3D.new()
		kick_shape.size = Vector3(size.x, size.y, kick_len)
		kick_col.shape = kick_shape
		kick_col.position = kick_offset
		kick_col.rotation_degrees = Vector3(kick_pitch_deg, 0.0, 0.0)
		deck.add_child(kick_col)

	if DisplayServer.get_name() != "headless":
		var deck_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.32, 0.90, 1.0, 0.64))
		var trim_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.76, 0.98, 1.0, 0.86))
		var strut_mat := MaterialLibrary.make_frosted_acrylic_material(Color(0.98, 0.80, 0.36, 0.52))

		var deck_mesh := MeshInstance3D.new()
		var deck_box := BoxMesh.new()
		deck_box.size = size
		deck_box.material = deck_mat
		RenderHelper.attach_mesh(deck_mesh, deck_box)
		deck.add_child(deck_mesh)

		for side_sign in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			var curb_box := BoxMesh.new()
			curb_box.size = Vector3(0.09, 0.10, size.z)
			curb_box.material = trim_mat
			RenderHelper.attach_mesh(curb, curb_box)
			curb.position = Vector3(side_sign * (size.x * 0.5 - 0.045), size.y * 0.5 + 0.05, 0.0)
			deck.add_child(curb)

			# Slender angled side-stay cables (visual only, leaving ground lane 100% clear)
			var stay := MeshInstance3D.new()
			var stay_cyl := CylinderMesh.new()
			stay_cyl.top_radius = 0.035
			stay_cyl.bottom_radius = 0.035
			stay_cyl.height = 1.85
			stay_cyl.radial_segments = 8
			stay_cyl.material = strut_mat
			RenderHelper.attach_mesh(stay, stay_cyl)
			stay.position = Vector3(side_sign * (size.x * 0.5 + 0.28), -0.78, 0.0)
			stay.rotation_degrees = Vector3(0.0, 0.0, side_sign * 22.0)
			deck.add_child(stay)

		if with_end_kick:
			var kick_mesh := MeshInstance3D.new()
			var kick_box := BoxMesh.new()
			kick_box.size = Vector3(size.x, size.y, kick_len)
			kick_box.material = trim_mat
			RenderHelper.attach_mesh(kick_mesh, kick_box)
			kick_mesh.position = kick_offset
			kick_mesh.rotation_degrees = Vector3(kick_pitch_deg, 0.0, 0.0)
			deck.add_child(kick_mesh)

	add_child(deck)
	return deck


func _add_speed_stripes(z_len: float, half_w: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.76, 0.58, 0.36)
	stripe_mat.roughness = 0.44
	stripe_mat.metallic = 0.18
	var count := int(z_len / 6.0)
	for i in range(count):
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(half_w * 1.5, 0.016, 0.28)
		bm.material = stripe_mat
		RenderHelper.attach_mesh(m, bm)
		m.position = Vector3(0.0, 0.009, -float(i) * 6.0 - 3.0)
		add_child(m)


func _build_straight_wide() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(1.0, 0.98, 0.94)
	)
	_add_speed_stripes(length, 5.25)
	var rail_col := Color(0.22, 0.78, 0.98)
	_add_guard_rail(Vector3(-6.45, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)


func _build_wave_hills() -> void:
	var base_wood := Color(0.99, 0.96, 0.91)
	var slope_wood := Color(1.0, 0.97, 0.92)
	var crest_wood := Color(1.03, 0.99, 0.93)
	var wave_t := 0.52

	# Entry apron [0 .. -3] flush at y = 0
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -1.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 3.0),
		base_wood
	)

	# Wave Hill 1 [-3.0 .. -13.5], crest peaking at +1.45m local Y
	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 0.0, -3.0, 1.45, -7.2, slope_wood)
	_add_floor_slab(
		Vector3(0.0, 1.45 - FLOOR_THICKNESS * 0.5, -8.25),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 2.1),
		crest_wood
	)
	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 1.45, -9.3, 0.0, -13.5, slope_wood)

	# Central flat trough [-13.5 .. -16.5] flush at y = 0 for stable landing shockwave targets
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -15.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 3.0),
		base_wood
	)

	# Wave Hill 2 [-16.5 .. -27.0], crest peaking at +1.45m local Y
	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 0.0, -16.5, 1.45, -20.7, slope_wood)
	_add_floor_slab(
		Vector3(0.0, 1.45 - FLOOR_THICKNESS * 0.5, -21.75),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 2.1),
		crest_wood
	)
	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 1.45, -22.8, 0.0, -27.0, slope_wood)

	# Exit apron [-27 .. -30] flush at y = 0
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -28.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 3.0),
		base_wood
	)

	var rail_col := Color(0.24, 0.86, 0.96)
	_add_guard_rail(Vector3(-6.45, 1.2, -length * 0.5), Vector3(0.4, 2.4, length), rail_col)
	_add_guard_rail(Vector3(6.45, 1.2, -length * 0.5), Vector3(0.4, 2.4, length), rail_col)


func _build_narrow_bridge() -> void:
	# Entry & exit transition aprons + 5.25m narrow unrailed beechwood bridge
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -2.0),
		Vector3(10.0, FLOOR_THICKNESS, 4.0),
		Color(0.98, 0.95, 0.90)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -12.0),
		Vector3(5.25, FLOOR_THICKNESS, 16.0),
		Color(0.95, 0.89, 0.81)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -22.0),
		Vector3(10.0, FLOOR_THICKNESS, 4.0),
		Color(0.98, 0.95, 0.90)
	)
	# Visual hazard edge trim (non-blocking height)
	if DisplayServer.get_name() != "headless":
		var trim_mat := MaterialLibrary.make_frosted_acrylic_material(Color(1.0, 0.58, 0.14, 0.86))
		for side in [-2.55, 2.55]:
			var trim := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.06, 16.0)
			bm.material = trim_mat
			RenderHelper.attach_mesh(trim, bm)
			trim.position = Vector3(side, 0.03, -12.0)
			add_child(trim)


func _build_split_path() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH + 1.5, FLOOR_THICKNESS, length),
		Color(0.99, 0.96, 0.92)
	)
	var rail_col := Color(0.25, 0.82, 0.96)
	_add_guard_rail(Vector3(-7.2, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	_add_guard_rail(Vector3(7.2, 0.55, -length * 0.5), Vector3(0.4, 1.1, length), rail_col)
	# Central frosted amber acrylic divider island with bolted FIXED flange stanchion
	_add_guard_rail(
		Vector3(0.0, 0.65, -length * 0.5),
		Vector3(1.6, 1.3, 20.0),
		Color(0.96, 0.48, 0.24),
		0.0,
		true
	)


func _build_ramp_gap() -> void:
	# Entry deck [0 .. -8]
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -4.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 8.0),
		Color(0.99, 0.96, 0.92)
	)
	# Central launch ramp [-8 .. -14], flush at Z=-8 (y=0) rising cleanly to y=+1.85m at Z=-14
	_add_sloped_wave_segment(6.5, 0.46, 0.0, -8.0, 1.85, -14.0, Color(1.02, 0.94, 0.84))
	# Auxiliary side bridges spanning [-8 .. -20] so low-speed balls can bypass chasm
	_add_floor_slab(
		Vector3(-5.125, -FLOOR_THICKNESS * 0.5, -14.0),
		Vector3(2.25, FLOOR_THICKNESS, 12.0),
		Color(0.95, 0.90, 0.83)
	)
	_add_floor_slab(
		Vector3(5.125, -FLOOR_THICKNESS * 0.5, -14.0),
		Vector3(2.25, FLOOR_THICKNESS, 12.0),
		Color(0.95, 0.90, 0.83)
	)
	# Landing deck [-20 .. -28]
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -24.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 8.0),
		Color(0.99, 0.96, 0.92)
	)
	var rail_col := Color(0.28, 0.78, 1.0)
	_add_guard_rail(Vector3(-6.45, 0.85, -length * 0.5), Vector3(0.4, 1.7, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.85, -length * 0.5), Vector3(0.4, 1.7, length), rail_col)


func _build_pinball_alley() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.99, 0.95, 0.91)
	)
	_add_speed_stripes(length, 5.0)
	var rail_col := Color(0.95, 0.36, 0.76)
	_add_guard_rail(Vector3(-6.45, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)


func _build_funnel_gauntlet() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.97, 0.93, 0.88)
	)
	var rail_col := Color(1.0, 0.38, 0.24)
	_add_guard_rail(Vector3(-6.45, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.65, -length * 0.5), Vector3(0.45, 1.3, length), rail_col)
	# Angled inner frosted acrylic funnel walls with bolted flange bases
	_add_guard_rail(Vector3(-4.75, 0.55, -10.0), Vector3(0.4, 1.1, 9.0), rail_col, -10.0, true)
	_add_guard_rail(Vector3(4.75, 0.55, -10.0), Vector3(0.4, 1.1, 9.0), rail_col, 10.0, true)
