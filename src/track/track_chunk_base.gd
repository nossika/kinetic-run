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
	var rbox := ClayMeshBuilder.make_rounded_box(size, 0.15, 3)
	var mat := MaterialLibrary.make_beechwood_material(color)
	ClayMeshBuilder.assign_mesh(mesh_inst, rbox, mat)
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
	var bevel := minf(size.x, size.y) * 0.45
	var rbox := ClayMeshBuilder.make_rounded_box(size, bevel, 3)
	var rail_mat := MaterialLibrary.make_silicone_soft_material(color, false)
	ClayMeshBuilder.assign_mesh(mesh_inst, rbox, rail_mat)
	rail.add_child(mesh_inst)

	_attach_rail_stanchions(rail, size, show_front_fixed_label)

	add_child(rail)
	return rail


func _attach_rail_stanchions(rail: StaticBody3D, size: Vector3, show_front_fixed_label: bool) -> void:
	rail.set_meta("is_anchored_fixed", true)
	var base_y := -size.y * 0.5

	if size.x > size.z and size.x >= 4.0:
		for sx in [-size.x * 0.38, 0.0, size.x * 0.38]:
			var post := Node3D.new()
			post.position = Vector3(sx, base_y, 0.0)
			rail.add_child(post)
			MaterialLibrary.attach_anchored_flange_base(post, 0.0, 0.42, maxf(0.28, size.z * 0.55), false)
		return

	var half_x := clampf(size.x * 0.58, 0.24, 0.72)
	var z_offsets: Array[float] = []
	if size.z >= 18.0:
		var end_z := size.z * 0.5 - 1.4
		z_offsets = [end_z, 0.0, -end_z]
	elif size.z >= 6.0:
		var end_z := size.z * 0.5 - 1.0
		z_offsets = [end_z, -end_z]
	else:
		z_offsets = [0.0]

	for idx in range(z_offsets.size()):
		var post := Node3D.new()
		post.position = Vector3(0.0, base_y, z_offsets[idx])
		rail.add_child(post)
		var show_lbl := show_front_fixed_label and idx == 0
		MaterialLibrary.attach_anchored_flange_base(post, 0.0, half_x, 0.44, show_lbl)


func add_side_launch_ramp(local_pos: Vector3, width: float = 3.0) -> StaticBody3D:
	const RAMP_PITCH_DEG: float = 16.0
	const RAMP_LEN: float = 5.25
	const RAMP_THICKNESS: float = 0.36

	var pitch_rad := deg_to_rad(RAMP_PITCH_DEG)
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
	var deck_size := Vector3(width, RAMP_THICKNESS, RAMP_LEN)
	var deck_rbox := ClayMeshBuilder.make_rounded_box(deck_size, 0.11, 3)
	var deck_mat := MaterialLibrary.make_silicone_soft_material(Color(0.54, 0.78, 0.92))
	ClayMeshBuilder.assign_mesh(deck_mesh, deck_rbox, deck_mat)
	ramp.add_child(deck_mesh)

	if DisplayServer.get_name() != "headless":
		var trim_mat := MaterialLibrary.make_silicone_soft_material(Color(0.98, 0.95, 0.88))
		var curb_rbox := ClayMeshBuilder.make_rounded_box(Vector3(0.14, 0.12, RAMP_LEN - 0.12), 0.05, 2)
		for side_sign in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			ClayMeshBuilder.assign_mesh(curb, curb_rbox, trim_mat)
			curb.position = Vector3(side_sign * (width * 0.5 - 0.08), RAMP_THICKNESS * 0.5 + 0.04, 0.0)
			ramp.add_child(curb)

	var flange_holder := Node3D.new()
	flange_holder.rotation_degrees = Vector3(-RAMP_PITCH_DEG, 0.0, 0.0)
	flange_holder.position = Basis(Vector3.RIGHT, -pitch_rad) * Vector3(0.0, local_pos.y - center_y, -0.55)
	ramp.add_child(flange_holder)
	MaterialLibrary.attach_anchored_flange_base(flange_holder, 0.0, width * 0.42, 1.35, false)

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

	var is_headless := DisplayServer.get_name() == "headless"
	var trim_mat: StandardMaterial3D = null
	if not is_headless:
		var deck_mat := MaterialLibrary.make_silicone_soft_material(Color(0.58, 0.80, 0.94))
		trim_mat = MaterialLibrary.make_silicone_soft_material(Color(0.99, 0.96, 0.90))
		var strut_mat := MaterialLibrary.make_beechwood_material(Color(0.96, 0.90, 0.80))

		var deck_mesh := MeshInstance3D.new()
		var deck_rbox := ClayMeshBuilder.make_rounded_box(size, 0.12, 3)
		ClayMeshBuilder.assign_mesh(deck_mesh, deck_rbox, deck_mat)
		deck.add_child(deck_mesh)

		var curb_rbox := ClayMeshBuilder.make_rounded_box(Vector3(0.14, 0.12, size.z - 0.14), 0.05, 2)

		var stay_cyl := CapsuleMesh.new()
		stay_cyl.radius = 0.045
		stay_cyl.height = 1.85
		stay_cyl.radial_segments = 12
		stay_cyl.material = strut_mat

		for side_sign in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			ClayMeshBuilder.assign_mesh(curb, curb_rbox, trim_mat)
			curb.position = Vector3(side_sign * (size.x * 0.5 - 0.08), size.y * 0.5 + 0.04, 0.0)
			deck.add_child(curb)

			var stay := MeshInstance3D.new()
			stay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			RenderHelper.attach_mesh(stay, stay_cyl)
			stay.position = Vector3(side_sign * (size.x * 0.5 + 0.26), -0.76, 0.0)
			stay.rotation_degrees = Vector3(0.0, 0.0, side_sign * 22.0)
			deck.add_child(stay)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	deck.add_child(col)

	if with_end_kick:
		const KICK_LEN: float = 2.6
		const KICK_PITCH_DEG: float = 12.0
		var kick_rad := deg_to_rad(KICK_PITCH_DEG)
		var kick_offset := Vector3(
			0.0,
			(KICK_LEN * 0.5) * sin(kick_rad),
			-size.z * 0.5 - (KICK_LEN * 0.5) * cos(kick_rad) + 0.08
		)
		var kick_col := CollisionShape3D.new()
		var kick_shape := BoxShape3D.new()
		kick_shape.size = Vector3(size.x, size.y, KICK_LEN)
		kick_col.shape = kick_shape
		kick_col.position = kick_offset
		kick_col.rotation_degrees = Vector3(KICK_PITCH_DEG, 0.0, 0.0)
		deck.add_child(kick_col)

		if not is_headless:
			var kick_mesh := MeshInstance3D.new()
			var kick_rbox := ClayMeshBuilder.make_rounded_box(Vector3(size.x, size.y, KICK_LEN), 0.11, 3)
			ClayMeshBuilder.assign_mesh(kick_mesh, kick_rbox, trim_mat)
			kick_mesh.position = kick_offset
			kick_mesh.rotation_degrees = Vector3(KICK_PITCH_DEG, 0.0, 0.0)
			deck.add_child(kick_mesh)

	add_child(deck)
	return deck


func _add_speed_stripes(_z_len: float, _half_w: float) -> void:
	# Kept intentionally clean: cross-track floor lines were visually noisy beneath the rolling ball.
	return


func _build_straight_wide() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(1.0, 0.98, 0.95)
	)
	_add_speed_stripes(length, 4.8)
	var rail_col := Color(0.18, 0.68, 0.64)
	_add_guard_rail(Vector3(-6.45, 0.52, -length * 0.5), Vector3(0.46, 1.04, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.52, -length * 0.5), Vector3(0.46, 1.04, length), rail_col)


func _build_wave_hills() -> void:
	var base_wood := Color(0.99, 0.97, 0.93)
	var slope_wood := Color(1.0, 0.98, 0.94)
	var crest_wood := Color(1.02, 0.99, 0.95)
	var wave_t := 0.54

	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -1.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 3.0),
		base_wood
	)

	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 0.0, -3.0, 1.45, -7.2, slope_wood)
	_add_floor_slab(
		Vector3(0.0, 1.45 - FLOOR_THICKNESS * 0.5, -8.25),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 2.1),
		crest_wood
	)
	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 1.45, -9.3, 0.0, -13.5, slope_wood)

	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -15.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 3.0),
		base_wood
	)

	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 0.0, -16.5, 1.45, -20.7, slope_wood)
	_add_floor_slab(
		Vector3(0.0, 1.45 - FLOOR_THICKNESS * 0.5, -21.75),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 2.1),
		crest_wood
	)
	_add_sloped_wave_segment(STANDARD_WIDTH, wave_t, 1.45, -22.8, 0.0, -27.0, slope_wood)

	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -28.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 3.0),
		base_wood
	)

	var rail_col := Color(0.22, 0.58, 0.88)
	_add_guard_rail(Vector3(-6.45, 1.15, -length * 0.5), Vector3(0.46, 2.3, length), rail_col)
	_add_guard_rail(Vector3(6.45, 1.15, -length * 0.5), Vector3(0.46, 2.3, length), rail_col)


func _build_narrow_bridge() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -2.0),
		Vector3(10.0, FLOOR_THICKNESS, 4.0),
		Color(0.99, 0.96, 0.92)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -12.0),
		Vector3(5.25, FLOOR_THICKNESS, 16.0),
		Color(0.96, 0.91, 0.84)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -22.0),
		Vector3(10.0, FLOOR_THICKNESS, 4.0),
		Color(0.99, 0.96, 0.92)
	)
	if DisplayServer.get_name() != "headless":
		var trim_mat := MaterialLibrary.make_silicone_soft_material(Color(0.92, 0.42, 0.28))
		var trim_rbox := ClayMeshBuilder.make_rounded_box(Vector3(0.14, 0.07, 15.8), 0.032, 2)
		for side in [-2.52, 2.52]:
			var trim := MeshInstance3D.new()
			ClayMeshBuilder.assign_mesh(trim, trim_rbox, trim_mat)
			trim.position = Vector3(side, 0.032, -12.0)
			add_child(trim)


func _build_split_path() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH + 1.5, FLOOR_THICKNESS, length),
		Color(0.99, 0.97, 0.93)
	)
	var rail_col := Color(0.18, 0.68, 0.64)
	_add_guard_rail(Vector3(-7.2, 0.52, -length * 0.5), Vector3(0.46, 1.04, length), rail_col)
	_add_guard_rail(Vector3(7.2, 0.52, -length * 0.5), Vector3(0.46, 1.04, length), rail_col)
	_add_guard_rail(
		Vector3(0.0, 0.62, -length * 0.5),
		Vector3(1.6, 1.24, 20.0),
		Color(0.92, 0.44, 0.30),
		0.0,
		false
	)


func _build_ramp_gap() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -4.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 8.0),
		Color(0.99, 0.97, 0.93)
	)
	_add_sloped_wave_segment(6.5, 0.48, 0.0, -8.0, 1.85, -14.0, Color(1.01, 0.95, 0.87))
	_add_floor_slab(
		Vector3(-5.125, -FLOOR_THICKNESS * 0.5, -14.0),
		Vector3(2.25, FLOOR_THICKNESS, 12.0),
		Color(0.96, 0.92, 0.86)
	)
	_add_floor_slab(
		Vector3(5.125, -FLOOR_THICKNESS * 0.5, -14.0),
		Vector3(2.25, FLOOR_THICKNESS, 12.0),
		Color(0.96, 0.92, 0.86)
	)
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -24.0),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, 8.0),
		Color(0.99, 0.97, 0.93)
	)
	var rail_col := Color(0.22, 0.58, 0.88)
	_add_guard_rail(Vector3(-6.45, 0.82, -length * 0.5), Vector3(0.46, 1.64, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.82, -length * 0.5), Vector3(0.46, 1.64, length), rail_col)


func _build_pinball_alley() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.99, 0.96, 0.93)
	)
	_add_speed_stripes(length, 4.6)
	var rail_col := Color(0.90, 0.36, 0.44)
	_add_guard_rail(Vector3(-6.45, 0.62, -length * 0.5), Vector3(0.48, 1.24, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.62, -length * 0.5), Vector3(0.48, 1.24, length), rail_col)


func _build_funnel_gauntlet() -> void:
	_add_floor_slab(
		Vector3(0.0, -FLOOR_THICKNESS * 0.5, -length * 0.5),
		Vector3(STANDARD_WIDTH, FLOOR_THICKNESS, length),
		Color(0.98, 0.95, 0.90)
	)
	var rail_col := Color(0.92, 0.42, 0.28)
	_add_guard_rail(Vector3(-6.45, 0.62, -length * 0.5), Vector3(0.48, 1.24, length), rail_col)
	_add_guard_rail(Vector3(6.45, 0.62, -length * 0.5), Vector3(0.48, 1.24, length), rail_col)
	_add_guard_rail(Vector3(-4.75, 0.54, -10.0), Vector3(0.46, 1.08, 9.0), rail_col, -10.0, false)
	_add_guard_rail(Vector3(4.75, 0.54, -10.0), Vector3(0.46, 1.08, 9.0), rail_col, 10.0, false)
